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

assert_order() {
  local script=$1
  local first=$2
  local second=$3
  local first_line
  local second_line

  first_line=$(grep -Fnm1 -- "$first" "$script" | cut -d: -f1)
  second_line=$(grep -Fnm1 -- "$second" "$script" | cut -d: -f1)
  [[ -n $first_line && -n $second_line && $first_line -lt $second_line ]] ||
    fail "$(basename "$script") does not order '$first' before '$second'"
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
# shellcheck disable=SC2016
assert_line "$iot_script" 'activate_iot_install_mode "$iot_filtered_install" "$agent_major_version" "$etcdir" "$LEGACY_ETCDIR"'
# shellcheck disable=SC2016
assert_line "$iot_script" '    install_deb_iot_filter_config "$sudo_cmd" /etc/dpkg/dpkg.cfg.d/99-datadog-iot retain-installer'
# shellcheck disable=SC2016
assert_line "$iot_script" '    install_deb_iot_filter_config "$sudo_cmd" /etc/dpkg/dpkg.cfg.d/99-datadog-iot'
assert_line "$iot_script" '    if ! validate_iot_install_layout /; then'
# shellcheck disable=SC2016
assert_line "$iot_script" '    if ! installed_agent_package_version=$(get_installed_agent_package_version deb) || [ -z "$installed_agent_package_version" ]; then'
# shellcheck disable=SC2016
assert_order "$iot_script" 'activate_iot_install_mode "$iot_filtered_install"' 'if [ -n "$DD_AGENT_MINOR_VERSION" ]'
# shellcheck disable=SC2016
assert_order "$iot_script" 'install_deb_iot_filter_config "$sudo_cmd"' "apt-get install -o Acquire::Retries='5' -y --force-yes"
assert_order "$iot_script" "apt-get install -o Acquire::Retries='5' -y --force-yes" 'validate_iot_install_layout /'
assert_order "$iot_script" 'validate_iot_install_layout /' '# Complete install_agent_packages'
[[ $(grep -Fc 'write_iot_install_profile()' "$iot_script") -eq 1 ]] ||
  fail "install_script_agent7_iot.sh should define but not call the final install profile writer"

for script_name in "${common_scripts[@]}"; do
  script="$repo_root/$script_name"
  assert_line "$script" 'iot_filtered_install=false'
  # shellcheck disable=SC2016
  if grep -Fq 'activate_iot_install_mode "$iot_filtered_install"' "$script" ||
     grep -Fq 'install_deb_iot_filter_config "$sudo_cmd"' "$script"; then
    fail "$script_name contains filtered IoT Task 3 orchestration"
  fi
done

localtest="$repo_root/test/localtest.sh"
grep -Fq 'verify_iot_debsums' "$localtest" || fail "localtest is missing fail-closed filtered debsums verification"
grep -Fq 'infrastructure_mode: iot' "$localtest" || fail "localtest does not verify filtered IoT infrastructure mode"
grep -Fq 'iot-installed-bytes.txt' "$localtest" || fail "localtest does not record filtered IoT logical bytes"
grep -Fq '/etc/dpkg/dpkg.cfg.d/99-datadog-iot' "$localtest" || fail "localtest does not verify the persistent dpkg filter"
grep -Fq '/etc/datadog-agent/install_profile' "$localtest" || fail "localtest does not verify that the final profile marker is absent"

grep -q '^test_iot_filtered_ubuntu_22_04:' "$repo_root/.gitlab-ci.yml" ||
  fail "GitLab CI is missing the filtered IoT Ubuntu 22.04 job"
grep -q '^test_iot_filtered_debian_12_pinned:' "$repo_root/.gitlab-ci.yml" ||
  fail "GitLab CI is missing the pinned filtered IoT Debian 12 job"

if awk '/^deploy:/{in_deploy=1} /^deploy_deprecated:/{in_deploy=0} in_deploy' "$repo_root/.gitlab-ci.yml" |
   grep -Fq install_script_agent7_iot.sh; then
  fail "install_script_agent7_iot.sh must not be publicly deployed in this draft"
fi

printf 'Generated script contract passed for %d scripts.\n' "${#generated_scripts[@]}"
