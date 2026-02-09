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
  sudo grep -wq "^# site: datadoghq.com$" $config_file
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
  sudo grep -wq "^# dd_url: https:\/\/app.datadoghq.com$" $config_file
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
  assertEquals "$(sudo yq eval '.private_action_runner.nodeAgent' $config_file)" "null"
}
testParEnabledWithSingleAction() {
  sudo rm $config_file 2> /dev/null
  ensure_config_file_exists "sudo" $config_file "dd-agent"
  update_par "sudo" $config_file "true" "com.datadoghq.script.runPredefinedScript"
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.private_action_runner.enabled' $config_file)" "true"
  assertEquals "$(sudo yq eval '.private_action_runner.nodeAgent.actions_allowlist[0]' $config_file)" "com.datadoghq.script.runPredefinedScript"
}
testParEnabledWithMultipleActions() {
  sudo rm $config_file 2> /dev/null
  ensure_config_file_exists "sudo" $config_file "dd-agent"
  update_par "sudo" $config_file "true" "com.datadoghq.script.runPredefinedScript,com.datadoghq.script.runShellScript"
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  assertEquals "$(sudo yq eval '.private_action_runner.enabled' $config_file)" "true"
  assertEquals "$(sudo yq eval '.private_action_runner.nodeAgent.actions_allowlist[0]' $config_file)" "com.datadoghq.script.runPredefinedScript"
  assertEquals "$(sudo yq eval '.private_action_runner.nodeAgent.actions_allowlist[1]' $config_file)" "com.datadoghq.script.runShellScript"
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

# shellcheck source=/dev/null
. shunit2
