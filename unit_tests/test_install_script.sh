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
  update_hosttags "sudo" "foo:bar,titi:toto" $config_file
  yamllint -c "$yaml_config" --no-warnings $config_file
  assertEquals 0 $?
  sudo grep -w "^tags: \['foo:bar', 'titi:toto'\]" $config_file | sudo tee tmp > /dev/null
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
### update_runtime_security
testRuntimeSecurityUpdated() {
  sudo rm $security_agent_config_file
  update_runtime_security "sudo" $security_agent_config_file
  yamllint -c "$yaml_config" --no-warnings $security_agent_config_file
  assertEquals 0 $?
  sudo sed -e '0,/^runtime_security_config/d' -e '/^[^ ]/,$d' $security_agent_config_file | grep -v "#" | grep -q "enabled: true"
  assertEquals 0 $?
}
testRuntimeSecurityUpdatedSystemPrope() {
  sudo rm $system_probe_config_file
  update_runtime_security "sudo" $system_probe_config_file
  yamllint -c "$yaml_config" --no-warnings $system_probe_config_file
  assertEquals 0 $?
  sudo sed -e '0,/^runtime_security_config/d' -e '/^[^ ]/,$d' $system_probe_config_file | grep -v "#" | grep -q "enabled: true"
  assertEquals 0 $?
}
testRuntimeSecurityDisabled() {
  sudo cp ${security_agent_config_file}.example $security_agent_config_file
  update_runtime_security "sudo" $security_agent_config_file
  sudo sed -e '0,/^runtime_security_config/d' -e '/^[^ ]/,$d' $security_agent_config_file | grep -v "#" | grep -q "enabled: true"
  assertEquals 1 $?
}

### update_compliance_configuration
testComplianceConfigurationUpdated() {
  sudo rm $security_agent_config_file
  update_compliance_configuration "sudo" $security_agent_config_file
  yamllint -c "$yaml_config" --no-warnings $security_agent_config_file
  assertEquals 0 $?
  sudo sed -e '0,/^compliance_config/d' -e '/^[^ ]/,$d' $security_agent_config_file | grep -v "#" | grep -q "enabled: true"
  assertEquals 0 $?
}
testComplianceConfigurationDisabled() {
  sudo cp ${security_agent_config_file}.example $security_agent_config_file
  update_compliance_configuration "sudo" $security_agent_config_file
  sudo sed -e '0,/^compliance_config/d' -e '/^[^ ]/,$d' $security_agent_config_file | grep -v "#" | grep -q "enabled: true"
  assertEquals 1 $?
}

# shellcheck source=/dev/null
. shunit2
