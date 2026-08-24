#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
generated_scripts=(
  install_script.sh
  install_script_agent6.sh
  install_script_agent7.sh
  install_script_agent7_iot.sh
  install_script_docker_injection.sh
)
common_scripts=(
  install_script.sh
  install_script_agent6.sh
  install_script_agent7.sh
  install_script_docker_injection.sh
)

fail() {
  printf 'generated script contract failed: %s\n' "$1" >&2
  exit 1
}

assert_line() {
  local script=$1
  local expected=$2

  grep -Fqx -- "$expected" "$script" || fail "$(basename "$script") is missing '$expected'"
}

for script_name in "${generated_scripts[@]}"; do
  script="$repo_root/$script_name"
  [[ -x $script ]] || fail "$script_name is missing or is not executable"
  if grep -Eq '[A-Z][A-Z0-9_]*_PLACEHOLDER' "$script"; then
    fail "$script_name contains an unresolved template placeholder"
  fi
done

iot_script="$repo_root/install_script_agent7_iot.sh"
assert_line "$iot_script" 'iot_filtered_install=true'
assert_line "$iot_script" 'variant=install_script_agent7_iot'
assert_line "$iot_script" 'agent_major_version=7'
grep -Fq 'Datadog Agent 7 IoT Filtered install script' "$iot_script" ||
  fail "install_script_agent7_iot.sh is missing its report label"

for script_name in "${common_scripts[@]}"; do
  assert_line "$repo_root/$script_name" 'iot_filtered_install=false'
done

printf 'Generated script contract passed for %d scripts.\n' "${#generated_scripts[@]}"
