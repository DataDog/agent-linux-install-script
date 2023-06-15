#!/usr/bin/env bash

file_path=$(realpath $0)
source `dirname $file_path`/extracted_functions.sh
yaml_config=`dirname $file_path`/.yamllint.yaml
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
  sudo grep -wq "^api_key: 123$" $config_file
  assertEquals 0 $?
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
  sudo yamllint -c $yaml_config --no-warnings $config_file
  assertEquals 0 $?
  sudo grep -wq "^site: d4t4d0g.cat" $config_file
  assertEquals 0 $?
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
  sudo yamllint -c $yaml_config --no-warnings $config_file
  assertEquals 0 $?
  sudo grep -wq "^dd_url: https:\/\/d4t4d0g.cat" $config_file
  assertEquals 0 $?
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
  sudo grep 9803 $config_file
  assertEquals 0 $?
}

### update_hostname
testHostnameUpdated() {
  sudo cp ${config_file}.example $config_file
  update_hostname "sudo" "gandalf" $config_file
  sudo yamllint -c $yaml_config --no-warnings $config_file
  assertEquals 0 $?
  match_id=`sudo grep '^hostname:' $config_file | grep gandalf | wc -l`
  assertEquals 1 $match_id
}
testNoHostname() {
  sudo cp ${config_file}.example $config_file
  update_hostname "sudo" "" $config_file
  match_id=`sudo grep '^hostname:' $config_file | wc -l`
  assertEquals 0 $match_id
}

### update_hosttags
testHostTagsUpdated() {
  sudo cp ${config_file}.example $config_file
  update_hosttags "sudo" "foo:bar,titi:toto" $config_file
  sudo yamllint -c $yaml_config --no-warnings $config_file
  assertEquals 0 $?
  sudo grep -wq "^tags: \['foo:bar', 'titi:toto'\]" $config_file
  assertEquals 0 $?
}
testNoHostTags() {
  sudo cp ${config_file}.example $config_file
  update_hosttags "sudo" "" $config_file
  sudo grep -wq '^# tags:$' $config_file
  assertEquals 0 $?
}

### update_runtime_security
testRuntimeSecurityUpdated() {
  sudo cp ${security_agent_config_file}.example $security_agent_config_file
  update_runtime_security "sudo" "true" $security_agent_config_file
  sudo yamllint -c $yaml_config --no-warnings $security_agent_config_file
  assertEquals 0 $?
  sudo sed -e '0,/^runtime_security_config/d' -e '/^[^ ]/,$d' $security_agent_config_file | grep -v "#" | grep -q "enabled: true"
  assertEquals 0 $?
}
testRuntimeSecurityUpdatedSystemPrope() {
  sudo cp ${system_probe_config_file}.example $system_probe_config_file
  update_runtime_security "sudo" "true" $system_probe_config_file
  sudo yamllint -c $yaml_config --no-warnings $system_probe_config_file
  assertEquals 0 $?
  sudo sed -e '0,/^runtime_security_config/d' -e '/^[^ ]/,$d' $system_probe_config_file | grep -v "#" | grep -q "enabled: true"
  assertEquals 0 $?
}
testRuntimeSecurityDisabled() {
  sudo cp ${security_agent_config_file}.example $security_agent_config_file
  update_runtime_security "sudo" "false" $security_agent_config_file
  sudo sed -e '0,/^runtime_security_config/d' -e '/^[^ ]/,$d' $security_agent_config_file | grep -v "#" | grep -q "enabled: true"
  assertEquals 1 $?
}

### update_compliance_configuration
testComplianceConfigurationUpdated() {
  sudo cp ${security_agent_config_file}.example $security_agent_config_file
  update_compliance_configuration "sudo" "true" $security_agent_config_file
  sudo yamllint -c $yaml_config --no-warnings $security_agent_config_file
  assertEquals 0 $?
  sudo sed -e '0,/^compliance_config/d' -e '/^[^ ]/,$d' $security_agent_config_file | grep -v "#" | grep -q "enabled: true"
  assertEquals 0 $?
}
testComplianceConfigurationDisabled() {
  sudo cp ${security_agent_config_file}.example $security_agent_config_file
  update_compliance_configuration "sudo" "false" $security_agent_config_file
  sudo sed -e '0,/^compliance_config/d' -e '/^[^ ]/,$d' $security_agent_config_file | grep -v "#" | grep -q "enabled: true"
  assertEquals 1 $?
}


. shunit2