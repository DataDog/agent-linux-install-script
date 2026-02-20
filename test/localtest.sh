#!/bin/bash -e

function get_os_type() {
  if command -v dpkg > /dev/null; then
    echo "ubuntu"
  else
    echo "redhat"
  fi
}

# Patch the sources.list file for debian. This is a workaround, we should change the image instead
if [[ "${IMAGE}" =~ "debian:10" ]]; then
  cp ./test/sources10.list /etc/apt/sources.list
elif [[ "${IMAGE}" =~ "debian:11" ]]; then
  cp ./test/sources11.list /etc/apt/sources.list
fi

EXPECTED_FLAVOR=${DD_AGENT_FLAVOR:-datadog-agent}
SCRIPT_FLAVOR=$(echo "${SCRIPT}" | sed "s|.*install_script_\(.*\).sh|\1|")
if [ "${EXPECTED_FLAVOR}" != "datadog-agent" ] && echo "${SCRIPT}" | grep "agent6.sh$" >/dev/null; then
    echo "[PASS] Can't install flavor '${DD_AGENT_FLAVOR}' with install_script_agent6.sh"
    exit 0
fi

cp "$SCRIPT" /tmp/script.sh

# Set up trace capture for telemetry testing (only if SHOW_TRACE is set)
if [[ "${SHOW_TRACE}" == "1" ]]; then
  export TRACE_CAPTURE_FILE="/tmp/captured_traces.json"
  rm -f "$TRACE_CAPTURE_FILE"
  echo "[INFO] Trace capture enabled - traces will be captured to $TRACE_CAPTURE_FILE"
fi

# Override curl to capture trace payloads (only if SHOW_TRACE is enabled)
if [[ "${SHOW_TRACE}" == "1" ]]; then
  # shellcheck disable=SC2317
  curl() {
    if [[ "$*" == *"instrumentation-telemetry-intake"* ]]; then
      echo "[TRACE CAPTURE] Intercepting telemetry submission" >&2
      echo "[TRACE CAPTURE] Full curl args: $*" >&2
      
      # Check if using --data @- (reading from stdin)
      if [[ "$*" == *"--data @-"* ]]; then
        echo "[TRACE CAPTURE] Capturing data from stdin" >&2
        # Read all stdin and save it directly
        cat >> "$TRACE_CAPTURE_FILE"
        echo "[TRACE CAPTURE] Data captured from stdin to $TRACE_CAPTURE_FILE" >&2
      else
        # Extract --data payload from parameters (fallback case)
        while [[ $# -gt 0 ]]; do
          case "$1" in 
            --data)
              if [[ -n "$2" && "$2" != "@-" ]]; then
                echo "$2" >> "$TRACE_CAPTURE_FILE"
                echo "[TRACE CAPTURE] Data parameter written to $TRACE_CAPTURE_FILE" >&2
              fi
              shift 2
              ;;
            --data-raw)
              if [[ -n "$2" ]]; then
                echo "$2" >> "$TRACE_CAPTURE_FILE"
                echo "[TRACE CAPTURE] Data-raw parameter written to $TRACE_CAPTURE_FILE" >&2
              fi
              shift 2
              ;;
            *) 
              shift 
              ;;
          esac
        done
      fi
      
      echo '202'  # Mock successful HTTP response
      return 0
    else
      # Use real curl for all other requests (GPG keys, packages, etc.)
      command curl "$@"
    fi
  }
  export -f curl
fi
if [ "$DD_APM_INSTRUMENTATION_ENABLED" == "all" ] || [ "$DD_APM_INSTRUMENTATION_ENABLED" == "docker" ] || [ "$SCRIPT_FLAVOR" == "docker_injection" ]; then
    # fake presence of docker for the installer
    touch /usr/local/bin/docker && chmod +x /usr/local/bin/docker
    # fake presence of docker and make sure the script doesn't try to restart it
    mkdir /etc/docker
    sed -i "s|dd-container-install --no-agent-restart|dd-container-install --no-agent-restart --no-docker-reload|" /tmp/script.sh
fi
/tmp/script.sh

OS_TYPE=$(get_os_type)
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
if [[ "$OS_TYPE" == "ubuntu" ]]; then
    apt-get install -y debsums

    if [ -z "$DD_NO_AGENT_INSTALL" ]; then
      debsums -c "${EXPECTED_FLAVOR}"
      INSTALLED_VERSION=$(dpkg-query -W "${EXPECTED_FLAVOR}" | cut -f2 | cut -d: -f2)
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

    TOOL_VERSION=$(grep "tool_version:" "$INSTALL_INFO_FILE" | cut -d":" -f 2)
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

# Lint configuration files when they exist
config_file=/etc/datadog-agent/datadog.yaml
security_agent_config_file=/etc/datadog-agent/security-agent.yaml
system_probe_config_file=/etc/datadog-agent/system-probe.yaml
config_files=( "$config_file" "$security_agent_config_file" "$system_probe_config_file" )
mkdir -p "${TESTING_DIR}/artifacts"
for file in "${config_files[@]}"; do
  [ -e "$file" ] && cp "$file" "${TESTING_DIR}/artifacts"
done

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
  test -d /opt/datadog-packages/datadog-apm-inject/stable
  test -d /opt/datadog-packages/datadog-apm-library-dotnet/stable
  test -d /opt/datadog-packages/datadog-apm-library-java/stable
  test -d /opt/datadog-packages/datadog-apm-library-js/stable
  test -d /opt/datadog-packages/datadog-apm-library-python/stable
  test -d /opt/datadog-packages/datadog-apm-library-ruby/stable
  echo "[OK] Inject libraries installed"

  if [ "$DD_APM_INSTRUMENTATION_ENABLED" == "all" ] || [ "$DD_APM_INSTRUMENTATION_ENABLED" == "host" ]; then
    if [ -f "/etc/ld.so.preload" ]; then
      echo "[OK] /etc/ld.so.preload exists"
    else
      echo "[FAIL] Expected to find /etc/ld.so.preload"
      RESULT=1
    fi
  fi
else
  if [[ "$OS_TYPE" == "ubuntu" ]] && debsums -c datadog-apm-inject ; then
    echo "[FAIL] datadog-apm-inject should not be installed"
    RESULT=1
  elif [[ "$OS_TYPE" == "redhat" ]] && rpm --verify --nomode --nouser --nogroup datadog-apm-inject ; then
    echo "[FAIL] datadog-apm-inject should not be installed"
    RESULT=1
  else
    echo "[OK] datadog-apm-inject is not installed"
  fi
fi

if [ -n "$DD_PRIVATE_ACTION_RUNNER_ENABLED" ]; then
  if id dd-scriptuser >/dev/null 2>&1; then
    echo "[OK] dd-scriptuser user exists"
  else
    echo "[FAIL] dd-scriptuser user does not exist"
    RESULT=1
  fi

  SU_RESULT=$(runuser -u dd-agent -- su dd-scriptuser -c whoami 2>/dev/null || true)
  if [ "$SU_RESULT" = "dd-scriptuser" ]; then
    echo "[OK] Can su to dd-scriptuser"
  else
    echo "[FAIL] Cannot su to dd-scriptuser"
    RESULT=1
  fi
fi

if [ -n "$DD_APM_INSTRUMENTATION_LANGUAGES" ]; then
  test -d /opt/datadog-packages/datadog-apm-library-dotnet/stable
  test -d /opt/datadog-packages/datadog-apm-library-java/stable
  test -d /opt/datadog-packages/datadog-apm-library-js/stable
  test -d /opt/datadog-packages/datadog-apm-library-python/stable
  test -d /opt/datadog-packages/datadog-apm-library-ruby/stable
  echo "[OK] Inject libraries installed"
fi

# Validate captured trace data (only if SHOW_TRACE is enabled)
if [[ "${SHOW_TRACE}" == "1" ]]; then
  echo "=== TRACE VALIDATION ==="
if [ -f "$TRACE_CAPTURE_FILE" ]; then
  echo "[OK] Trace data was captured"
  
  # Validate JSON structure
  if command -v jq >/dev/null 2>&1; then
    if jq . "$TRACE_CAPTURE_FILE" >/dev/null 2>&1; then
      echo "[OK] Captured trace is valid JSON"
      
      # Count spans
      SPAN_COUNT=$(jq '.traces[0] | length' "$TRACE_CAPTURE_FILE" 2>/dev/null || echo "0")
      echo "[INFO] Trace contains $SPAN_COUNT spans"
      
      # Check for root span
      ROOT_SPANS=$(jq '.traces[0] | map(select(.parent_id == null)) | length' "$TRACE_CAPTURE_FILE" 2>/dev/null || echo "0")
      if [ "$ROOT_SPANS" = "1" ]; then
        echo "[OK] Found 1 root span"
      else
        echo "[WARN] Expected 1 root span, found $ROOT_SPANS"
      fi
      
      # List stage spans
      STAGE_SPANS=$(jq -r '.traces[0][] | select(.parent_id != null) | .name' "$TRACE_CAPTURE_FILE" 2>/dev/null || true)
      if [ -n "$STAGE_SPANS" ]; then
        echo "[INFO] Stage spans found:"
        echo "$STAGE_SPANS" | sed 's/^/  - /'
      fi
      
    else
      echo "[FAIL] Captured trace is not valid JSON"
      RESULT=1
    fi
  else
    echo "[INFO] jq not available, skipping JSON validation"
  fi
  
  echo "[INFO] Captured trace data:"
  echo "----------------------------------------"
  cat "$TRACE_CAPTURE_FILE"
  echo "----------------------------------------"
  
else
  echo "[WARN] No trace data was captured (file not found: $TRACE_CAPTURE_FILE)"
fi
  echo "=== END TRACE VALIDATION ==="
fi

exit ${RESULT}
