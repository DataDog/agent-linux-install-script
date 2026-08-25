#!/bin/bash -e

function get_os_type() {
  if command -v dpkg > /dev/null; then
    echo "ubuntu"
  else
    echo "redhat"
  fi
}

function dpkg_path_is_excluded() {
  local package_path=$1
  local config_path
  local line
  local directive
  local pattern
  local decision=include
  local -a config_paths=(/etc/dpkg/dpkg.cfg /etc/dpkg/dpkg.cfg.d/*)

  for config_path in "${config_paths[@]}"; do
    [ -f "$config_path" ] || continue
    while IFS= read -r line || [ -n "$line" ]; do
      line=${line#"${line%%[![:space:]]*}"}
      case "$line" in
        path-exclude=*|path-include=*)
          directive=${line%%=*}
          pattern=${line#*=}
          # shellcheck disable=SC2053
          if [[ "$package_path" == $pattern ]]; then
            case "$directive" in
              path-exclude) decision=exclude ;;
              path-include) decision=include ;;
            esac
          fi
          ;;
      esac
    done < "$config_path"
  done

  [ "$decision" = exclude ]
}

function verify_iot_dpkg_policy() {
  local filter_path=$1
  local package_path
  local result=0
  local -a included_paths=(
    /opt/datadog-agent/bin/agent/agent
    /opt/datadog-agent/embedded/bin/agent-data-plane
    /opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so
    /opt/datadog-agent/bin/agent/dist/views/index.html
    /etc/datadog-agent/conf.d/cpu.d/conf.yaml.example
  )
  local -a excluded_paths=(
    /opt/datadog-agent/embedded/bin/python3
    /opt/datadog-agent/bin/process-agent/process-agent
    /opt/datadog-agent/embedded/bin/system-probe
    /opt/datadog-agent/embedded/share/ebpf/co-re.o
    /opt/datadog-agent/bin/agent/dist/jmx/jmxfetch.jar
    /etc/datadog-agent/conf.d/docker.d/conf.yaml.example
  )

  for package_path in "${included_paths[@]}"; do
    if dpkg_path_is_excluded "$package_path"; then
      echo "[FAIL] Persistent filtered IoT dpkg policy excludes required path $package_path"
      result=1
    fi
  done
  for package_path in "${excluded_paths[@]}"; do
    if ! dpkg_path_is_excluded "$package_path"; then
      echo "[FAIL] Persistent filtered IoT dpkg policy includes disallowed path $package_path"
      result=1
    fi
  done
  if [ -f "$filter_path" ] && grep -Fqx 'path-include=/opt/datadog-agent/embedded/bin/installer' "$filter_path"; then
    echo "[FAIL] Persistent filtered IoT dpkg policy retains the transient installer rule"
    result=1
  fi
  if [ -e /opt/datadog-agent/embedded/bin/installer ] || [ -L /opt/datadog-agent/embedded/bin/installer ]; then
    echo "[FAIL] Filtered IoT install retains the package installer binary"
    result=1
  fi

  return "$result"
}

function verify_iot_debsums() {
  local package_name=$1
  local output_path
  local debsums_status=0
  local line
  local missing_path
  local missing_count=0
  local failure_count=0

  output_path=$(mktemp)
  debsums -as "$package_name" > "$output_path" 2>&1 || debsums_status=$?
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "debsums: missing file "*)
        missing_path=${line#debsums: missing file }
        missing_path=${missing_path%% (from *}
        if [[ "$missing_path" != /* ]] || ! dpkg_path_is_excluded "$missing_path"; then
          echo "[FAIL] Missing package path is not excluded by the installed dpkg rules: $line"
          failure_count=$((failure_count + 1))
        else
          missing_count=$((missing_count + 1))
        fi
        ;;
      "") ;;
      *)
        echo "[FAIL] Retained package checksum error: $line"
        failure_count=$((failure_count + 1))
        ;;
    esac
  done < "$output_path"
  rm -f "$output_path"

  if [ "$failure_count" -ne 0 ]; then
    return 1
  fi
  if [ "$debsums_status" -ne 0 ] && [ "$missing_count" -eq 0 ]; then
    echo "[FAIL] debsums failed without reporting an excluded missing path (status $debsums_status)"
    return 1
  fi
  echo "[OK] All $missing_count reported missing package paths are excluded by installed dpkg rules; retained checksums are valid"
}

function verify_iot_filtered_layout() {
  local required_path
  local check_name
  local unexpected_path
  local result=0
  local -a required_executables=(
    /opt/datadog-agent/bin/agent/agent
    /opt/datadog-agent/embedded/bin/agent-data-plane
  )
  local -a retained_checks=(
    cpu disk io load memory network ntp uptime system_swap systemd jetson
  )
  local -a excluded_roots=(
    /opt/datadog-agent/embedded/include
    /opt/datadog-agent/embedded/msodbcsql
    /opt/datadog-agent/embedded/sbin
    /opt/datadog-agent/embedded/share/ebpf
    /opt/datadog-agent/embedded/share/system-probe
    /opt/datadog-agent/python-scripts
    /opt/datadog-agent/requirements
    /opt/datadog-agent/compliance
    /opt/datadog-agent/runtime-security.d
    /etc/datadog-agent/compliance.d
    /etc/datadog-agent/runtime-security.d
    /etc/datadog-agent/conf.d/docker.d
  )

  for required_path in "${required_executables[@]}"; do
    if [ ! -f "$required_path" ] || [ -L "$required_path" ] || [ ! -x "$required_path" ]; then
      echo "[FAIL] Filtered layout is missing required executable $required_path"
      result=1
    fi
  done
  if ! compgen -G '/opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so*' >/dev/null; then
    echo "[FAIL] Filtered layout is missing the rtloader library"
    result=1
  fi
  if ! find /opt/datadog-agent/bin/agent/dist/views -type f -print -quit 2>/dev/null | grep -q .; then
    echo "[FAIL] Filtered layout is missing support view content"
    result=1
  fi
  for check_name in "${retained_checks[@]}"; do
    if ! find "/etc/datadog-agent/conf.d/$check_name.d" -type f -print -quit 2>/dev/null | grep -q .; then
      echo "[FAIL] Filtered layout is missing retained $check_name check configuration"
      result=1
    fi
  done
  for required_path in "${excluded_roots[@]}"; do
    [ -e "$required_path" ] || [ -L "$required_path" ] || continue
    unexpected_path=$(find "$required_path" \( -type f -o -type l \) -print -quit 2>/dev/null) || {
      echo "[FAIL] Unable to inspect excluded payload root $required_path"
      result=1
      continue
    }
    if [ -n "$unexpected_path" ] && { [ ! -L "$unexpected_path" ] || [ -e "$unexpected_path" ]; }; then
      echo "[FAIL] Excluded payload remains at $unexpected_path"
      result=1
    fi
  done
  for required_path in \
    /opt/datadog-agent/bin/process-agent \
    /opt/datadog-agent/embedded/bin/python3 \
    /opt/datadog-agent/requirements-agent-release.txt; do
    if [ -e "$required_path" ]; then
      echo "[FAIL] Excluded payload remains at $required_path"
      result=1
    fi
  done

  return "$result"
}

# Patch the sources.list file for debian. This is a workaround, we should change the image instead
if [[ "${IMAGE}" =~ "debian:10" ]]; then
  cp ./test/sources10.list /etc/apt/sources.list
elif [[ "${IMAGE}" =~ "debian:11" ]]; then
  cp ./test/sources11.list /etc/apt/sources.list
fi

SCRIPT_FLAVOR=$(echo "${SCRIPT}" | sed "s|.*install_script_\(.*\).sh|\1|")
EXPECTED_FLAVOR=${DD_AGENT_FLAVOR:-datadog-agent}
if [ "${SCRIPT_FLAVOR}" == "agent7_iot" ]; then
    EXPECTED_FLAVOR=datadog-agent
fi
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
  # shellcheck disable=SC2317,SC2329
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
if [ "${SCRIPT_FLAVOR}" == "agent7" ] || [ "${SCRIPT_FLAVOR}" == "agent7_iot" ] || [ "${EXPECTED_FLAVOR}" != "datadog-agent" ] ; then
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
      if [ "${SCRIPT_FLAVOR}" = "agent7_iot" ]; then
        if ! verify_iot_debsums "${EXPECTED_FLAVOR}"; then
          RESULT=1
        fi
      elif ! debsums -c "${EXPECTED_FLAVOR}"; then
        RESULT=1
      fi
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
elif [ "${SCRIPT_FLAVOR}" == "agent7_iot" ]; then
    EXPECTED_TOOL_VERSION="install_script_agent7_iot"
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

if [ "${SCRIPT_FLAVOR}" = "agent7_iot" ] && [ -z "$DD_NO_AGENT_INSTALL" ]; then
  iot_filter=/etc/dpkg/dpkg.cfg.d/99-datadog-iot
  if [ ! -f "$iot_filter" ] || [ -L "$iot_filter" ]; then
    echo "[FAIL] Persistent filtered IoT dpkg configuration is missing or is not a regular file"
    RESULT=1
  elif [ "$(stat -c '%u:%g:%a' "$iot_filter")" != "0:0:644" ]; then
    echo "[FAIL] Persistent filtered IoT dpkg configuration must be root:root mode 0644"
    RESULT=1
  elif grep -Ev '^(path-exclude|path-include)=/' "$iot_filter" | grep -q .; then
    echo "[FAIL] Persistent filtered IoT dpkg configuration contains an invalid directive"
    RESULT=1
  else
    echo "[OK] Persistent filtered IoT dpkg configuration has the expected ownership and mode"
  fi
  if ! verify_iot_dpkg_policy "$iot_filter"; then
    RESULT=1
  else
    echo "[OK] Persistent filtered IoT dpkg policy has the expected effective decisions"
  fi

  if ! grep -q '^infrastructure_mode: iot$' /etc/datadog-agent/datadog.yaml; then
    echo "[FAIL] Filtered IoT configuration does not set infrastructure_mode: iot"
    RESULT=1
  else
    echo "[OK] Filtered IoT infrastructure mode is configured"
  fi
  if [ -e /etc/datadog-agent/install_profile ] || [ -L /etc/datadog-agent/install_profile ]; then
    echo "[FAIL] Final filtered IoT install profile marker must not be written by this draft"
    RESULT=1
  else
    echo "[OK] Final filtered IoT install profile marker is absent"
  fi
  if ! verify_iot_filtered_layout; then
    RESULT=1
  else
    echo "[OK] Filtered IoT retained and excluded layout is valid"
  fi
  if ! /opt/datadog-agent/bin/agent/agent version; then
    echo "[FAIL] Filtered normal Agent version command failed"
    RESULT=1
  fi

  mkdir -p "${TESTING_DIR}/artifacts"
  iot_logical_bytes=$(du -sb /opt/datadog-agent /etc/datadog-agent | awk '{total += $1} END {print total}')
  printf '%s\n' "$iot_logical_bytes" | tee "${TESTING_DIR}/artifacts/iot-installed-bytes.txt"
  echo "[INFO] Filtered IoT installed logical bytes: $iot_logical_bytes"
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
