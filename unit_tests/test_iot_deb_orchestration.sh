#!/usr/bin/env bash

set -u

dir_path=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=/dev/null
source "${dir_path}/extracted_functions.sh"
eval "$(awk '
  /^function dpkg_path_is_excluded\(\)/ { capture=1 }
  /^# Patch the sources.list file for debian/ { capture=0 }
  capture { print }
' "${dir_path}/../test/localtest.sh")"

unset_iot_options() {
  unset DD_AGENT_FLAVOR
  unset DD_INFRASTRUCTURE_MODE
  unset DD_FIPS_MODE
  unset DD_APM_INSTRUMENTATION_ENABLED
  unset DD_APM_INSTRUMENTATION_LIBRARIES
  unset DD_OTELCOLLECTOR_ENABLED
  unset DD_REMOTE_UPDATES
  unset DD_NO_AGENT_INSTALL
  unset DD_UPGRADE
  unset DD_RUNTIME_SECURITY_CONFIG_ENABLED
  unset DD_COMPLIANCE_CONFIG_ENABLED
  unset DD_DISCOVERY_ENABLED
  unset DD_SYSTEM_PROBE_SERVICE_MONITORING_ENABLED
  unset DD_PRIVILEGED_LOGS_ENABLED
  unset DD_PRIVATE_ACTION_RUNNER_ENABLED
}

setUp() {
  unset_iot_options
  TEST_ROOT=$(mktemp -d)
  agent_flavor=unexpected-internal-flavor
  infrastructure_mode=unexpected-internal-mode
  nice_flavor=Unexpected
}

tearDown() {
  unset -f dpkg-query 2>/dev/null || true
  unset -f rpm 2>/dev/null || true
  unset -f sudo 2>/dev/null || true
  unset_iot_options
  rm -rf "$TEST_ROOT"
}

assertContains() {
  local message=$1
  local actual=$2
  local expected=$3

  case "$actual" in
    *"$expected"*) assertTrue "$message" 0 ;;
    *) assertTrue "$message: expected <$actual> to contain <$expected>" 1 ;;
  esac
}

testFilteredModeForcesNormalAgentAndIotInfrastructureMode() {
  DD_INSTALL_ONLY=true
  # shellcheck disable=SC2329
  dpkg-query() { return 1; }
  # shellcheck disable=SC2329
  rpm() { return 1; }

  activate_iot_install_mode true 7 "$TEST_ROOT/etc/datadog-agent" "$TEST_ROOT/etc/dd-agent"
  assertEquals "filtered activation should succeed" 0 $?
  assertEquals "normal Agent package should be forced" datadog-agent "$agent_flavor"
  assertEquals "IoT infrastructure mode should be forced" iot "$infrastructure_mode"
  assertEquals "readable flavor should follow the forced package" "Datadog Agent" "$nice_flavor"
  assertEquals "DD_INSTALL_ONLY remains supported" true "$DD_INSTALL_ONLY"
}

testOrdinaryModeDoesNotChangeResolvedOptions() {
  activate_iot_install_mode false 7 "$TEST_ROOT/etc/datadog-agent" "$TEST_ROOT/etc/dd-agent"
  assertEquals "ordinary activation should be a no-op" 0 $?
  assertEquals unexpected-internal-flavor "$agent_flavor"
  assertEquals unexpected-internal-mode "$infrastructure_mode"
  assertEquals Unexpected "$nice_flavor"
}

testFilteredModeValidatesExplicitOptionsBeforeForcingValues() {
  local output
  local status

  export DD_AGENT_FLAVOR=datadog-iot-agent
  # shellcheck disable=SC2329
  dpkg-query() { return 1; }
  output=$(activate_iot_install_mode true 7 "$TEST_ROOT/etc/datadog-agent" "$TEST_ROOT/etc/dd-agent" 2>&1)
  status=$?

  assertNotEquals "an incompatible explicit flavor should be rejected" 0 "$status"
  assertContains "the rejection should name the explicit option" "$output" DD_AGENT_FLAVOR
}

testFilteredModeRejectsEachExistingDebAgentPackage() {
  local existing_package
  local output
  local status

  for existing_package in datadog-agent datadog-iot-agent; do
    # shellcheck disable=SC2329
    dpkg-query() {
      if [ "${*: -1}" = "$existing_package" ]; then
        printf 'installed\n'
        return 0
      fi
      return 1
    }

    output=$(activate_iot_install_mode true 7 "$TEST_ROOT/etc/datadog-agent" "$TEST_ROOT/etc/dd-agent" 2>&1)
    status=$?
    assertNotEquals "$existing_package should make the filtered draft fail closed" 0 "$status"
    assertContains "the package rejection should identify $existing_package" "$output" "$existing_package"
    unset -f dpkg-query
  done
}

testFilteredModeRejectsPreExistingConfigurationTrees() {
  local config_path
  local output
  local status

  # shellcheck disable=SC2329
  dpkg-query() { return 1; }
  # shellcheck disable=SC2329
  rpm() { return 1; }

  for config_path in "$TEST_ROOT/etc/datadog-agent" "$TEST_ROOT/etc/dd-agent"; do
    rm -rf "${TEST_ROOT:?}/etc"
    mkdir -p "$config_path"
    output=$(activate_iot_install_mode true 7 "$TEST_ROOT/etc/datadog-agent" "$TEST_ROOT/etc/dd-agent" 2>&1)
    status=$?
    assertNotEquals "$config_path should make the filtered draft fail closed" 0 "$status"
    assertContains "the configuration rejection should identify $config_path" "$output" "$config_path"
  done
}

testIotDebsumsAcceptsOnlyMissingPathsCoveredByDpkgRules() {
  local original_matcher
  local output
  local status

  original_matcher=$(declare -f dpkg_path_is_excluded)
  # shellcheck disable=SC2329
  debsums() {
    printf '%s\n' \
      'debsums: missing file /opt/datadog-agent/embedded/bin/python3 (from datadog-agent package)' \
      'debsums: missing file /opt/datadog-agent/bin/process-agent/process-agent (from datadog-agent package)'
    return 2
  }
  # shellcheck disable=SC2329
  dpkg_path_is_excluded() {
    case "$1" in
      /opt/datadog-agent/embedded/bin/python3|/opt/datadog-agent/bin/process-agent/process-agent) return 0 ;;
      *) return 1 ;;
    esac
  }

  output=$(verify_iot_debsums datadog-agent 2>&1)
  status=$?
  eval "$original_matcher"
  unset -f debsums

  assertEquals "excluded missing paths should be accepted" 0 "$status"
  assertContains "the result should count every classified missing path" "$output" "All 2 reported missing package paths"
}

testIotDebsumsRejectsUnexcludedMissingPathsAndRetainedChecksumErrors() {
  local original_matcher
  local output
  local status

  original_matcher=$(declare -f dpkg_path_is_excluded)
  # shellcheck disable=SC2329
  debsums() {
    printf '%s\n' \
      'debsums: missing file /opt/datadog-agent/embedded/bin/python3 (from datadog-agent package)' \
      'debsums: changed file /opt/datadog-agent/bin/agent/agent (from datadog-agent package)'
    return 2
  }
  # shellcheck disable=SC2329
  dpkg_path_is_excluded() { return 1; }

  output=$(verify_iot_debsums datadog-agent 2>&1)
  status=$?
  eval "$original_matcher"
  unset -f debsums

  assertNotEquals "unexcluded or retained checksum failures should fail closed" 0 "$status"
  assertContains "unexcluded missing path should be reported" "$output" "not excluded"
  assertContains "changed retained content should be fatal" "$output" "Retained package checksum error"
}

testDebFilterRootInstallerUsesShellWrapperAndProducesRootMode0644File() {
  local destination=$TEST_ROOT/etc/dpkg/dpkg.cfg.d/99-datadog-iot
  local sudo_arguments=$TEST_ROOT/sudo-arguments

  mkdir -p "$(dirname "$destination")"
  # shellcheck disable=SC2329
  sudo() {
    printf '%s\n' "$@" > "$sudo_arguments"
    "$@"
  }

  install_deb_iot_filter_config sudo "$destination"
  assertEquals "root-context installation should succeed" 0 $?
  assertEquals "the wrapper should invoke a shell, not a shell function" sh "$(head -n 1 "$sudo_arguments")"
  assertTrue "the persistent filter should be a regular file" "[ -f '$destination' ]"
  assertFalse "the persistent filter should not be a symlink" "[ -L '$destination' ]"
  assertEquals "the persistent filter mode" 644 "$(stat -c '%a' "$destination")"
  assertEquals "the persistent filter owner" "$(id -u)" "$(stat -c '%u' "$destination")"
  assertContains "the rendered filter should exclude Python" "$(cat "$destination")" 'path-exclude=/opt/datadog-agent/embedded/bin/*'
}

testDebFilterRootInstallerCanRetainInstallerOnlyDuringPackageConfiguration() {
  local destination=$TEST_ROOT/etc/dpkg/dpkg.cfg.d/99-datadog-iot

  mkdir -p "$(dirname "$destination")"
  install_deb_iot_filter_config "" "$destination" retain-installer
  assertEquals "install-time filter installation should succeed" 0 $?
  assertEquals "the installer should be transiently retained" \
    'path-include=/opt/datadog-agent/embedded/bin/installer' "$(tail -n 1 "$destination")"

  install_deb_iot_filter_config "" "$destination"
  assertEquals "persistent filter replacement should succeed" 0 $?
  assertFalse "the persistent filter should not retain the package installer" \
    "grep -q '^path-include=/opt/datadog-agent/embedded/bin/installer$' '$destination'"
}

testDebFilterRootInstallerPreservesExistingFilterUntilReplacementSucceeds() {
  local destination=$TEST_ROOT/etc/dpkg/dpkg.cfg.d/99-datadog-iot
  local fake_bin=$TEST_ROOT/bin
  local real_mv
  local output
  local status

  mkdir -p "$(dirname "$destination")" "$fake_bin"
  printf 'existing valid filter\n' > "$destination"
  real_mv=$(command -v mv)
  cat > "$fake_bin/mv" <<EOF
#!/bin/sh
last_argument=
for argument do
  last_argument=\$argument
done
case "\$last_argument" in
  '$destination') exit 73 ;;
esac
exec '$real_mv' "\$@"
EOF
  chmod +x "$fake_bin/mv"

  output=$(PATH="$fake_bin:$PATH" install_deb_iot_filter_config "" "$destination" 2>&1)
  status=$?

  assertNotEquals "a failed atomic replacement should return nonzero" 0 "$status"
  assertEquals "the prior complete filter should be preserved" "existing valid filter" "$(cat "$destination")"
  assertEquals "same-directory root temporary files should be cleaned" 0 "$(find "$(dirname "$destination")" -name '.datadog_iot_filter.root.*' | wc -l | tr -d ' ')"
}

# shellcheck source=/dev/null
. shunit2
