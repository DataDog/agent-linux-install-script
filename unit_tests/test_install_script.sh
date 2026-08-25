#!/usr/bin/env bash

dir_path=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=/dev/null
source "${dir_path}/extracted_functions.sh"
yaml_config="$(dirname "$dir_path")/.yamllint.yaml"
config_file="/etc/datadog-agent/datadog.yaml"
security_agent_config_file="/etc/datadog-agent/security-agent.yaml"
system_probe_config_file="/etc/datadog-agent/system-probe.yaml"

### ensure_config_file_exists
testEnsureExists() {
  ensure_config_file_exists "sudo" "/etc/hosts" "root"
  assertEquals 1 $?
}
testEnsureExistsWrongSudo() {
  sudo rm /etc/datadog-agent/datadog.yaml
  ensure_config_file_exists "sumo" $config_file "dd-agent"
  assertEquals 125 $?
}
testEnsureExistsFailsWrongUser() {
  sudo rm /etc/datadog-agent/datadog.yaml
  ensure_config_file_exists "sudo" $config_file "datad0g-agent"
  assertEquals 1 $?
}
testEnsureNotExists() {
  sudo rm /etc/datadog-agent/datadog.yaml
  ensure_config_file_exists "sudo" $config_file "dd-agent"
  assertEquals 0 $?
}

### update_api_key
testUpdateKey() {
  sudo cp ${config_file}.example $config_file
  update_api_key "sudo" "123" $config_file
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  sudo grep -w "^api_key: 123$" $config_file | sudo tee tmp > /dev/null
  assertEquals 0 $?
  nb_match=$(sudo cat tmp | wc -l)
  assertEquals 1 "$nb_match"
}
testNoKey() {
  sudo cp ${config_file}.example $config_file
  update_api_key "sudo" "" $config_file
  sudo grep -wq "^api_key:" $config_file
  assertEquals 0 $?
}

testUpdateAppKey() {
  sudo cp ${config_file}.example $config_file
  update_api_key "sudo" "testapikey" $config_file
  update_app_key "sudo" "testappkey123" $config_file
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  sudo grep -w "^app_key: testappkey123$" $config_file | sudo tee tmp > /dev/null
  assertEquals 0 $?
  nb_match=$(sudo cat tmp | wc -l)
  assertEquals 1 "$nb_match"
}
testNoAppKey() {
  sudo cp ${config_file}.example $config_file
  update_app_key "sudo" "" $config_file
  sudo grep -wq "^app_key:" $config_file
  assertEquals 1 $?
}
testUpdateAppKeyWhenExists() {
  sudo cp ${config_file}.example $config_file
  update_api_key "sudo" "testapikey" $config_file
  update_app_key "sudo" "firstappkey" $config_file
  update_app_key "sudo" "updatedappkey" $config_file
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.app_key' $config_file)" "updatedappkey"
}

### update_site
testUpdateSite() {
  sudo cp ${config_file}.example $config_file
  update_site "sudo" "d4t4d0g.cat" $config_file
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  sudo grep -w "^site: d4t4d0g.cat" $config_file | sudo tee tmp > /dev/null
  assertEquals 0 $?
  nb_match=$(sudo cat tmp | wc -l)
  assertEquals 1 "$nb_match"
}
testNoSite() {
  sudo cp ${config_file}.example $config_file
  update_site "sudo" "" $config_file
  sudo grep -wq "^# site: datadoghq.com$" $config_file || sudo grep -wq "^# site: \"datadoghq.com\"$" $config_file
  assertEquals 0 $?
}

### update_url
testUrlUpdated() {
  sudo cp ${config_file}.example $config_file
  update_url "sudo" "https:\/\/d4t4d0g.cat" $config_file
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  sudo grep -w "^dd_url: https:\/\/d4t4d0g.cat" $config_file | sudo tee tmp > /dev/null
  assertEquals 0 $?
  nb_match=$(sudo cat tmp | wc -l)
  assertEquals 1 "$nb_match"
}
testNoUrl() {
  sudo cp ${config_file}.example $config_file
  update_url "sudo" "" $config_file
  sudo grep -wq "^# dd_url: https:\/\/app.datadoghq.com$" $config_file || sudo grep -wq "^# dd_url: \"https:\/\/app.datadoghq.com\"$" $config_file
  assertEquals 0 $?
}

### update_fips
testUpdateFips() {
  sudo cp ${config_file}.example $config_file
  update_fips "sudo" $config_file
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  sudo grep -q 9803 $config_file
  assertEquals 0 $?
}

### update_hostname
testHostnameUpdated() {
  sudo cp ${config_file}.example $config_file
  update_hostname "sudo" "gandalf" $config_file
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  sudo grep -w "^hostname: gandalf$" $config_file | sudo tee tmp > /dev/null
  assertEquals 0 $?
  nb_match=$(sudo cat tmp | wc -l)
  assertEquals 1 "$nb_match"
}
testNoHostname() {
  sudo cp ${config_file}.example $config_file
  update_hostname "sudo" "" $config_file
  sudo grep -wq "^# hostname: <HOSTNAME_NAME>$" $config_file
  assertEquals 0 $?
}

### update_hosttags
testHostTagsUpdated() {
  sudo cp ${config_file}.example $config_file
  update_hosttags "sudo" "foo:bar,titi:toto,allowedchars:a1_-:./" $config_file
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  sudo grep -w "^tags: \['foo:bar', 'titi:toto', 'allowedchars:a1_-:./'\]" $config_file | sudo tee tmp > /dev/null
  assertEquals 0 $?
  nb_match=$(sudo cat tmp | wc -l)
  assertEquals 1 "$nb_match"
}
testNoHostTags() {
  sudo cp ${config_file}.example $config_file
  update_hosttags "sudo" "" $config_file
  sudo grep -wq "^# tags:$" $config_file
  assertEquals 0 $?
}

### update_env
testEnvUpdated(){
  sudo cp ${config_file}.example $config_file
  update_env "sudo" "interstellar" $config_file
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  sudo grep -w "^env: interstellar" $config_file | sudo tee tmp > /dev/null
  assertEquals 0 $?
  nb_match=$(sudo cat tmp | wc -l)
  assertEquals 1 "$nb_match"
}
testNoEnv(){
  sudo cp ${config_file}.example $config_file
  update_env "sudo" "" $config_file
  sudo grep -wq "^# env: <environment name>$" $config_file
  assertEquals 0 $?
}

### update_infrastructure_mode
testInfrastructureModeUpdated(){
  sudo cp ${config_file}.example $config_file
  update_infrastructure_mode "sudo" "basic" $config_file
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  sudo grep -w "^infrastructure_mode: basic" $config_file | sudo tee tmp > /dev/null
  assertEquals 0 $?
  nb_match=$(sudo cat tmp | wc -l)
  assertEquals 1 "$nb_match"
}
testNoInfrastructureMode(){
  sudo cp ${config_file}.example $config_file
  update_infrastructure_mode "sudo" "" $config_file
  sudo grep -wq "^infrastructure_mode:" $config_file
  assertEquals 1 $?
}

### update_security_and_or_compliance
testRuntimeSecurityUpdated() {
  sudo cp ${security_agent_config_file}.example $security_agent_config_file
  update_security_and_or_compliance "sudo" $security_agent_config_file true false
  yamllint -c "$yaml_config" --no-warnings $security_agent_config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.runtime_security_config.enabled' $security_agent_config_file)" "true"
}
testRuntimeSecurityUpdatedSystemPrope() {
  sudo cp ${system_probe_config_file}.example $system_probe_config_file
  update_security_and_or_compliance "sudo" $system_probe_config_file true false
  yamllint -c "$yaml_config" --no-warnings $system_probe_config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.runtime_security_config.enabled' $system_probe_config_file)" "true"
}
testComplianceConfigurationUpdated() {
  sudo cp ${security_agent_config_file}.example $security_agent_config_file
  update_security_and_or_compliance "sudo" $security_agent_config_file false true
  yamllint -c "$yaml_config" --no-warnings $security_agent_config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.compliance_config.enabled' $security_agent_config_file)" "true"
}
testSecurityAndComplianceEnabled() {
  sudo cp ${security_agent_config_file}.example $security_agent_config_file
  sudo cp ${system_probe_config_file}.example $system_probe_config_file
  update_security_and_or_compliance "sudo" $security_agent_config_file true true
  yamllint -c "$yaml_config" --no-warnings $security_agent_config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.runtime_security_config.enabled' $security_agent_config_file)" "true"
  assertEquals "$(sudo yq eval '.compliance_config.enabled' $security_agent_config_file)" "true"
}
testSecurityAndComplianceDisabled() {
  sudo cp ${security_agent_config_file}.example $security_agent_config_file
  update_security_and_or_compliance "sudo" $security_agent_config_file false false
  assertEquals "$(sudo yq eval '.runtime_security_config.enabled' $security_agent_config_file)" "null"
  assertEquals "$(sudo yq eval '.compliance_config.enabled' $security_agent_config_file)" "null"
}

### Manage security config files
testSecurityConfigNoCreation() {
  sudo rm $security_agent_config_file 2> /dev/null
  manage_security_config "sudo" $security_agent_config_file false false
  sudo test -e $security_agent_config_file
  assertEquals 1 $?
}
testSecurityConfigPreventOnBoth() {
  sudo cp ${security_agent_config_file}.example $security_agent_config_file
  manage_security_config "sudo" $security_agent_config_file true true
  assertEquals "$(sudo yq eval '.runtime_security_config.enabled' $security_agent_config_file)" "null"
  assertEquals "$(sudo yq eval '.compliance_config.enabled' $security_agent_config_file)" "null"
}
testSecurityConfigComplianceOnSecurity(){
  sudo rm $security_agent_config_file 2> /dev/null
  manage_security_config "sudo" $security_agent_config_file false true
  yamllint -c "$yaml_config" --no-warnings $security_agent_config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.compliance_config.enabled' $security_agent_config_file)" "true"
}
testSecurityConfigSecOnBoth(){
  sudo rm $security_agent_config_file 2> /dev/null
  manage_security_config "sudo" $security_agent_config_file true false
  yamllint -c "$yaml_config" --no-warnings $security_agent_config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.runtime_security_config.enabled' $security_agent_config_file)" "true"
  assertEquals "$(sudo yq eval '.compliance_config.enabled' $security_agent_config_file)" "null"
}
testSecurityConfigFullConfig(){
  sudo rm $security_agent_config_file 2> /dev/null
  manage_security_config "sudo" $security_agent_config_file true true
  yamllint -c "$yaml_config" --no-warnings $security_agent_config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.runtime_security_config.enabled' $security_agent_config_file)" "true"
  assertEquals "$(sudo yq eval '.compliance_config.enabled' $security_agent_config_file)" "true"
}

### Manage system probe config files
testSystemProbeConfigNoCreation() {
  sudo rm $system_probe_config_file 2> /dev/null
  manage_system_probe_config "sudo" $system_probe_config_file false false "" false
  sudo test -e $system_probe_config_file
  assertEquals 1 $?
}
testSystemProbeConfigSecOn(){
  sudo rm $system_probe_config_file 2> /dev/null
  manage_system_probe_config "sudo" $system_probe_config_file true false "" false
  yamllint -c "$yaml_config" --no-warnings $system_probe_config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.runtime_security_config.enabled' $system_probe_config_file)" "true"
  assertEquals "$(sudo yq eval '.discovery.enabled' $system_probe_config_file)" "null"
  assertEquals "$(sudo yq eval '.privileged_logs.enabled' $system_probe_config_file)" "null"
}
testSystemProbeConfigDiscoveryOn(){
  sudo rm $system_probe_config_file 2> /dev/null
  manage_system_probe_config "sudo" $system_probe_config_file false true "" false
  yamllint -c "$yaml_config" --no-warnings $system_probe_config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.runtime_security_config.enabled' $system_probe_config_file)" "null"
  assertEquals "$(sudo yq eval '.discovery.enabled' $system_probe_config_file)" "true"
  assertEquals "$(sudo yq eval '.privileged_logs.enabled' $system_probe_config_file)" "null"
}
testSystemProbeConfigPrivilegedLogsOn(){
  sudo rm $system_probe_config_file 2> /dev/null
  manage_system_probe_config "sudo" $system_probe_config_file false false true false
  yamllint -c "$yaml_config" --no-warnings $system_probe_config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.runtime_security_config.enabled' $system_probe_config_file)" "null"
  assertEquals "$(sudo yq eval '.discovery.enabled' $system_probe_config_file)" "null"
  assertEquals "$(sudo yq eval '.privileged_logs.enabled' $system_probe_config_file)" "true"
}
testSystemProbeConfigPrivilegedLogsAndDiscovery(){
  sudo rm $system_probe_config_file 2> /dev/null
  manage_system_probe_config "sudo" $system_probe_config_file false true true false
  yamllint -c "$yaml_config" --no-warnings $system_probe_config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.runtime_security_config.enabled' $system_probe_config_file)" "null"
  assertEquals "$(sudo yq eval '.discovery.enabled' $system_probe_config_file)" "true"
  assertEquals "$(sudo yq eval '.privileged_logs.enabled' $system_probe_config_file)" "true"
}
testSystemProbeConfigFullConfig(){
  sudo rm $system_probe_config_file 2> /dev/null
  manage_system_probe_config "sudo" $system_probe_config_file true true true false
  yamllint -c "$yaml_config" --no-warnings $system_probe_config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.runtime_security_config.enabled' $system_probe_config_file)" "true"
  assertEquals "$(sudo yq eval '.discovery.enabled' $system_probe_config_file)" "true"
  assertEquals "$(sudo yq eval '.privileged_logs.enabled' $system_probe_config_file)" "true"
}
testSystemProbeConfigPrivilegedLogsExplicitlyDisabled(){
  sudo rm $system_probe_config_file 2> /dev/null
  manage_system_probe_config "sudo" $system_probe_config_file false false false false
  yamllint -c "$yaml_config" --no-warnings $system_probe_config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.runtime_security_config.enabled' $system_probe_config_file)" "null"
  assertEquals "$(sudo yq eval '.discovery.enabled' $system_probe_config_file)" "null"
  assertEquals "$(sudo yq eval '.privileged_logs.enabled' $system_probe_config_file)" "false"
}

### Test logs config process collect all function
testLogsConfigProcessCollectAll() {
  sudo rm $config_file 2> /dev/null
  ensure_config_file_exists "sudo" $config_file "dd-agent"
  update_logs_config_process_collect_all "sudo" $config_file
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?

  # Test logs_enabled is set to true
  assertEquals "$(sudo yq eval '.logs_enabled' $config_file)" "true"

  # Test process_config.process_collection.use_wlm is set to true
  assertEquals "$(sudo yq eval '.process_config.process_collection.use_wlm' $config_file)" "true"

  # Test extra_config_providers contains process_log
  assertEquals "$(sudo yq eval 'contains({"extra_config_providers": "process_log"})' $config_file)" "true"

  # Test logs_config.process_exclude_agent is set to true
  assertEquals "$(sudo yq eval '.logs_config.process_exclude_agent' $config_file)" "true"

  # Test logs_config.auto_multi_line_detection is set to true
  assertEquals "$(sudo yq eval '.logs_config.auto_multi_line_detection' $config_file)" "true"
}

### Test update_par function
testParDisabled() {
  sudo rm $config_file 2> /dev/null
  ensure_config_file_exists "sudo" $config_file "dd-agent"
  update_par "sudo" $config_file "false" ""
  # Should not add private_action_runner section
  sudo grep -q "^private_action_runner:" $config_file
  assertEquals 1 $?
}
testParEnabledNoActions() {
  sudo rm $config_file 2> /dev/null
  ensure_config_file_exists "sudo" $config_file "dd-agent"
  update_par "sudo" $config_file "true" ""
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.private_action_runner.enabled' $config_file)" "true"
  assertEquals "$(sudo yq eval '.private_action_runner.actions_allowlist' $config_file)" "null"
}
testParEnabledWithSingleAction() {
  sudo rm $config_file 2> /dev/null
  ensure_config_file_exists "sudo" $config_file "dd-agent"
  update_par "sudo" $config_file "true" "com.datadoghq.script.runPredefinedScript"
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.private_action_runner.enabled' $config_file)" "true"
  assertEquals "$(sudo yq eval '.private_action_runner.actions_allowlist[0]' $config_file)" "com.datadoghq.script.runPredefinedScript"
}
testParEnabledWithMultipleActions() {
  sudo rm $config_file 2> /dev/null
  ensure_config_file_exists "sudo" $config_file "dd-agent"
  update_par "sudo" $config_file "true" "com.datadoghq.script.runPredefinedScript,com.datadoghq.script.runShellScript"
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.private_action_runner.enabled' $config_file)" "true"
  assertEquals "$(sudo yq eval '.private_action_runner.actions_allowlist[0]' $config_file)" "com.datadoghq.script.runPredefinedScript"
  assertEquals "$(sudo yq eval '.private_action_runner.actions_allowlist[1]' $config_file)" "com.datadoghq.script.runShellScript"
}
testParConfigAlreadyExists() {
  sudo rm $config_file 2> /dev/null
  ensure_config_file_exists "sudo" $config_file "dd-agent"
  # Add existing PAR config
  echo "private_action_runner:" | sudo tee -a $config_file > /dev/null
  echo "  enabled: false" | sudo tee -a $config_file > /dev/null
  # Try to update PAR config
  update_par "sudo" $config_file "true" "com.datadoghq.test.action"
  # Should not modify existing config
  assertEquals "$(sudo yq eval '.private_action_runner.enabled' $config_file)" "false"
}
testParEnabledWithApiKeyOnlyEnrollment() {
  sudo rm $config_file 2> /dev/null
  ensure_config_file_exists "sudo" $config_file "dd-agent"
  update_par "sudo" $config_file "true" "" "true"
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.private_action_runner.enabled' $config_file)" "true"
  assertEquals "$(sudo yq eval '.private_action_runner.api_key_only_enrollment' $config_file)" "true"
}
testParEnabledWithoutApiKeyOnlyEnrollment() {
  sudo rm $config_file 2> /dev/null
  ensure_config_file_exists "sudo" $config_file "dd-agent"
  update_par "sudo" $config_file "true" ""
  # Should not add api_key_only_enrollment when not provided
  assertEquals "$(sudo yq eval '.private_action_runner.api_key_only_enrollment' $config_file)" "null"
}

### Filtered IoT install helpers
assertIotContains() {
  local message="$1"
  local actual="$2"
  local expected="$3"

  if [[ "$actual" == *"$expected"* ]]; then
    assertTrue "$message" 0
  else
    assertTrue "$message: expected <$actual> to contain <$expected>" 1
  fi
}

assertIotNotContains() {
  local message="$1"
  local actual="$2"
  local unexpected="$3"

  if [[ "$actual" == *"$unexpected"* ]]; then
    assertTrue "$message: expected <$actual> not to contain <$unexpected>" 1
  else
    assertTrue "$message" 0
  fi
}

iotDpkgPathIsIncluded() {
  local config_file_path="$1"
  local package_path="$2"
  local directive
  local pattern
  local decision="include"

  while IFS='=' read -r directive pattern; do
    # shellcheck disable=SC2053
    if [[ "$package_path" == $pattern ]]; then
      case "$directive" in
        path-exclude) decision="exclude" ;;
        path-include) decision="include" ;;
      esac
    fi
  done < "$config_file_path"

  [ "$decision" = "include" ]
}

createIotRetainedLayout() {
  local root="$1"
  local check_name
  local -a check_names=(
    cpu disk io load memory network ntp uptime system_swap systemd jetson
  )

  mkdir -p \
    "$root/opt/datadog-agent/bin/agent/dist/views" \
    "$root/opt/datadog-agent/embedded/bin" \
    "$root/opt/datadog-agent/embedded/lib" \
    "$root/etc/datadog-agent/conf.d"
  touch \
    "$root/opt/datadog-agent/bin/agent/agent" \
    "$root/opt/datadog-agent/bin/agent/dist/views/index.html" \
    "$root/opt/datadog-agent/embedded/bin/agent-data-plane" \
    "$root/opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so" \
    "$root/etc/datadog-agent/datadog.yaml.example"
  chmod +x \
    "$root/opt/datadog-agent/bin/agent/agent" \
    "$root/opt/datadog-agent/embedded/bin/agent-data-plane"

  for check_name in "${check_names[@]}"; do
    mkdir -p "$root/etc/datadog-agent/conf.d/$check_name.d"
    touch "$root/etc/datadog-agent/conf.d/$check_name.d/conf.yaml.example"
  done
}

testIotOptionsAcceptSupportedMode() {
  validate_iot_installer_options "" "7" "" "" "" "" "" "" "" "" "" "" "" "" "" ""
  assertEquals "unset compatible options should be accepted" 0 $?

  validate_iot_installer_options "datadog-agent" "7" "iot" "" "" "" "" "" "" "" "" "" "" "" "" ""
  assertEquals "explicit filtered IoT options should be accepted" 0 $?
}

testIotOptionsRejectNonAgentFlavors() {
  local flavor
  local output
  local status

  for flavor in datadog-iot-agent datadog-fips-agent datadog-dogstatsd; do
    output=$(validate_iot_installer_options "$flavor" "7" "iot" "" "" "" "" "" "" "" "" "" "" "" "" "" 2>&1)
    status=$?
    assertNotEquals "$flavor should be rejected" 0 "$status"
    assertIotContains "$flavor rejection should name DD_AGENT_FLAVOR" "$output" "DD_AGENT_FLAVOR"
    assertEquals "$flavor rejection should be one actionable message" 1 "$(printf '%s\n' "$output" | wc -l | tr -d ' ')"
  done
}

testIotOptionsRejectIncompatibleValues() {
  local -a option_names=(
    DD_AGENT_MAJOR_VERSION
    DD_INFRASTRUCTURE_MODE
    DD_FIPS_MODE
    DD_APM_INSTRUMENTATION_ENABLED
    DD_APM_INSTRUMENTATION_LIBRARIES
    DD_OTELCOLLECTOR_ENABLED
    DD_REMOTE_UPDATES
    DD_NO_AGENT_INSTALL
    DD_UPGRADE
    DD_RUNTIME_SECURITY_CONFIG_ENABLED
    DD_COMPLIANCE_CONFIG_ENABLED
    DD_DISCOVERY_ENABLED
    DD_SYSTEM_PROBE_SERVICE_MONITORING_ENABLED
    DD_PRIVILEGED_LOGS_ENABLED
    DD_PRIVATE_ACTION_RUNNER_ENABLED
  )
  local -a incompatible_values=(
    6
    basic
    true
    host
    java
    true
    true
    true
    true
    true
    true
    true
    true
    true
    true
  )
  local -a arguments
  local index
  local output
  local status

  for index in "${!option_names[@]}"; do
    arguments=(datadog-agent 7 iot "" "" "" "" "" "" "" "" "" "" "" "" "")
    arguments[index + 1]="${incompatible_values[$index]}"
    output=$(validate_iot_installer_options "${arguments[@]}" 2>&1)
    status=$?
    assertNotEquals "${option_names[$index]} should be rejected" 0 "$status"
    assertIotContains "rejection should name ${option_names[$index]}" "$output" "${option_names[$index]}"
  done
}

testDebIotFilterConfigIsDeterministicAndUnique() {
  local test_dir
  local filter_path
  local expected
  local duplicate_count

  test_dir=$(mktemp -d)
  filter_path="$test_dir/99-datadog-iot"
  write_deb_iot_filter_config "$filter_path"
  assertEquals "filter writer should succeed" 0 $?

  expected='path-exclude=/opt/datadog-agent/bin/*
path-exclude=/opt/datadog-agent/embedded/bin/*
path-exclude=/opt/datadog-agent/embedded/include/*
path-exclude=/opt/datadog-agent/embedded/lib/libodbc*
path-exclude=/opt/datadog-agent/embedded/lib/libpython*
path-exclude=/opt/datadog-agent/embedded/lib/libtdsodbc*
path-exclude=/opt/datadog-agent/embedded/lib/python*
path-exclude=/opt/datadog-agent/embedded/msodbcsql/*
path-exclude=/opt/datadog-agent/embedded/sbin/*
path-exclude=/opt/datadog-agent/embedded/share/ebpf/*
path-exclude=/opt/datadog-agent/embedded/share/msodbcsql*
path-exclude=/opt/datadog-agent/embedded/share/system-probe/*
path-exclude=/opt/datadog-agent/python-scripts/*
path-exclude=/opt/datadog-agent/requirements/*
path-exclude=/opt/datadog-agent/requirements*.txt
path-exclude=/opt/datadog-agent/compliance/*
path-exclude=/opt/datadog-agent/runtime-security.d/*
path-exclude=/etc/datadog-agent/compliance.d/*
path-exclude=/etc/datadog-agent/runtime-security.d/*
path-exclude=/etc/datadog-agent/conf.d/*
path-include=/opt/datadog-agent/bin
path-include=/opt/datadog-agent/bin/agent
path-include=/opt/datadog-agent/bin/agent/agent
path-include=/opt/datadog-agent/bin/agent/dist
path-include=/opt/datadog-agent/bin/agent/dist/views
path-include=/opt/datadog-agent/bin/agent/dist/views/*
path-include=/opt/datadog-agent/embedded/bin
path-include=/opt/datadog-agent/embedded/bin/agent-data-plane
path-include=/opt/datadog-agent/embedded/lib
path-include=/opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so*
path-include=/etc/datadog-agent/conf.d
path-include=/etc/datadog-agent/conf.d/cpu.d
path-include=/etc/datadog-agent/conf.d/cpu.d/*
path-include=/etc/datadog-agent/conf.d/disk.d
path-include=/etc/datadog-agent/conf.d/disk.d/*
path-include=/etc/datadog-agent/conf.d/io.d
path-include=/etc/datadog-agent/conf.d/io.d/*
path-include=/etc/datadog-agent/conf.d/load.d
path-include=/etc/datadog-agent/conf.d/load.d/*
path-include=/etc/datadog-agent/conf.d/memory.d
path-include=/etc/datadog-agent/conf.d/memory.d/*
path-include=/etc/datadog-agent/conf.d/network.d
path-include=/etc/datadog-agent/conf.d/network.d/*
path-include=/etc/datadog-agent/conf.d/ntp.d
path-include=/etc/datadog-agent/conf.d/ntp.d/*
path-include=/etc/datadog-agent/conf.d/uptime.d
path-include=/etc/datadog-agent/conf.d/uptime.d/*
path-include=/etc/datadog-agent/conf.d/system_swap.d
path-include=/etc/datadog-agent/conf.d/system_swap.d/*
path-include=/etc/datadog-agent/conf.d/systemd.d
path-include=/etc/datadog-agent/conf.d/systemd.d/*
path-include=/etc/datadog-agent/conf.d/jetson.d
path-include=/etc/datadog-agent/conf.d/jetson.d/*'
  assertEquals "DEB filter content and order" "$expected" "$(cat "$filter_path")"

  duplicate_count=$(sort "$filter_path" | uniq -d | wc -l | tr -d ' ')
  assertEquals "each DEB filter rule should be unique" 0 "$duplicate_count"
  assertEquals "DEB filter mode" 644 "$(stat -c '%a' "$filter_path")"
  rm -rf "$test_dir"
}

testDebIotFilterConfigPreservesFilterAndCleansTempOnWriteFailure() {
  local test_dir
  local filter_path
  local output
  local status
  local temp_count

  test_dir=$(mktemp -d)
  filter_path="$test_dir/99-datadog-iot"
  mkdir "$test_dir/bin"
  printf 'existing complete filter\n' > "$filter_path"
  cat > "$test_dir/bin/cat" <<'EOF'
#!/bin/sh
exit 1
EOF
  chmod +x "$test_dir/bin/cat"

  output=$(PATH="$test_dir/bin:$PATH" write_deb_iot_filter_config "$filter_path" 2>&1)
  status=$?

  assertNotEquals "failed temporary filter write should return nonzero" 0 "$status"
  assertIotContains "write failure should be actionable" "$output" "temporary filtered IoT dpkg configuration"
  assertEquals "failed write should preserve the complete filter" "existing complete filter" "$(cat "$filter_path")"
  temp_count=$(find "$test_dir" -maxdepth 1 -name '.datadog_iot_filter.tmp.*' | wc -l | tr -d ' ')
  assertEquals "failed write should clean its temporary file" 0 "$temp_count"
  rm -rf "$test_dir"
}

testDebIotFilterConfigPreservesFilterAndCleansTempOnReplaceFailure() {
  local test_dir
  local filter_path
  local arguments_path
  local output
  local status
  local temp_count

  test_dir=$(mktemp -d)
  filter_path="$test_dir/99-datadog-iot"
  arguments_path="$test_dir/mv-arguments"
  printf 'existing complete filter\n' > "$filter_path"
  # shellcheck disable=SC2329
  mv() {
    printf '%s\n' "$@" > "$arguments_path"
    return 1
  }

  output=$(write_deb_iot_filter_config "$filter_path" 2>&1)
  status=$?
  unset -f mv

  assertNotEquals "failed filter replacement should return nonzero" 0 "$status"
  assertIotContains "replacement failure should be actionable" "$output" "atomically replace"
  assertEquals "failed replacement should preserve the complete filter" "existing complete filter" "$(cat "$filter_path")"
  assertEquals "filter replacement should use no-target-directory semantics" "-fT
--" "$(head -n 2 "$arguments_path")"
  assertEquals "filter replacement destination should be exact" "$filter_path" "$(tail -n 1 "$arguments_path")"
  temp_count=$(find "$test_dir" -maxdepth 1 -name '.datadog_iot_filter.tmp.*' | wc -l | tr -d ' ')
  assertEquals "failed replacement should clean its temporary file" 0 "$temp_count"
  rm -rf "$test_dir"
}

testDebIotFilterConfigRejectsDirectoryDestination() {
  local test_dir
  local filter_path
  local output
  local status
  local nested_count

  test_dir=$(mktemp -d)
  filter_path="$test_dir/99-datadog-iot"
  mkdir "$filter_path"

  output=$(write_deb_iot_filter_config "$filter_path" 2>&1)
  status=$?

  assertNotEquals "directory filter destination should fail closed" 0 "$status"
  assertTrue "directory destination should remain a directory" "[ -d '$filter_path' ]"
  nested_count=$(find "$filter_path" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
  assertEquals "no filter temporary file should be moved into the destination directory" 0 "$nested_count"
  rm -rf "$test_dir"
}

testDebIotFilterConfigExplicitlyIncludesParentsBeforeLeaves() {
  local test_dir
  local filter_path
  local package_path
  local check_name
  local -a parent_paths=(
    /opt/datadog-agent/bin
    /opt/datadog-agent/bin/agent
    /opt/datadog-agent/bin/agent/dist
    /opt/datadog-agent/bin/agent/dist/views
    /opt/datadog-agent/embedded/bin
    /opt/datadog-agent/embedded/lib
    /etc/datadog-agent/conf.d
  )
  local -a check_names=(
    cpu disk io load memory network ntp uptime system_swap systemd jetson
  )

  test_dir=$(mktemp -d)
  filter_path="$test_dir/99-datadog-iot"
  write_deb_iot_filter_config "$filter_path"

  for package_path in "${parent_paths[@]}"; do
    iotDpkgPathIsIncluded "$filter_path" "$package_path"
    assertEquals "$package_path parent should be explicitly retained" 0 $?
  done
  for check_name in "${check_names[@]}"; do
    package_path="/etc/datadog-agent/conf.d/$check_name.d"
    iotDpkgPathIsIncluded "$filter_path" "$package_path"
    assertEquals "$package_path parent should be explicitly retained" 0 $?
  done

  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/bin/agent/agent"
  assertEquals "normal Agent should be retained" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/etc/datadog-agent/datadog.yaml.example"
  assertEquals "Agent configuration example should be retained" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/embedded/bin/agent-data-plane"
  assertEquals "agent-data-plane should be re-included" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so.1"
  assertEquals "rtloader shim should be re-included" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/bin/agent/dist/views/flare.html"
  assertEquals "support views should be re-included" 0 $?
  for check_name in "${check_names[@]}"; do
    package_path="/etc/datadog-agent/conf.d/$check_name.d/conf.yaml.example"
    iotDpkgPathIsIncluded "$filter_path" "$package_path"
    assertEquals "$package_path payload should be retained" 0 $?
  done

  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/embedded/ssl/certs/cacert.pem"
  assertEquals "embedded SSL data should remain available to the Agent" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/embedded/lib/libssl.so.3"
  assertEquals "embedded SSL libraries should remain available to the Agent" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/embedded/share/openscap/cpe.xml"
  assertEquals "non-system-probe support data should remain available" 0 $?

  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/embedded/bin/python3"
  assertNotEquals "Python should remain excluded" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/embedded/lib/libpython3.13.so.1.0"
  assertNotEquals "libpython should remain excluded" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/embedded/lib/python3.13/site-packages/yaml.py"
  assertNotEquals "Python site-packages should remain excluded" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/embedded/include/Python.h"
  assertNotEquals "headers should remain excluded" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/embedded/lib/libodbc.so.2"
  assertNotEquals "ODBC libraries should remain excluded" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/embedded/share/system-probe/ebpf.o"
  assertNotEquals "system-probe support data should remain excluded" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/embedded/share/msodbcsql18/lib64/libmsodbcsql.so"
  assertNotEquals "shared MS ODBC payloads should remain excluded" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/python-scripts/post.py"
  assertNotEquals "Agent Python scripts should remain excluded" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/requirements/base.txt"
  assertNotEquals "Agent requirement directories should remain excluded" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/requirements-agent-release.txt"
  assertNotEquals "Agent requirement manifests should remain excluded" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/bin/process-agent/process-agent"
  assertNotEquals "process-agent should remain excluded" 0 $?
  iotDpkgPathIsIncluded "$filter_path" "/etc/datadog-agent/conf.d/docker.d/conf.yaml.example"
  assertNotEquals "non-IoT check configuration should remain excluded" 0 $?
  rm -rf "$test_dir"
}

testRpmIotExcludePathsDerivesSortedUniquePrefixes() {
  local test_dir
  local package_path
  local arguments_path
  local output
  local status
  local expected
  local expected_arguments

  test_dir=$(mktemp -d)
  package_path="$test_dir/datadog agent [7].rpm"
  arguments_path="$test_dir/rpm-arguments"
  : > "$package_path"

  # shellcheck disable=SC2329
  rpm() {
    printf '%s\n' "$@" > "$arguments_path"
    cat <<'EOF'
/opt/datadog-agent/bin/agent/agent
/opt/datadog-agent/bin/agent/dist/views/index.html
/opt/datadog-agent/bin/agent/dist/checks/check.py
/opt/datadog-agent/bin/agent/dist/config/config.py
/opt/datadog-agent/bin/agent/dist/utils/util.py
/opt/datadog-agent/bin/agent/dist/jmx/jmxfetch.jar
/opt/datadog-agent/bin/process-agent/process-agent
/opt/datadog-agent/embedded/bin/agent-data-plane
/opt/datadog-agent/embedded/bin/process-agent
/opt/datadog-agent/embedded/bin/python3
/opt/datadog-agent/embedded/bin/python3/site.py
/opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so
/opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so.1
/opt/datadog-agent/embedded/lib/libpython3.12.so
/opt/datadog-agent/embedded/lib/python3.12/site-packages/yaml.py
/opt/datadog-agent/embedded/lib/libssl.so.3
/opt/datadog-agent/embedded/ssl/certs/cacert.pem
/opt/datadog-agent/embedded/share/openscap/cpe.xml
/opt/datadog-agent/embedded/sbin/chroot
/opt/datadog-agent/embedded/include/Python.h
/opt/datadog-agent/embedded/share/system-probe/ebpf.o
/opt/datadog-agent/embedded/share/ebpf/co-re.o
/opt/datadog-agent/embedded/share/msodbcsql18/lib64/libmsodbcsql.so
/opt/datadog-agent/embedded/msodbcsql/lib64/libmsodbcsql.so
/opt/datadog-agent/python-scripts/post.py
/opt/datadog-agent/requirements/base.txt
/opt/datadog-agent/requirements-agent-release.txt
/opt/datadog-agent/compliance/rules.json
/opt/datadog-agent/runtime-security.d/policy.policy
/etc/datadog-agent/compliance.d/default.json
/etc/datadog-agent/runtime-security.d/default.policy
/etc/datadog-agent/conf.d/cpu.d/conf.yaml.example
/etc/datadog-agent/conf.d/jetson.d/conf.yaml.example
/etc/datadog-agent/conf.d/docker.d/conf.yaml.example
EOF
  }

  output=$(rpm_iot_exclude_paths "$package_path" 2>&1)
  status=$?
  unset -f rpm

  assertEquals "RPM path derivation should succeed" 0 "$status"
  expected='/etc/datadog-agent/compliance.d/
/etc/datadog-agent/conf.d/docker.d
/etc/datadog-agent/runtime-security.d/
/opt/datadog-agent/bin/agent/dist/checks
/opt/datadog-agent/bin/agent/dist/config
/opt/datadog-agent/bin/agent/dist/jmx
/opt/datadog-agent/bin/agent/dist/utils
/opt/datadog-agent/bin/process-agent
/opt/datadog-agent/compliance/
/opt/datadog-agent/embedded/bin/process-agent
/opt/datadog-agent/embedded/bin/python3
/opt/datadog-agent/embedded/include/
/opt/datadog-agent/embedded/lib/libpython3.12.so
/opt/datadog-agent/embedded/lib/python3.12
/opt/datadog-agent/embedded/msodbcsql/
/opt/datadog-agent/embedded/sbin/
/opt/datadog-agent/embedded/share/ebpf/
/opt/datadog-agent/embedded/share/msodbcsql18/
/opt/datadog-agent/embedded/share/system-probe/
/opt/datadog-agent/python-scripts/
/opt/datadog-agent/requirements-agent-release.txt
/opt/datadog-agent/requirements/
/opt/datadog-agent/runtime-security.d/'
  assertEquals "RPM exclusions should be sorted, unique, and retain only supported payloads" "$expected" "$output"

  expected_arguments="-qpl
$package_path"
  assertEquals "package path should remain one quoted rpm argument" "$expected_arguments" "$(cat "$arguments_path")"
  rm -rf "$test_dir"
}

testRpmIotExcludePathsRunsUnderSystemBashWithoutAssociativeArrays() {
  local test_dir
  local package_path
  local helper_definition
  local output
  local status

  test_dir=$(mktemp -d)
  package_path="$test_dir/agent.rpm"
  mkdir "$test_dir/bin"
  : > "$package_path"
  cat > "$test_dir/bin/rpm" <<'EOF'
#!/bin/sh
printf '%s\n' \
  /opt/datadog-agent/embedded/bin/process-agent \
  /opt/datadog-agent/embedded/bin/process-agent
EOF
  chmod +x "$test_dir/bin/rpm"

  helper_definition=$(declare -f rpm_iot_exclude_paths)
  assertIotNotContains "RPM helper should not declare a local associative array" "$helper_definition" "local -A"
  assertIotNotContains "RPM helper should not declare an associative array" "$helper_definition" "declare -A"

  output=$(PATH="$test_dir/bin:$PATH" /bin/bash -c 'source "$1"; rpm_iot_exclude_paths "$2"' _ "$dir_path/extracted_functions.sh" "$package_path" 2>&1)
  status=$?

  assertEquals "RPM helper should run under the system Bash" 0 "$status"
  assertEquals "Bash-compatible deduplication should emit one prefix" "/opt/datadog-agent/embedded/bin/process-agent" "$output"
  rm -rf "$test_dir"
}

testRpmIotExcludePathsRejectsAgentDataPlanePrefixCollisionWithoutOutput() {
  local test_dir
  local output_path
  local error_path
  local status

  test_dir=$(mktemp -d)
  output_path="$test_dir/output"
  error_path="$test_dir/error"
  # shellcheck disable=SC2329
  rpm() {
    cat <<'EOF'
/opt/datadog-agent/embedded/bin/agent-data
/opt/datadog-agent/embedded/bin/agent-data-plane
/opt/datadog-agent/embedded/bin/process-agent
EOF
  }

  rpm_iot_exclude_paths "$test_dir/agent.rpm" > "$output_path" 2> "$error_path"
  status=$?
  unset -f rpm

  assertNotEquals "an exclusion prefix that matches agent-data-plane should fail" 0 "$status"
  assertEquals "a collision should not emit any partial exclusion output" "" "$(cat "$output_path")"
  assertIotContains "collision error should identify the unsafe prefix" "$(cat "$error_path")" "/opt/datadog-agent/embedded/bin/agent-data"
  assertIotContains "collision error should identify agent-data-plane" "$(cat "$error_path")" "/opt/datadog-agent/embedded/bin/agent-data-plane"
  assertIotNotContains "unrelated exclusions should not leak to stderr" "$(cat "$error_path")" "/opt/datadog-agent/embedded/bin/process-agent"
  rm -rf "$test_dir"
}

testRpmIotExcludePathsRejectsSupportViewsPrefixCollisionWithoutOutput() {
  local test_dir
  local output_path
  local error_path
  local status

  test_dir=$(mktemp -d)
  output_path="$test_dir/output"
  error_path="$test_dir/error"
  # shellcheck disable=SC2329
  rpm() {
    cat <<'EOF'
/opt/datadog-agent/bin/agent/dist/view/index.html
/opt/datadog-agent/bin/agent/dist/views/index.html
/opt/datadog-agent/bin/agent/dist/checks/check.py
EOF
  }

  rpm_iot_exclude_paths "$test_dir/agent.rpm" > "$output_path" 2> "$error_path"
  status=$?
  unset -f rpm

  assertNotEquals "an exclusion prefix that matches support views should fail" 0 "$status"
  assertEquals "a collision should not emit any partial exclusion output" "" "$(cat "$output_path")"
  assertIotContains "collision error should identify the unsafe prefix" "$(cat "$error_path")" "/opt/datadog-agent/bin/agent/dist/view"
  assertIotContains "collision error should identify support views" "$(cat "$error_path")" "/opt/datadog-agent/bin/agent/dist/views"
  assertIotNotContains "unrelated exclusions should not leak to stderr" "$(cat "$error_path")" "/opt/datadog-agent/bin/agent/dist/checks"
  rm -rf "$test_dir"
}

testRpmIotExcludePathsRejectsMoreThan1024Prefixes() {
  local test_dir
  local output
  local status

  test_dir=$(mktemp -d)
  # shellcheck disable=SC2329
  rpm() {
    local index=0
    while [ "$index" -le 1024 ]; do
      printf '/opt/datadog-agent/embedded/bin/tool-%04d\n' "$index"
      index=$((index + 1))
    done
  }

  output=$(rpm_iot_exclude_paths "$test_dir/agent.rpm" 2>&1)
  status=$?
  unset -f rpm

  assertNotEquals "more than 1024 RPM exclusions should fail" 0 "$status"
  assertIotContains "bound error should be actionable" "$output" "1024"
  assertIotNotContains "no partial prefix list should be printed" "$output" "/opt/datadog-agent/embedded/bin/tool-0000"
  rm -rf "$test_dir"
}

testValidateIotInstallLayoutAcceptsFilteredLayout() {
  local root

  root=$(mktemp -d)
  createIotRetainedLayout "$root"
  validate_iot_install_layout "$root"
  assertEquals "filtered layout should pass" 0 $?
  rm -rf "$root"
}

testValidateIotInstallLayoutAggregatesMissingRetainedClasses() {
  local root
  local output
  local status
  local check_name
  local -a check_names=(
    cpu disk io load memory network ntp uptime system_swap systemd jetson
  )

  root=$(mktemp -d)
  output=$(validate_iot_install_layout "$root" 2>&1)
  status=$?

  assertNotEquals "a layout missing retained classes should fail" 0 "$status"
  assertIotContains "normal Agent should be required" "$output" "/opt/datadog-agent/bin/agent/agent"
  assertIotContains "agent-data-plane should be required" "$output" "/opt/datadog-agent/embedded/bin/agent-data-plane"
  assertIotContains "rtloader should be required" "$output" "/opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so*"
  assertIotContains "support views should be required" "$output" "/opt/datadog-agent/bin/agent/dist/views"
  assertIotContains "Agent configuration example should be required" "$output" "/etc/datadog-agent/datadog.yaml.example"
  for check_name in "${check_names[@]}"; do
    assertIotContains "$check_name configuration directory should be required" "$output" "/etc/datadog-agent/conf.d/$check_name.d"
  done
  rm -rf "$root"
}

testValidateIotInstallLayoutRequiresRetainedDirectoryContent() {
  local root
  local output
  local status
  local check_name
  local -a check_names=(
    cpu disk io load memory network ntp uptime system_swap systemd jetson
  )

  root=$(mktemp -d)
  createIotRetainedLayout "$root"
  rm "$root/opt/datadog-agent/bin/agent/dist/views/index.html"
  for check_name in "${check_names[@]}"; do
    rm "$root/etc/datadog-agent/conf.d/$check_name.d/conf.yaml.example"
  done

  output=$(validate_iot_install_layout "$root" 2>&1)
  status=$?
  assertNotEquals "empty retained directories should fail" 0 "$status"
  assertIotContains "support view content should be required" "$output" "/opt/datadog-agent/bin/agent/dist/views/*"
  for check_name in "${check_names[@]}"; do
    assertIotContains "$check_name configuration content should be required" "$output" "/etc/datadog-agent/conf.d/$check_name.d/*"
  done
  rm -rf "$root"
}

testValidateIotInstallLayoutAggregatesPrunedPayloadClasses() {
  local root
  local output
  local status
  local payload_path
  local -a disallowed_payloads=(
    /opt/datadog-agent/bin/process-agent/process-agent
    /opt/datadog-agent/bin/agent/dist/checks/check.py
    /opt/datadog-agent/bin/agent/dist/config/config.py
    /opt/datadog-agent/bin/agent/dist/utils/util.py
    /opt/datadog-agent/bin/agent/dist/jmx/jmxfetch.jar
    /opt/datadog-agent/embedded/bin/process-agent
    /opt/datadog-agent/embedded/bin/trace-agent
    /opt/datadog-agent/embedded/bin/security-agent
    /opt/datadog-agent/embedded/bin/privateactionrunner
    /opt/datadog-agent/embedded/bin/installer
    /opt/datadog-agent/embedded/bin/system-probe
    /opt/datadog-agent/embedded/bin/unexpected-helper
    /opt/datadog-agent/embedded/bin/python3
    /opt/datadog-agent/embedded/lib/libpython3.13.so.1.0
    /opt/datadog-agent/embedded/lib/python3.13/os.py
    /opt/datadog-agent/embedded/lib/python3.13/site-packages/yaml/__init__.py
    /opt/datadog-agent/embedded/share/system-probe/ebpf.o
    /opt/datadog-agent/embedded/share/ebpf/co-re.o
    /opt/datadog-agent/embedded/share/msodbcsql18/lib64/libmsodbcsql.so
    /opt/datadog-agent/embedded/include/Python.h
    /opt/datadog-agent/embedded/lib/libodbc.so.2
    /opt/datadog-agent/embedded/msodbcsql/lib64/libmsodbcsql.so
    /opt/datadog-agent/embedded/sbin/chroot
    /opt/datadog-agent/python-scripts/post.py
    /opt/datadog-agent/requirements/base.txt
    /opt/datadog-agent/requirements-agent-release.txt
    /opt/datadog-agent/compliance/rules.json
    /etc/datadog-agent/compliance.d/default.rego
    /opt/datadog-agent/runtime-security.d/policy.policy
    /etc/datadog-agent/runtime-security.d/default.policy
    /etc/datadog-agent/conf.d/docker.d/conf.yaml.example
    /etc/datadog-agent/conf.d/kubelet.d/conf.yaml.example
  )

  root=$(mktemp -d)
  createIotRetainedLayout "$root"
  for payload_path in "${disallowed_payloads[@]}"; do
    mkdir -p "$(dirname "$root$payload_path")"
    touch "$root$payload_path"
  done

  output=$(validate_iot_install_layout "$root" 2>&1)
  status=$?
  assertNotEquals "a layout containing pruned payload classes should fail" 0 "$status"
  for payload_path in "${disallowed_payloads[@]}"; do
    assertIotContains "$payload_path should be reported" "$output" "$payload_path"
  done
  rm -rf "$root"
}

testValidateIotInstallLayoutRequiresExecutableRegularBinaries() {
  local root
  local output
  local status

  root=$(mktemp -d)
  createIotRetainedLayout "$root"
  chmod -x \
    "$root/opt/datadog-agent/bin/agent/agent" \
    "$root/opt/datadog-agent/embedded/bin/agent-data-plane"

  output=$(validate_iot_install_layout "$root" 2>&1)
  status=$?

  assertNotEquals "non-executable retained binaries should fail" 0 "$status"
  assertIotContains "normal Agent error should require an executable regular file" "$output" "/opt/datadog-agent/bin/agent/agent"
  assertIotContains "agent-data-plane error should require an executable regular file" "$output" "/opt/datadog-agent/embedded/bin/agent-data-plane"
  rm -rf "$root"
}

testValidateIotInstallLayoutRejectsWrongRetainedTypes() {
  local root
  local output
  local status

  root=$(mktemp -d)
  createIotRetainedLayout "$root"
  rm "$root/opt/datadog-agent/bin/agent/agent"
  mkdir "$root/opt/datadog-agent/bin/agent/agent"
  rm "$root/opt/datadog-agent/embedded/bin/agent-data-plane"
  mkdir "$root/opt/datadog-agent/embedded/bin/agent-data-plane"
  rm "$root/etc/datadog-agent/datadog.yaml.example"
  mkdir "$root/etc/datadog-agent/datadog.yaml.example"
  rm -rf "$root/opt/datadog-agent/bin/agent/dist/views"
  touch "$root/opt/datadog-agent/bin/agent/dist/views"
  rm -rf "$root/etc/datadog-agent/conf.d/cpu.d"
  touch "$root/etc/datadog-agent/conf.d/cpu.d"
  mv "$root/opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so" "$root/opt/datadog-agent/embedded/lib/rtloader-target"
  ln -s rtloader-target "$root/opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so"

  output=$(validate_iot_install_layout "$root" 2>&1)
  status=$?

  assertNotEquals "wrong retained path types should fail" 0 "$status"
  assertIotContains "normal Agent should reject a directory" "$output" "/opt/datadog-agent/bin/agent/agent"
  assertIotContains "agent-data-plane should reject a directory" "$output" "/opt/datadog-agent/embedded/bin/agent-data-plane"
  assertIotContains "configuration example should reject a directory" "$output" "/etc/datadog-agent/datadog.yaml.example"
  assertIotContains "views should reject a regular file" "$output" "/opt/datadog-agent/bin/agent/dist/views"
  assertIotContains "check directory should reject a regular file" "$output" "/etc/datadog-agent/conf.d/cpu.d"
  assertIotContains "rtloader should reject a live symlink" "$output" "/opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so*"
  rm -rf "$root"
}

testValidateIotInstallLayoutRejectsLiveLinksInDisallowedTrees() {
  local root
  local output
  local status
  local link_path
  local -a link_paths=(
    /opt/datadog-agent/bin/process-agent
    /opt/datadog-agent/embedded/bin/python3
    /opt/datadog-agent/embedded/lib/python3.13/os.py
    /opt/datadog-agent/embedded/share/system-probe/live-data
    /opt/datadog-agent/embedded/share/msodbcsql18/live-data
    /opt/datadog-agent/python-scripts/live-script
    /opt/datadog-agent/requirements/live-requirement
    /opt/datadog-agent/requirements-agent-release.txt
    /etc/datadog-agent/conf.d/kubelet.d
  )

  root=$(mktemp -d)
  createIotRetainedLayout "$root"
  mkdir -p \
    "$root/live-target-directory" \
    "$root/opt/datadog-agent/embedded/lib/python3.13" \
    "$root/opt/datadog-agent/embedded/share/system-probe" \
    "$root/opt/datadog-agent/embedded/share/msodbcsql18" \
    "$root/opt/datadog-agent/python-scripts" \
    "$root/opt/datadog-agent/requirements"
  touch "$root/live-target-file"
  ln -s "$root/live-target-file" "$root/opt/datadog-agent/bin/process-agent"
  ln -s "$root/live-target-directory" "$root/opt/datadog-agent/embedded/bin/python3"
  ln -s "$root/live-target-file" "$root/opt/datadog-agent/embedded/lib/python3.13/os.py"
  ln -s "$root/live-target-directory" "$root/opt/datadog-agent/embedded/share/system-probe/live-data"
  ln -s "$root/live-target-directory" "$root/opt/datadog-agent/embedded/share/msodbcsql18/live-data"
  ln -s "$root/live-target-file" "$root/opt/datadog-agent/python-scripts/live-script"
  ln -s "$root/live-target-file" "$root/opt/datadog-agent/requirements/live-requirement"
  ln -s "$root/live-target-file" "$root/opt/datadog-agent/requirements-agent-release.txt"
  ln -s "$root/live-target-directory" "$root/etc/datadog-agent/conf.d/kubelet.d"

  output=$(validate_iot_install_layout "$root" 2>&1)
  status=$?

  assertNotEquals "live links in disallowed trees should fail" 0 "$status"
  for link_path in "${link_paths[@]}"; do
    assertIotContains "$link_path should be reported" "$output" "$link_path"
  done
  rm -rf "$root"
}

testValidateIotInstallLayoutFailsClosedWhenDisallowedTreeCannotBeInspected() {
  local root
  local failing_tree
  local output
  local status

  root=$(mktemp -d)
  createIotRetainedLayout "$root"
  failing_tree="$root/opt/datadog-agent/embedded/share/system-probe"
  mkdir -p "$failing_tree"
  touch "$failing_tree/hidden-payload"
  # shellcheck disable=SC2329
  find() {
    if [ "${1-}" = "$failing_tree" ]; then
      return 73
    fi
    command find "$@"
  }

  output=$(validate_iot_install_layout "$root" 2>&1)
  status=$?
  unset -f find

  assertNotEquals "an unreadable disallowed tree should fail closed" 0 "$status"
  assertIotContains "inspection failure should be aggregated" "$output" "unable to inspect disallowed payload tree: /opt/datadog-agent/embedded/share/system-probe"
  rm -rf "$root"
}

testValidateIotInstallLayoutAllowsEmptyExcludedDirectoriesAndDanglingLinks() {
  local root
  local excluded_directory
  local -a excluded_directories=(
    /opt/datadog-agent/bin/agent/dist/jmx
    /opt/datadog-agent/embedded/include
    /opt/datadog-agent/embedded/lib/python3.13/site-packages
    /opt/datadog-agent/embedded/msodbcsql
    /opt/datadog-agent/embedded/sbin
    /opt/datadog-agent/embedded/share/ebpf
    /opt/datadog-agent/embedded/share/msodbcsql18
    /opt/datadog-agent/embedded/share/system-probe
    /opt/datadog-agent/python-scripts
    /opt/datadog-agent/requirements
    /opt/datadog-agent/compliance
    /opt/datadog-agent/runtime-security.d
    /etc/datadog-agent/compliance.d
    /etc/datadog-agent/runtime-security.d
    /etc/datadog-agent/conf.d/docker.d
  )

  root=$(mktemp -d)
  createIotRetainedLayout "$root"
  for excluded_directory in "${excluded_directories[@]}"; do
    mkdir -p "$root$excluded_directory"
  done
  ln -s python3.13 "$root/opt/datadog-agent/embedded/bin/python3"
  ln -s libpython3.13.so.1.0 "$root/opt/datadog-agent/embedded/lib/libpython3.13.so"
  ln -s missing-extension.so "$root/opt/datadog-agent/embedded/lib/python3.13/site-packages/native-extension.so"

  validate_iot_install_layout "$root"
  assertEquals "empty excluded directories and dangling links should be harmless" 0 $?
  rm -rf "$root"
}

testWriteIotInstallProfileWritesExactYamlAndMode() {
  local test_dir
  local marker_path
  local expected

  test_dir=$(mktemp -d)
  marker_path="$test_dir/install_profile"
  write_iot_install_profile "$marker_path" "7.72.1-1"
  assertEquals "profile writer should succeed" 0 $?

  expected='version: 1
profile: iot-filtered
manifest: iot-v1
package: datadog-agent
package_version: '\''7.72.1-1'\''
installer: install_script_agent7_iot'
  assertEquals "profile YAML" "$expected" "$(cat "$marker_path")"
  assertEquals "profile mode" 644 "$(stat -c '%a' "$marker_path")"
  rm -rf "$test_dir"
}

testWriteIotInstallProfilePreservesMarkerAndCleansTempOnFailure() {
  local test_dir
  local marker_path
  local output
  local status
  local temp_count

  test_dir=$(mktemp -d)
  marker_path="$test_dir/install_profile"
  printf 'existing marker\n' > "$marker_path"
  # shellcheck disable=SC2329
  mv() {
    return 1
  }

  output=$(write_iot_install_profile "$marker_path" "7.72.1-1" 2>&1)
  status=$?
  unset -f mv

  assertNotEquals "failed replacement should return nonzero" 0 "$status"
  assertEquals "existing marker should remain intact" "existing marker" "$(cat "$marker_path")"
  temp_count=$(find "$test_dir" -maxdepth 1 -name '.install_profile.tmp.*' | wc -l | tr -d ' ')
  assertEquals "failed replacement should clean its temporary file" 0 "$temp_count"
  rm -rf "$test_dir"
}

testWriteIotInstallProfileRejectsDirectoryDestinations() {
  local test_dir
  local marker_path
  local output
  local status
  local nested_count

  test_dir=$(mktemp -d)
  marker_path="$test_dir/install_profile"
  mkdir "$marker_path"

  output=$(write_iot_install_profile "$marker_path" "7.72.1-1" 2>&1)
  status=$?

  assertNotEquals "directory marker destination should fail closed" 0 "$status"
  assertTrue "marker destination should remain a directory" "[ -d '$marker_path' ]"
  nested_count=$(find "$marker_path" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
  assertEquals "no marker temporary file should be moved into the destination directory" 0 "$nested_count"
  rm -rf "$test_dir"
}

testWriteIotInstallProfileRejectsSymlinkToDirectoryDestinations() {
  local test_dir
  local target_directory
  local marker_path
  local output
  local status
  local nested_count

  test_dir=$(mktemp -d)
  target_directory="$test_dir/marker-target"
  marker_path="$test_dir/install_profile"
  mkdir "$target_directory"
  ln -s "$target_directory" "$marker_path"

  output=$(write_iot_install_profile "$marker_path" "7.72.1-1" 2>&1)
  status=$?

  assertNotEquals "symlink-to-directory marker destination should fail closed" 0 "$status"
  assertTrue "marker destination should remain a symlink" "[ -L '$marker_path' ]"
  nested_count=$(find "$target_directory" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
  assertEquals "no marker temporary file should be moved through the destination symlink" 0 "$nested_count"
  rm -rf "$test_dir"
}

testWriteIotInstallProfileVerifiesExactDestinationAfterReplacement() {
  local test_dir
  local marker_path
  local output
  local status
  local temp_count

  test_dir=$(mktemp -d)
  marker_path="$test_dir/install_profile"
  # shellcheck disable=SC2329
  mv() {
    return 0
  }

  output=$(write_iot_install_profile "$marker_path" "7.72.1-1" 2>&1)
  status=$?
  unset -f mv

  assertNotEquals "replacement without an exact regular marker should fail" 0 "$status"
  assertFalse "missing exact marker should not be accepted" "[ -e '$marker_path' ]"
  temp_count=$(find "$test_dir" -maxdepth 1 -name '.install_profile.tmp.*' | wc -l | tr -d ' ')
  assertEquals "failed post-replacement verification should clean its temporary file" 0 "$temp_count"
  rm -rf "$test_dir"
}

testGetInstalledAgentPackageVersionQueriesExplicitFamily() {
  local test_dir
  local arguments_path
  local output
  local status
  local expected_dpkg_arguments
  local expected_rpm_arguments

  test_dir=$(mktemp -d)
  arguments_path="$test_dir/query-arguments"
  # shellcheck disable=SC2329
  dpkg-query() {
    printf '%s\n' "$@" > "$arguments_path"
    printf '7.72.1-1\n'
  }
  output=$(get_installed_agent_package_version deb)
  status=$?
  unset -f dpkg-query
  assertEquals "DEB version query should succeed" 0 "$status"
  assertEquals "DEB installed package version" "7.72.1-1" "$output"
  # shellcheck disable=SC2016
  expected_dpkg_arguments='--show
--showformat=${Version}\n
datadog-agent'
  assertEquals "dpkg-query arguments" "$expected_dpkg_arguments" "$(cat "$arguments_path")"

  # shellcheck disable=SC2329
  rpm() {
    printf '%s\n' "$@" > "$arguments_path"
    printf '7.72.1-1\n'
  }
  output=$(get_installed_agent_package_version rpm)
  status=$?
  unset -f rpm
  assertEquals "RPM version query should succeed" 0 "$status"
  assertEquals "RPM installed package version" "7.72.1-1" "$output"
  expected_rpm_arguments='-q
--queryformat
%{VERSION}-%{RELEASE}\n
datadog-agent'
  assertEquals "rpm query arguments" "$expected_rpm_arguments" "$(cat "$arguments_path")"
  rm -rf "$test_dir"
}

testGetInstalledAgentPackageVersionRejectsUnknownFamily() {
  local output
  local status

  output=$(get_installed_agent_package_version apk 2>&1)
  status=$?
  assertNotEquals "unknown package family should fail" 0 "$status"
  assertIotContains "unknown family error should be actionable" "$output" "apk"
}

# shellcheck source=/dev/null
. shunit2
