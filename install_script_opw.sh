#!/bin/bash
# (C) Datadog, Inc. 2010-present
# All rights reserved
# Licensed under Apache-2.0 License (see LICENSE)
# Datadog Observability Pipelines Worker installation script:
# install and set up the Observability Pipelines Worker on supported Linux distributions
# using the package manager and Datadog repositories.

set -e

install_script_version="0.1.0"
logfile="dd-install.log"
support_email="support@datadoghq.com"

# DATADOG_APT_KEY_CURRENT.public always contains key used to sign current
# repodata and newly released packages
# DATADOG_APT_KEY_382E94DE.public expires in 2022
# DATADOG_APT_KEY_F14F620E.public expires in 2032
# DATADOG_APT_KEY_C0962C7D.public expires in 2028
APT_GPG_KEYS=("DATADOG_APT_KEY_CURRENT.public" "DATADOG_APT_KEY_C0962C7D.public" "DATADOG_APT_KEY_F14F620E.public" "DATADOG_APT_KEY_382E94DE.public")

# DATADOG_RPM_KEY_CURRENT.public always contains key used to sign current
# repodata and newly released packages
# DATADOG_RPM_KEY_E09422B3.public expires in 2022
# DATADOG_RPM_KEY_FD4BF915.public expires in 2024
# DATADOG_RPM_KEY_B01082D3.public expires in 2028
RPM_GPG_KEYS=("DATADOG_RPM_KEY_CURRENT.public" "DATADOG_RPM_KEY_B01082D3.public" "DATADOG_RPM_KEY_FD4BF915.public" "DATADOG_RPM_KEY_E09422B3.public")

# Error codes for telemetry
GENERAL_ERROR_CODE=1
UNSUPPORTED_PLATFORM_CODE=5
INVALID_PARAMETERS_CODE=6

# Set up a named pipe for logging
npipe=/tmp/$$.tmp
mknod $npipe p

# Log all output to a log for error checking
tee <$npipe $logfile &
exec 1>&-
exec 1>$npipe 2>&1
trap 'rm -f $npipe' EXIT

function fallback_msg(){
  printf "
If you are still having problems, please send an email to $support_email
with the contents of $logfile and any information you think would be
useful and we will do our very best to help you solve your problem.\n"
}

# TODO: this uses an Agent specific endpoint, remove before using?
function report(){
  if curl -f -s \
    --data-urlencode "os=${OS}" \
    --data-urlencode "version=${worker_major_version}" \
    --data-urlencode "log=$(cat $logfile)" \
    --data-urlencode "email=${email}" \
    --data-urlencode "apikey=${apikey}" \
    "$report_failure_url"; then
   printf "A notification has been sent to Datadog with the contents of $logfile\n"
  else
    printf "Unable to send the notification (curl v7.18 or newer is required)"
  fi
}

function report_telemetry() {
  if [ "$DD_INSTRUMENTATION_TELEMETRY_ENABLED" == "false" ] || \
    [ "$site" == "ddog-gov.com" ] || \
    [ -z "${apikey}" ] || \
    [ -z "$telemetry_url" ]; then
    return
  fi

  if [ -n "$worker_minor_version" ] ; then
    safe_worker_version=$(echo -n "$worker_major_version.$worker_minor_version" | tr '\n' ' ' | tr '"' '_')
  else
    safe_worker_version=$(echo -n "$worker_major_version" | tr '\n' ' ' | tr '"' '_')
  fi

  if [ -z "${ERROR_CODE}" ] ; then
    telemetry_event="
{
   \"request_type\": \"apm-onboarding-event\",
   \"api_version\": \"v1\",
   \"payload\": {
       \"event_name\": \"pipelines.installation.success\",
       \"tags\": {
           \"worker_platform\": \"native\",
           \"worker_version\": \"$safe_worker_version\",
           \"script_version\": \"$install_script_version\"
       }
   }
}
"
  else
    safe_error_message=$(echo -n "$ERROR_MESSAGE" | tr '\n' ' ' | tr '"' '_')
    telemetry_event="
{
   \"request_type\": \"apm-onboarding-event\",
   \"api_version\": \"v1\",
   \"payload\": {
       \"event_name\": \"pipelines.installation.error\",
       \"tags\": {
           \"worker_platform\": \"native\",
           \"worker_version\": \"$safe_worker_version\",
           \"script_version\": \"$install_script_version\"
       },
       \"error\": {
          \"code\": $ERROR_CODE,
          \"message\": \"$safe_error_message\"
       }
   }
}
"
  fi

  if ! (cat <<END
       $telemetry_event
END
       ) | curl --fail --silent --output /dev/null \
    "$telemetry_url" \
    --header 'Content-Type: application/json' \
    --header "DD-Api-Key: $apikey" \
    --data @-
  then
    printf "Unable to send telemetry\n"
  fi
}

function on_read_error() {
  printf "Timed out or input EOF reached, assuming 'No'\n"
  yn="n"
}

function get_email() {
  emaillocalpart='^[a-zA-Z0-9][a-zA-Z0-9._%+-]{0,63}'
  hostnamepart='[a-zA-Z0-9.-]+\.[a-zA-Z]+'
  email_regex="$emaillocalpart@$hostnamepart"
  cntr=0
  until [[ "$cntr" -eq 3 ]]
  do
      read -p "Enter an email address so we can follow up: " -r email
      if [[ "$email" =~ $email_regex ]]; then
        isEmailValid=true
        break
      else
        ((cntr=cntr+1))
        echo -e "\033[33m($cntr/3) Email address invalid: $email\033[0m\n"
      fi
  done
}

function on_error() {
    if [ -z "${ERROR_MESSAGE}" ] ; then
      # Save the few lines of the log file for telemetry if the error message is blank
      SAVED_ERROR_MESSAGE=$(tail -n 3 $logfile)
    fi

    printf "\033[31m$ERROR_MESSAGE
It looks like you hit an issue when trying to install the $nice_flavor.

Troubleshooting and basic usage information for the $nice_flavor are available at:

    https://docs.datadoghq.com/observability_pipelines/\n\033[0m\n"

    ERROR_MESSAGE=$SAVED_ERROR_MESSAGE
    ERROR_CODE=$GENERAL_ERROR_CODE
    report_telemetry

    if ! tty -s; then
      fallback_msg
      exit 1;
    fi

    if [ "$site" == "ddog-gov.com" ]; then
      fallback_msg
      exit 1;
    fi

    while true; do
        read -t 60 -p  "Do you want to send a failure report to Datadog (including $logfile)? (y/[n]) " -r yn || on_read_error
        case $yn in
          [Yy]* )
            get_email
            if [[ -n "$isEmailValid" ]]; then
              report
            fi
            fallback_msg
            break;;
          [Nn]*|"" )
            fallback_msg
            break;;
          * )
            printf "Please answer yes or no.\n"
            ;;
        esac
    done
}
trap on_error ERR

# OPW doesn't have a public changelog
function verify_agent_version(){
    local ver_separator="$1"
    if [ -z "$agent_version_custom" ]; then
        ERROR_MESSAGE="Specified version not found: $worker_major_version.$worker_minor_version"
        ERROR_CODE=$INVALID_PARAMETERS_CODE
        echo -e "
  \033[33mWarning: $ERROR_MESSAGE
\033[0m"
        fallback_msg
        report_telemetry
        exit 1;
    else
        worker_flavor+="$ver_separator$agent_version_custom"
    fi
}

echo -e "\033[34m\n* Datadog Observability Pipelines Worker install script v${install_script_version}\n\033[0m"

site=
if [ -n "$DD_SITE" ]; then
    site="$DD_SITE"
fi

apikey=
if [ -n "$DD_API_KEY" ]; then
    apikey=$DD_API_KEY
fi

op_pipeline_id=
if [ -n "$DD_OP_PIPELINE_ID" ]; then
    op_pipeline_id=$DD_OP_PIPELINE_ID
fi

no_start=
if [ -n "$DD_INSTALL_ONLY" ]; then
    no_start=true
fi

if [ -n "$DD_REPO_URL" ]; then
    repository_url=$DD_REPO_URL
elif [ -n "$REPO_URL" ]; then
    echo -e "\033[33mWarning: REPO_URL is deprecated and might be removed later (use DD_REPO_URL instead).\033[0m"
    repository_url=$REPO_URL
else
    repository_url="datadoghq.com"
fi

if [ -n "$TESTING_KEYS_URL" ]; then
  keys_url=$TESTING_KEYS_URL
else
  keys_url="keys.datadoghq.com"
fi

if [ -n "$TESTING_YUM_URL" ]; then
  yum_url=$TESTING_YUM_URL
else
  yum_url="yum.${repository_url}"
fi

# We turn off `repo_gpgcheck` for custom REPO_URL, unless explicitly turned
# on via DD_RPM_REPO_GPGCHECK.
# There is more logic for redhat/suse in their specific code branches below
rpm_repo_gpgcheck=
if [ -n "$DD_RPM_REPO_GPGCHECK" ]; then
    rpm_repo_gpgcheck=$DD_RPM_REPO_GPGCHECK
else
    if [ -n "$REPO_URL" ] || [ -n "$DD_REPO_URL" ]; then
        rpm_repo_gpgcheck=0
    fi
fi

if [ -n "$TESTING_APT_URL" ]; then
  apt_url=$TESTING_APT_URL
else
  apt_url="apt.${repository_url}"
fi

# TODO: this uses an Agent specific endpoint, remove before using?
report_failure_url="https://api.datadoghq.com/agent_stats/report_failure"
if [ -n "$DD_SITE" ]; then
    report_failure_url="https://api.${DD_SITE}/agent_stats/report_failure"
fi

telemetry_url="https://instrumentation-telemetry-intake.datadoghq.com/api/v2/apmtelemetry"
if [ -n "$DD_SITE" ]; then
    telemetry_url="https://instrumentation-telemetry-intake.${DD_SITE}/api/v2/apmtelemetry"
fi

if [ -n "$TESTING_REPORT_URL" ]; then
  report_failure_url=$TESTING_REPORT_URL
  telemetry_url=$TESTING_REPORT_URL
fi

worker_flavor="observability-pipelines-worker"
nice_flavor="Observability Pipelines Worker"

if [ -z "$etcdir" ]; then
    etcdir="/etc/observability-pipelines-worker"
fi

if [ -z "$config_file" ]; then
    config_file="$etcdir/bootstrap.yaml"
fi

worker_major_version=1
if [ -n "$DD_WORKER_MAJOR_VERSION" ]; then
  worker_major_version=${DD_WORKER_MAJOR_VERSION}
fi

if [ -n "$DD_WORKER_MINOR_VERSION" ]; then
  # Examples:
  #  - 20   = defaults to highest patch version x.20.2
  #  - 20.0 = sets explicit patch version x.20.0
  # Note: Specifying an invalid minor version will terminate the script.
  worker_minor_version=${DD_WORKER_MINOR_VERSION}
fi

worker_dist_channel=stable
if [ -n "$DD_WORKER_DIST_CHANNEL" ]; then
  if [ "$repository_url" == "datadoghq.com" ]; then
    if [ "$DD_WORKER_DIST_CHANNEL" != "stable" ] && [ "$DD_WORKER_DIST_CHANNEL" != "beta" ]; then
      ERROR_MESSAGE="DD_WORKER_DIST_CHANNEL must be either 'stable' or 'beta'. Current value: $DD_WORKER_DIST_CHANNEL"
      ERROR_CODE=$INVALID_PARAMETERS_CODE
      echo "$ERROR_MESSAGE"
      report_telemetry
      exit 1;
    fi
  elif [ "$DD_WORKER_DIST_CHANNEL" != "stable" ] && [ "$DD_WORKER_DIST_CHANNEL" != "beta" ] && [ "$DD_WORKER_DIST_CHANNEL" != "nightly" ]; then
    ERROR_MESSAGE="DD_WORKER_DIST_CHANNEL must be either 'stable', 'beta' or 'nightly' on custom repos. Current value: $DD_WORKER_DIST_CHANNEL"
    ERROR_CODE=$INVALID_PARAMETERS_CODE
    echo "$ERROR_MESSAGE"
    report_telemetry
    exit 1;
  fi
  worker_dist_channel=$DD_WORKER_DIST_CHANNEL
fi

if [ -n "$TESTING_YUM_VERSION_PATH" ]; then
  yum_version_path=$TESTING_YUM_VERSION_PATH
else
  yum_version_path="${worker_dist_channel}/observability-pipelines-worker-1"
fi

if [ -n "$TESTING_APT_REPO_VERSION" ]; then
  apt_repo_version=$TESTING_APT_REPO_VERSION
else
  apt_repo_version="${worker_dist_channel} observability-pipelines-worker-1"
fi

if [ ! "$apikey" ]; then
  if [ ! -e "$config_file" ]; then
    printf "\033[31mAPI key not available in DD_API_KEY environment variable.\033[0m\n"
    exit 1;
  fi
fi

# OS/Distro Detection
# Try lsb_release, fallback with /etc/issue then uname command
KNOWN_DISTRIBUTION="(Debian|Ubuntu|RedHat|CentOS|Amazon)"
DISTRIBUTION=$(lsb_release -d 2>/dev/null | grep -Eo $KNOWN_DISTRIBUTION  || grep -Eo $KNOWN_DISTRIBUTION /etc/issue 2>/dev/null || grep -m1 -Eo $KNOWN_DISTRIBUTION /etc/os-release 2>/dev/null || uname -s)

if [ "$DISTRIBUTION" = "Darwin" ]; then
    ERROR_MESSAGE="This script does not support installing on Mac."
    ERROR_CODE=$UNSUPPORTED_PLATFORM_CODE
    printf "\033[31m$ERROR_MESSAGE
\033[0m\n"
    report_telemetry
    exit 1;

elif [ -f /etc/debian_version ] || [ "$DISTRIBUTION" == "Debian" ] || [ "$DISTRIBUTION" == "Ubuntu" ]; then
    OS="Debian"
elif [ -f /etc/redhat-release ] || [ "$DISTRIBUTION" == "RedHat" ] || [ "$DISTRIBUTION" == "CentOS" ] || [ "$DISTRIBUTION" == "Amazon" ]; then
    OS="RedHat"
# Some newer distros like Amazon may not have a redhat-release file
elif [ -f /etc/system-release ] || [ "$DISTRIBUTION" == "Amazon" ]; then
    OS="RedHat"
fi

# Root user detection
if [ "$(echo "$UID")" = "0" ]; then
    sudo_cmd=''
else
    sudo_cmd='sudo'
fi

# Install the necessary package sources
if [ "$OS" = "RedHat" ]; then
    echo -e "\033[34m\n* Installing YUM sources for Datadog\n\033[0m"

    UNAME_M=$(uname -m)
    if [ "$UNAME_M" == "aarch64" ]; then
        ARCHI="aarch64"
    else
        ARCHI="x86_64"
    fi

    # Because of https://bugzilla.redhat.com/show_bug.cgi?id=1792506, we disable
    # repo_gpgcheck on RHEL/CentOS 8.1
    if [ -z "$rpm_repo_gpgcheck" ]; then
        if grep -q "8\.1\(\b\|\.\)" /etc/redhat-release 2>/dev/null; then
            rpm_repo_gpgcheck=0
        else
            rpm_repo_gpgcheck=1
        fi
    fi

    gpgkeys="https://${keys_url}/DATADOG_RPM_KEY.public\n       https://${keys_url}/DATADOG_RPM_KEY_E09422B3.public"

    gpgkeys=''
    separator='\n       '
    for key_path in "${RPM_GPG_KEYS[@]}"; do
      gpgkeys="${gpgkeys:+"${gpgkeys}${separator}"}https://${keys_url}/${key_path}"
    done

    $sudo_cmd sh -c "echo -e '[datadog]\nname = Datadog, Inc.\nbaseurl = https://${yum_url}/${yum_version_path}/${ARCHI}/\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=${rpm_repo_gpgcheck}\npriority=1\ngpgkey=${gpgkeys}' > /etc/yum.repos.d/datadog.repo"

    $sudo_cmd yum -y clean metadata

    dnf_flag=""
    if [ -f "/usr/bin/dnf" ] && { [ ! -f "/usr/bin/yum" ] || [ -L "/usr/bin/yum" ]; } ; then
      # On modern Red Hat based distros, yum is an alias (symlink) of dnf.
      # "dnf install" doesn't upgrade a package if a newer version
      # is available, unless the --best flag is set
      # NOTE: we assume that sometime in the future "/usr/bin/yum" will
      # be removed altogether, so we test for that as well.
      dnf_flag="--best"
    fi

    if [ -n "$worker_minor_version" ]; then
        # Example: observability-pipelines-worker-1.2.1-1
        pkg_pattern="$worker_major_version\.${worker_minor_version%.}(\.[[:digit:]]+){0,1}(-[[:digit:]])?"
        agent_version_custom="$(yum -y --disablerepo=* --enablerepo=datadog list --showduplicates observability-pipelines-worker | sort -r | grep -E "$pkg_pattern" -om1)" || true
        verify_agent_version "-"
    fi

    declare -a packages
    packages=("observability-pipelines-worker")
    
    echo -e "  \033[33mInstalling package(s): ${packages[*]}\n\033[0m"

    $sudo_cmd yum -y --disablerepo='*' --enablerepo='datadog' install $dnf_flag "${packages[@]}" || $sudo_cmd yum -y install $dnf_flag "${packages[@]}"

elif [ "$OS" = "Debian" ]; then
    apt_trusted_d_keyring="/etc/apt/trusted.gpg.d/datadog-archive-keyring.gpg"
    apt_usr_share_keyring="/usr/share/keyrings/datadog-archive-keyring.gpg"
    
    DD_APT_INSTALL_ERROR_MSG=/tmp/ddog_install_error_msg
    MAX_RETRY_NB=10
    for i in $(seq 1 $MAX_RETRY_NB)
    do
        printf "\033[34m\n* Installing apt-transport-https, curl and gnupg\n\033[0m\n"
        $sudo_cmd apt-get update || printf "\033[31m'apt-get update' failed, the script will not install the latest version of apt-transport-https.\033[0m\n"
        # installing curl might trigger install of additional version of libssl; this will fail the installation process,
        # see https://unix.stackexchange.com/q/146283 for reference - we use DEBIAN_FRONTEND=noninteractive to fix that
        apt_exit_code=0
        if [ -z "$sudo_cmd" ]; then
            # if $sudo_cmd is empty, doing `$sudo_cmd X=Y command` fails with
            # `X=Y: command not found`; therefore we don't prefix the command with
            # $sudo_cmd at all in this case
            DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https curl gnupg 2>$DD_APT_INSTALL_ERROR_MSG  || apt_exit_code=$?
        else
            $sudo_cmd DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https curl gnupg 2>$DD_APT_INSTALL_ERROR_MSG || apt_exit_code=$?
        fi

        if grep "Could not get lock" $DD_APT_INSTALL_ERROR_MSG; then
            RETRY_TIME=$((i*5))
            printf "\033[31mInstallation failed: Unable to get lock.\nRetrying in ${RETRY_TIME}s ($i/$MAX_RETRY_NB).\033[0m\n"
            sleep $RETRY_TIME
        elif [ $apt_exit_code -ne 0 ]; then
            cat $DD_APT_INSTALL_ERROR_MSG
            exit $apt_exit_code
        else
            break
        fi
    done

    printf "\033[34m\n* Installing APT package sources for Datadog\n\033[0m\n"
    $sudo_cmd sh -c "echo 'deb [signed-by=${apt_usr_share_keyring}] https://${apt_url}/ ${apt_repo_version}' > /etc/apt/sources.list.d/datadog.list"

    if [ ! -f $apt_usr_share_keyring ]; then
        $sudo_cmd touch $apt_usr_share_keyring
    fi
    # ensure that the _apt user used on Ubuntu/Debian systems to read GPG keyrings
    # can read our keyring
    $sudo_cmd chmod a+r $apt_usr_share_keyring

    for key in "${APT_GPG_KEYS[@]}"; do
        $sudo_cmd curl --retry 5 -o "/tmp/${key}" "https://${keys_url}/${key}"
        $sudo_cmd cat "/tmp/${key}" | $sudo_cmd gpg --import --batch --no-default-keyring --keyring "$apt_usr_share_keyring"
    done

    release_version="$(grep VERSION_ID /etc/os-release | cut -d = -f 2 | xargs echo | cut -d "." -f 1)"
    if { [ "$DISTRIBUTION" == "Debian" ] && [ "$release_version" -lt 9 ]; } || \
       { [ "$DISTRIBUTION" == "Ubuntu" ] && [ "$release_version" -lt 16 ]; }; then
        # copy with -a to preserve file permissions
        $sudo_cmd cp -a $apt_usr_share_keyring $apt_trusted_d_keyring
    fi

    ERROR_MESSAGE="ERROR
Failed to update the sources after adding the Datadog repository.
This may be due to any of the configured APT sources failing -
see the logs above to determine the cause.
If the failing repository is Datadog, please contact Datadog support.
*****
"
    $sudo_cmd apt-get update -o Dir::Etc::sourcelist="sources.list.d/datadog.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
    ERROR_MESSAGE="ERROR
Failed to install one or more packages, sometimes it may be
due to another APT source failing. See the logs above to
determine the cause.
If the cause is unclear, please contact Datadog support.
*****
"

    if [ -n "$worker_minor_version" ]; then
        # Example: observability-pipelines-worker=1.2.1-1
        pkg_pattern="([[:digit:]]:)?$worker_major_version\.${worker_minor_version%.}(\.[[:digit:]]+){0,1}(-[[:digit:]])?"
        agent_version_custom="$(apt-cache madison observability-pipelines-worker | grep -E "$pkg_pattern" -om1)" || true
        verify_agent_version "="
    fi

    declare -a packages
    packages=("observability-pipelines-worker" "datadog-signing-keys")

    echo -e "  \033[33mInstalling package(s): ${packages[*]}\n\033[0m"

    $sudo_cmd apt-get install -y --force-yes "${packages[@]}"

    ERROR_MESSAGE=""
else
    ERROR_MESSAGE="Your OS or distribution are not supported by this install script.
Please follow the instructions on the Observability Pipelines Worker setup page:

https://docs.datadoghq.com/observability_pipelines/setup/"
    ERROR_CODE=$UNSUPPORTED_PLATFORM_CODE
    printf "\033[31m$ERROR_MESSAGE\033[0m\n"
    report_telemetry
    exit;
fi

# Set the configuration
if [ "$apikey" ]; then
  printf "\033[34m\n* Adding your API key to the $nice_flavor configuration: $config_file\n\033[0m\n"
  $sudo_cmd sh -c "sed -i 's/# api_key:.*/api_key: $apikey/' $config_file"
else
  # If the import script failed for any reason, we might end here also in case
  # of upgrade, let's not start the worker or it would fail because the api key
  # is missing
  if ! $sudo_cmd grep -q -E '^api_key: .+' "$config_file"; then
    printf "\033[31mThe $nice_flavor won't start automatically at the end of the script because the API key is missing,\nplease add one in $config_file and start the $nice_flavor manually.\n\033[0m\n"
    no_start=true
  fi
fi

if [ "$op_pipeline_id" ]; then
  printf "\033[34m\n* Adding your Pipeline ID to the $nice_flavor configuration: $config_file\n\033[0m\n"
  $sudo_cmd sh -c "sed -i 's/# pipeline_id:.*/pipeline_id: $op_pipeline_id/' $config_file"
else
  # If the import script failed for any reason, we might end here also in case
  # of upgrade, let's not start the worker or it would fail because the api key
  # is missing
  if ! $sudo_cmd grep -q -E '^pipeline_id: .+' "$config_file"; then
    printf "\033[31mThe $nice_flavor won't start automatically at the end of the script because the Pipeline ID is missing,\nplease add one in $config_file and start the $nice_flavor manually.\n\033[0m\n"
    no_start=true
  fi
fi

if [ "$site" ]; then
  printf "\033[34m\n* Setting SITE in the $nice_flavor configuration: $config_file\n\033[0m\n"
  $sudo_cmd sh -c "sed -i 's/# site:.*/site: $site/' $config_file"
fi

if [ ! -e "$etcdir"/pipeline.yaml ]; then
  printf "\033[31mThe $nice_flavor won't start automatically at the end of the script because the pipeline configuration is missing,\nplease add one at $etcdir/pipeline.yaml and start the $nice_flavor manually.\n\033[0m\n"
  no_start=true
fi

$sudo_cmd chown observability-pipelines-worker:observability-pipelines-worker "$config_file"
$sudo_cmd chmod 640 "$config_file"

# Creating or overriding the install information
install_info_content="---
install_method:
  tool: install_script
  tool_version: install_script_opw
  installer_version: install_script-$install_script_version
"

$sudo_cmd sh -c "echo '$install_info_content' > $etcdir/install_info"

service_cmd="service"

if [ $no_start ]; then
  printf "\033[34m\n  * DD_INSTALL_ONLY environment variable set.\033[0m\n"
fi

# Use /usr/sbin/service by default.
# Some distros usually include compatibility scripts with Upstart or Systemd. Check with: `command -v service | xargs grep -E "(upstart|systemd)"`
restart_cmd="$sudo_cmd $service_cmd $worker_flavor restart"
stop_instructions="$sudo_cmd $service_cmd $worker_flavor stop"
start_instructions="$sudo_cmd $service_cmd $worker_flavor start"

if [[ `$sudo_cmd ps --no-headers -o comm 1 2>&1` == "systemd" ]] && command -v systemctl 2>&1; then
  # Use systemd if systemctl binary exists and systemd is the init process
  restart_cmd="$sudo_cmd systemctl restart ${worker_flavor}.service"
  stop_instructions="$sudo_cmd systemctl stop $worker_flavor"
  start_instructions="$sudo_cmd systemctl start $worker_flavor"
elif /sbin/init --version 2>&1 | grep -q upstart; then
  # Try to detect Upstart, this works most of the times but still a best effort
  restart_cmd="$sudo_cmd stop $worker_flavor || true ; sleep 2s ; $sudo_cmd start $worker_flavor"
  stop_instructions="$sudo_cmd stop $worker_flavor"
  start_instructions="$sudo_cmd start $worker_flavor"
fi

if [ $no_start ]; then
  printf "\033[34m\n    The newly installed version of the ${nice_flavor} will not be started.
  You will have to do it manually using the following command:

  $start_instructions\033[0m\n\n"

else
  printf "\033[34m* Starting the ${nice_flavor}...\n\033[0m\n"
  ERROR_MESSAGE="Error starting ${nice_flavor}"

  eval "$restart_cmd"

  ERROR_MESSAGE=""
    
  # Metrics are submitted, echo some instructions and exit
  printf "\033[32m  Your ${nice_flavor} is running and functioning properly.\n\033[0m"

  printf "\033[32m  It will continue to run in the background and submit metrics to Datadog.\n\033[0m"

  printf "\033[32m  If you ever want to stop the ${nice_flavor}, run:

      $stop_instructions

  And to run it again run:

      $start_instructions\033[0m\n\n"
fi

report_telemetry
