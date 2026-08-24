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

  mkdir -p \
    "$root/opt/datadog-agent/bin/agent" \
    "$root/opt/datadog-agent/embedded/bin" \
    "$root/opt/datadog-agent/embedded/lib"
  touch \
    "$root/opt/datadog-agent/bin/agent/agent" \
    "$root/opt/datadog-agent/embedded/bin/agent-data-plane" \
    "$root/opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so"
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
path-exclude=/opt/datadog-agent/embedded/*
path-exclude=/opt/datadog-agent/python-scripts/*
path-exclude=/opt/datadog-agent/requirements/*
path-exclude=/opt/datadog-agent/requirements*.txt
path-exclude=/opt/datadog-agent/compliance/*
path-exclude=/opt/datadog-agent/runtime-security.d/*
path-exclude=/etc/datadog-agent/compliance.d/*
path-exclude=/etc/datadog-agent/runtime-security.d/*
path-exclude=/etc/datadog-agent/conf.d/*
path-include=/opt/datadog-agent/bin/agent/agent
path-include=/opt/datadog-agent/embedded/bin/agent-data-plane
path-include=/opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so*
path-include=/opt/datadog-agent/bin/agent/dist/views/*
path-include=/etc/datadog-agent/conf.d/cpu.d/*
path-include=/etc/datadog-agent/conf.d/disk.d/*
path-include=/etc/datadog-agent/conf.d/io.d/*
path-include=/etc/datadog-agent/conf.d/load.d/*
path-include=/etc/datadog-agent/conf.d/memory.d/*
path-include=/etc/datadog-agent/conf.d/network.d/*
path-include=/etc/datadog-agent/conf.d/ntp.d/*
path-include=/etc/datadog-agent/conf.d/uptime.d/*
path-include=/etc/datadog-agent/conf.d/system_swap.d/*
path-include=/etc/datadog-agent/conf.d/systemd.d/*
path-include=/etc/datadog-agent/conf.d/jetson.d/*'
  assertEquals "DEB filter content and order" "$expected" "$(cat "$filter_path")"

  duplicate_count=$(sort "$filter_path" | uniq -d | wc -l | tr -d ' ')
  assertEquals "each DEB filter rule should be unique" 0 "$duplicate_count"
  rm -rf "$test_dir"
}

testDebIotFilterConfigUsesLastMatchingRule() {
  local test_dir
  local filter_path

  test_dir=$(mktemp -d)
  filter_path="$test_dir/99-datadog-iot"
  write_deb_iot_filter_config "$filter_path"

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
  iotDpkgPathIsIncluded "$filter_path" "/etc/datadog-agent/conf.d/systemd.d/conf.yaml.example"
  assertEquals "IoT check configuration should be re-included" 0 $?

  iotDpkgPathIsIncluded "$filter_path" "/opt/datadog-agent/embedded/bin/python3"
  assertNotEquals "Python should remain excluded" 0 $?
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
/opt/datadog-agent/embedded/sbin/chroot
/opt/datadog-agent/embedded/include/Python.h
/opt/datadog-agent/embedded/share/system-probe/ebpf.o
/opt/datadog-agent/embedded/share/ebpf/co-re.o
/opt/datadog-agent/embedded/msodbcsql/lib64/libmsodbcsql.so
/opt/datadog-agent/python-scripts/post.py
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
/opt/datadog-agent/embedded/share/system-probe/
/opt/datadog-agent/python-scripts/
/opt/datadog-agent/requirements-agent-release.txt
/opt/datadog-agent/runtime-security.d/'
  assertEquals "RPM exclusions should be sorted, unique, and retain only supported payloads" "$expected" "$output"

  expected_arguments="-qpl
$package_path"
  assertEquals "package path should remain one quoted rpm argument" "$expected_arguments" "$(cat "$arguments_path")"
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

testValidateIotInstallLayoutAggregatesFailures() {
  local root
  local output
  local status

  root=$(mktemp -d)
  createIotRetainedLayout "$root"
  rm \
    "$root/opt/datadog-agent/embedded/bin/agent-data-plane" \
    "$root/opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so"
  mkdir -p \
    "$root/opt/datadog-agent/embedded/bin" \
    "$root/opt/datadog-agent/bin/agent/dist/jmx" \
    "$root/etc/datadog-agent/conf.d/docker.d"
  touch \
    "$root/opt/datadog-agent/embedded/bin/process-agent" \
    "$root/opt/datadog-agent/embedded/bin/python3" \
    "$root/opt/datadog-agent/embedded/bin/system-probe" \
    "$root/opt/datadog-agent/bin/agent/dist/jmx/jmxfetch.jar" \
    "$root/etc/datadog-agent/conf.d/docker.d/conf.yaml.example"

  output=$(validate_iot_install_layout "$root" 2>&1)
  status=$?
  assertNotEquals "invalid filtered layout should fail" 0 "$status"
  assertIotContains "missing ADP should be reported" "$output" "missing required path: /opt/datadog-agent/embedded/bin/agent-data-plane"
  assertIotContains "missing rtloader should be reported" "$output" "missing required path: /opt/datadog-agent/embedded/lib/libdatadog-agent-rtloader.so*"
  assertIotContains "process-agent should be reported" "$output" "disallowed path remains: /opt/datadog-agent/embedded/bin/process-agent"
  assertIotContains "Python should be reported" "$output" "disallowed path remains: /opt/datadog-agent/embedded/bin/python3"
  assertIotContains "system-probe should be reported" "$output" "disallowed path remains: /opt/datadog-agent/embedded/bin/system-probe"
  assertIotContains "JMX should be reported" "$output" "disallowed path remains: /opt/datadog-agent/bin/agent/dist/jmx/jmxfetch.jar"
  assertIotContains "non-IoT config should be reported" "$output" "disallowed path remains: /etc/datadog-agent/conf.d/docker.d/conf.yaml.example"
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
