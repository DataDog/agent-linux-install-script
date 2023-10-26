#!/bin/bash -e

EXPECTED_FLAVOR=${DD_AGENT_FLAVOR:-datadog-agent}
SCRIPT_FLAVOR=$(echo ${SCRIPT} | sed "s|.*install_script_\(.*\).sh|\1|")
if [ "${EXPECTED_FLAVOR}" != "datadog-agent" ] && echo "${SCRIPT}" | grep "agent6.sh$" >/dev/null; then
    echo "[PASS] Can't install flavor '${DD_AGENT_FLAVOR}' with install_script_agent6.sh"
    exit 0
fi

cp $SCRIPT /tmp/script.sh
if [ "$DD_APM_INSTRUMENTATION_ENABLED" == "all" ] || [ "$DD_APM_INSTRUMENTATION_ENABLED" == "docker" ] || [ "$SCRIPT_FLAVOR" == "docker_injection" ]; then
    # fake presence of docker and make sure the script doesn't try to restart it
    mkdir /etc/docker
    sed -i "s|dd-container-install --no-agent-restart|dd-container-install --no-agent-restart --no-docker-reload|" /tmp/script.sh
fi
/tmp/script.sh

INSTALLED_VERSION=
RESULT=0
EXPECTED_MAJOR_VERSION=6
if [ "${SCRIPT_FLAVOR}" == "agent7" ] || [ "${EXPECTED_FLAVOR}" != "datadog-agent" ] ; then
    EXPECTED_MAJOR_VERSION=7
fi
if [ "${SCRIPT_FLAVOR}" == "docker_injection" ]; then
    DD_NO_AGENT_INSTALL=true
fi
EXPECTED_MINOR_VERSION="${EXPECTED_MINOR_VERSION:-${DD_AGENT_MINOR_VERSION}}"

# basic checks to ensure that the correct flavor was installed
if command -v dpkg > /dev/null; then
    apt-get install -y debsums

    if [ -z "$DD_NO_AGENT_INSTALL" ]; then
      debsums -c ${EXPECTED_FLAVOR}
      INSTALLED_VERSION=$(dpkg-query -W ${EXPECTED_FLAVOR} | cut -f2 | cut -d: -f2)
    elif debsums -c datadog-agent ; then
      echo "[FAIL] datadog-agent should not be installed"
      RESULT=1
    fi
else
    if [ -z "$DD_NO_AGENT_INSTALL" ]; then
      # skip verification of mode/user/group, because these are
      # changed by the postinstall scriptlet
      rpm --verify --nomode --nouser --nogroup "${EXPECTED_FLAVOR}"
      INSTALLED_VERSION=$(rpm -q --qf "%{version}" "${EXPECTED_FLAVOR}")
    elif rpm --verify --nomode --nouser --nogroup datadog-agent ; then
      echo "[FAIL] datadog-agent should not be installed"
      RESULT=1
    fi
fi

echo -e "\n"

MAJOR_VERSION=$(echo "$INSTALLED_VERSION" | cut -d "." -f 1)
MINOR_VERSION=$(echo "$INSTALLED_VERSION" | cut -d "." -f 2)

if [ -z "$DD_NO_AGENT_INSTALL" ]; then
  if [ "${EXPECTED_MAJOR_VERSION}" != "${MAJOR_VERSION}" ]; then
      echo "[FAIL] Expected major version ${EXPECTED_MAJOR_VERSION} to be installed, but found ${MAJOR_VERSION}"
      RESULT=1
  else
      echo "[OK] Correct major version installed"
  fi
fi

if [ -n "${EXPECTED_MINOR_VERSION}" ]; then
    if [ "${EXPECTED_MINOR_VERSION}" != "${MINOR_VERSION}" ]; then
        echo "[FAIL] Expected minor version ${EXPECTED_MINOR_VERSION} to be installed, but found ${MINOR_VERSION}"
        RESULT=1
    else
        echo "[OK] Correct minor version installed"
    fi
else
    echo "[PASS] DD_AGENT_MINOR_VERSION not specified, not checking installed minor version"
fi

EXPECTED_TOOL_VERSION=
if [ "${SCRIPT_FLAVOR}" == "agent6" ]; then
    EXPECTED_TOOL_VERSION="install_script_agent6"
elif [ "${SCRIPT_FLAVOR}" == "agent7" ]; then
    EXPECTED_TOOL_VERSION="install_script_agent7"
elif [ "${SCRIPT_FLAVOR}" == "install_script.sh" ]; then
    EXPECTED_TOOL_VERSION="install_script"
elif [ "${SCRIPT_FLAVOR}" == "docker_injection" ]; then
    EXPECTED_TOOL_VERSION="docker_injection"
else
    echo "[ERROR] Don't know what install info to expect for script ${SCRIPT}"
    RESULT=1
fi

if [ -n "${EXPECTED_TOOL_VERSION}" ] && [ -z "$DD_NO_AGENT_INSTALL" ]; then
    INSTALL_INFO_FILE=/etc/datadog-agent/install_info
    if [ "${EXPECTED_FLAVOR}" = "datadog-dogstatsd" ]; then
        INSTALL_INFO_FILE=/etc/datadog-dogstatsd/install_info
    fi

    TOOL_VERSION=$(cat "$INSTALL_INFO_FILE" | grep "tool_version:" | cut -d":" -f 2)
    if echo "${TOOL_VERSION}" | grep "${EXPECTED_TOOL_VERSION}$" >/dev/null; then
        echo "[OK] Correct tool_version found in install_info file"
    else
        echo "[FAIL] Expected to find tool_version ${EXPECTED_TOOL_VERSION} in install_info, but found '${TOOL_VERSION}'"
        RESULT=1
    fi
fi

if [ "${EXPECTED_FLAVOR}" == "datadog-agent" ] && [ -z "$DD_NO_AGENT_INSTALL" ]; then
    dd_agent_config_file=/etc/datadog-agent/datadog.yaml
    if [ ! -f $dd_agent_config_file ]; then
        echo "[FAIL] Config file $dd_agent_config_file not found"
        RESULT=1
    fi
    if [ -n "$DD_ENV" ]; then
        if grep -q "^env: $DD_ENV" $dd_agent_config_file; then
            echo "[OK] Expected environment was found"
        else
            echo "[FAIL] Expected environment wasn't found in $dd_agent_config_file"
            RESULT=1
        fi
        if grep -E "^[[:space:]]+env: $DD_ENV" $dd_agent_config_file; then
            echo "[FAIL] Some other occurences of env were mistakenly replaced $dd_agent_config_file"
            RESULT=1
        fi
    fi
fi

system_probe_config_file=/etc/datadog-agent/system-probe.yaml
if [ -n "${DD_SYSTEM_PROBE_ENSURE_CONFIG}" ]; then
    if [ -e "$system_probe_config_file" ]; then
        echo "[OK] Found system-probe configuration file $system_probe_config_file"
        config_file_user=$(stat -c '%U' $system_probe_config_file)
        if [ "$config_file_user" = "dd-agent" ]; then
            echo "[OK] dd-agent user is the owner system-probe configuration file $system_probe_config_file"
        else
            echo "[FAIL] Expected dd-agent user to be the owner system-probe configuration file $system_probe_config_file"
            RESULT=1
        fi
        config_file_group=$(stat -c '%G' $system_probe_config_file)
        if [ "$config_file_group" = "dd-agent" ]; then
            echo "[OK] dd-agent group is the owner system-probe configuration file $system_probe_config_file"
        else
            echo "[FAIL] Expected dd-agent group to be the owner system-probe configuration file $system_probe_config_file"
            RESULT=1
        fi
    else
        echo "[FAIL] Expected to find system-probe configuration file $system_probe_config_file"
        RESULT=1
    fi
fi

if [ -n "$DD_APM_INSTRUMENTATION_ENABLED" ] || [ "${SCRIPT_FLAVOR}" == "docker_injection" ]; then
  if command -v dpkg > /dev/null; then
      debsums -c datadog-apm-inject
      debsums -c datadog-apm-library-all
      echo "[OK] Inject libraries installed"
  else
      rpm --verify --nomode --nouser --nogroup datadog-apm-inject
      rpm --verify --nomode --nouser --nogroup datadog-apm-library-all
      echo "[OK] Inject libraries installed"
  fi

  if [ "$DD_APM_INSTRUMENTATION_ENABLED" == "all" ] || [ "$DD_APM_INSTRUMENTATION_ENABLED" == "host" ]; then
    if [ -f "/etc/ld.so.preload" ]; then
      echo "[OK] /etc/ld.so.preload exists"
    else
      echo "[FAIL] Expected to find /etc/ld.so.preload"
      RESULT=1
    fi
  fi
else
  if command -v dpkg > /dev/null && debsums -c datadog-apm-inject ; then
    echo "[FAIL] datadog-apm-inject should not be installed"
    RESULT=1
  elif rpm --verify --nomode --nouser --nogroup datadog-apm-inject ; then
    echo "[FAIL] datadog-apm-inject should not be installed"
    RESULT=1
  else
    echo "[OK] datadog-apm-inject is not installed"
  fi
fi

if [ -n "$DD_APM_INSTRUMENTATION_LANGUAGES" ]; then
  if command -v dpkg > /dev/null; then
    debsums -c datadog-apm-library-all
    echo "[OK] Inject libraries installed"
  else
    rpm --verify --nomode --nouser --nogroup datadog-apm-library-all
    echo "[OK] Inject libraries installed"
  fi
fi

exit ${RESULT}
