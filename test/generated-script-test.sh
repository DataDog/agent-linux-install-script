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
assert_line "$iot_script" '    begin_deb_iot_filter_transaction "$sudo_cmd" /etc/dpkg/dpkg.cfg.d/99-datadog-iot'
# shellcheck disable=SC2016
assert_line "$iot_script" '    install_deb_iot_filter_config "$sudo_cmd" /etc/dpkg/dpkg.cfg.d/99-datadog-iot retain-installer'
# shellcheck disable=SC2016
assert_line "$iot_script" '    install_deb_iot_filter_config "$sudo_cmd" /etc/dpkg/dpkg.cfg.d/99-datadog-iot'
assert_line "$iot_script" '    if ! validate_iot_install_layout /; then'
assert_line "$iot_script" '    commit_deb_iot_filter_transaction'
grep -Fq "DD_INFRASTRUCTURE_MODE='iot'" "$iot_script" ||
  fail "filtered IoT APT package environment does not force DD_INFRASTRUCTURE_MODE=iot"
# shellcheck disable=SC2016
grep -Fq 'finish_deb_iot_apt_install "$iot_apt_exit_code" || exit $?' "$iot_script" ||
  fail "filtered IoT APT failure does not explicitly invoke rollback"
grep -Fq 'rollback_deb_iot_filter_transaction || true' "$iot_script" ||
  fail "filtered IoT EXIT handler does not invoke rollback"
# shellcheck disable=SC2016
assert_line "$iot_script" '  ensure_iot_infrastructure_mode_config "$sudo_cmd" "$config_file"'
# shellcheck disable=SC2016
assert_line "$iot_script" '    if ! installed_agent_package_version=$(get_installed_agent_package_version deb) || [ -z "$installed_agent_package_version" ]; then'
# shellcheck disable=SC2016
assert_order "$iot_script" 'activate_iot_install_mode "$iot_filtered_install"' 'if [ -n "$DD_AGENT_MINOR_VERSION" ]'
# shellcheck disable=SC2016
assert_order "$iot_script" 'install_deb_iot_filter_config "$sudo_cmd"' "apt-get install -o Acquire::Retries='5' -y --force-yes"
assert_order "$iot_script" "apt-get install -o Acquire::Retries='5' -y --force-yes" 'validate_iot_install_layout /'
assert_order "$iot_script" 'validate_iot_install_layout /' '    commit_deb_iot_filter_transaction'
assert_order "$iot_script" '    commit_deb_iot_filter_transaction' '# Complete install_agent_packages'
[[ $(grep -Fc 'write_iot_install_profile()' "$iot_script") -eq 1 ]] ||
  fail "install_script_agent7_iot.sh should define the reviewed install profile writer once"
[[ $(grep -Fc 'install_iot_install_profile()' "$iot_script") -eq 1 ]] ||
  fail "install_script_agent7_iot.sh should define the root-context profile installer once"
# shellcheck disable=SC2016
assert_line "$iot_script" 'install_iot_install_profile "$sudo_cmd" "$etcdir/install_profile" "$installed_agent_package_version" "$variant"'
# shellcheck disable=SC2016
assert_order "$iot_script" '# Complete service_management (final stage)' \
  'install_iot_install_profile "$sudo_cmd" "$etcdir/install_profile"'
# shellcheck disable=SC2016
assert_order "$iot_script" \
  'install_iot_install_profile "$sudo_cmd" "$etcdir/install_profile"' \
  'report_telemetry "$install_id" "$install_type" "$install_time"'

for script_name in "${common_scripts[@]}"; do
  script="$repo_root/$script_name"
  assert_line "$script" 'iot_filtered_install=false'
  # shellcheck disable=SC2016
  if grep -Fq 'activate_iot_install_mode "$iot_filtered_install"' "$script" ||
     grep -Fq 'install_deb_iot_filter_config "$sudo_cmd"' "$script" ||
     grep -Fq 'install_iot_install_profile' "$script" ||
     grep -Fq "DD_INFRASTRUCTURE_MODE='iot'" "$script" ||
     grep -Fq 'iot_deb_filter_rollback' "$script"; then
    fail "$script_name contains filtered IoT orchestration"
  fi
done

failure_marker=$(mktemp)
rm -f "$failure_marker"
finalization_block=$(awk '
  /^# Complete service_management \(final stage\)/ { capture=1 }
  capture { print }
  capture && /^report_telemetry / { exit }
' "$iot_script")
set +e
# The extracted block consumes these variables and functions through eval.
# shellcheck disable=SC2034,SC2329
(
  set -e
  services=()
  no_start=
  service_cmd=service
  SUSE11=
  sudo_cmd=
  installed_agent_package_version=1:7.82.0-1
  variant=install_script_agent7_iot
  etcdir=$(dirname "$failure_marker")
  install_id=test-install-id
  install_type=install_script
  install_time=0
  end_stage() { return 73; }
  install_iot_install_profile() { : > "$failure_marker"; }
  report_telemetry() { return 0; }
  eval "$finalization_block"
)
controlled_failure_status=$?
set -e
[[ $controlled_failure_status -eq 73 ]] ||
  fail "controlled pre-marker failure should retain its status"
[[ ! -e $failure_marker ]] ||
  fail "controlled pre-marker failure published an install profile"
rm -f "$failure_marker"

localtest="$repo_root/test/localtest.sh"
grep -Fq 'verify_iot_debsums' "$localtest" || fail "localtest is missing fail-closed filtered debsums verification"
grep -Fq 'infrastructure_mode: iot' "$localtest" || fail "localtest does not verify filtered IoT infrastructure mode"
grep -Fq 'iot-installed-bytes.txt' "$localtest" || fail "localtest does not record filtered IoT logical bytes"
grep -Fq '/etc/dpkg/dpkg.cfg.d/99-datadog-iot' "$localtest" || fail "localtest does not verify the persistent dpkg filter"
# shellcheck disable=SC2016
grep -Fq 'if ! verify_iot_dpkg_policy "$iot_filter"; then' "$localtest" || fail "localtest does not exercise the installed filtered IoT dpkg policy"
grep -Fq '/etc/datadog-agent/install_profile' "$localtest" || fail "localtest does not verify the final install profile"
# shellcheck disable=SC2016
grep -Fq 'package_version: '\''$INSTALLED_PACKAGE_VERSION'\''' "$localtest" ||
  fail "localtest does not bind the install profile to the installed DEB version"
grep -Fq "stat -c '%u:%g:%a'" "$localtest" ||
  fail "localtest does not verify the install profile ownership and mode"
grep -Fq 'installer: install_script_agent7_iot' "$localtest" ||
  fail "localtest does not verify the install profile identity"

grep -q '^test_iot_filtered_ubuntu_22_04:' "$repo_root/.gitlab-ci.yml" ||
  fail "GitLab CI is missing the filtered IoT Ubuntu 22.04 job"
grep -q '^test_iot_filtered_debian_12_pinned:' "$repo_root/.gitlab-ci.yml" ||
  fail "GitLab CI is missing the pinned filtered IoT Debian 12 job"
pinned_iot_job=$(awk '
  /^test_iot_filtered_debian_12_pinned:/ { in_job=1; next }
  in_job && /^[^[:space:]]/ { exit }
  in_job { print }
' "$repo_root/.gitlab-ci.yml")
if ! grep -Fqx '    DD_AGENT_MINOR_VERSION: 82' <<< "$pinned_iot_job"; then
  fail "filtered IoT Debian 12 CI does not pin DD_AGENT_MINOR_VERSION=82"
fi
# shellcheck disable=SC2016
if ! grep -Fqx '    - if: '\''$CI_PIPELINE_SOURCE == "push"'\''' <<< "$pinned_iot_job"; then
  fail "filtered IoT Debian 12 pinned CI job must be push-only"
fi

unit_test_job=$(awk '
  /^unit_tests:/ { in_job=1; next }
  in_job && /^[^[:space:]]/ { exit }
  in_job { print }
' "$repo_root/.gitlab-ci.yml")
if ! grep -Fqx '    - ./unit_tests/test_iot_deb_orchestration.sh' <<< "$unit_test_job"; then
  fail "GitLab unit_tests does not run filtered IoT DEB orchestration tests"
fi
main_unit_line=$(grep -Fn './unit_tests/test_install_script.sh' <<< "$unit_test_job" | cut -d: -f1)
iot_unit_line=$(grep -Fn './unit_tests/test_iot_deb_orchestration.sh' <<< "$unit_test_job" | cut -d: -f1)
if [[ -z $main_unit_line || -z $iot_unit_line || $main_unit_line -ge $iot_unit_line ]]; then
  fail "GitLab unit_tests must run filtered IoT DEB orchestration after the main shunit suite"
fi

if awk '/^deploy:/{in_deploy=1} /^deploy_deprecated:/{in_deploy=0} in_deploy' "$repo_root/.gitlab-ci.yml" |
   grep -Fq install_script_agent7_iot.sh; then
  fail "install_script_agent7_iot.sh must not be publicly deployed in this draft"
fi

printf 'Generated script contract passed for %d scripts.\n' "${#generated_scripts[@]}"
