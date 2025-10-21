// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.

package e2e

import (
	"fmt"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/e2e"
	awshost "github.com/DataDog/datadog-agent/test/new-e2e/pkg/provisioners/aws/host"
	"github.com/stretchr/testify/assert"
)

type installLogsConfigProcessCollectAllTestSuite struct {
	linuxInstallerTestSuite
}

type installLogsConfigProcessCollectAllDisabledPrivilegedLogsTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallLogsConfigProcessCollectAllSuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("logs config process collect all test supports only datadog-agent flavor")
	}
	stackName := fmt.Sprintf("install-logs-config-process-collect-all-%s-%s-%s", flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install with logs config process collect all %s with install script on %s", flavor, platform)
		testSuite := &installLogsConfigProcessCollectAllTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.WithProvisioner(awshost.ProvisionerNoAgentNoFakeIntake(awshost.WithEC2InstanceOptions(getEC2Options(t)...))),
			e2e.WithStackName(stackName),
		)
	})
}

func TestInstallLogsConfigProcessCollectAllDisabledPrivilegedLogsSuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("logs config process collect all test supports only datadog-agent flavor")
	}
	stackName := fmt.Sprintf("install-logs-config-process-collect-all-disabled-privileged-logs-%s-%s-%s", flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install with logs config process collect all and privileged logs disabled %s with install script on %s", flavor, platform)
		testSuite := &installLogsConfigProcessCollectAllDisabledPrivilegedLogsTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.WithProvisioner(awshost.ProvisionerNoAgentNoFakeIntake(awshost.WithEC2InstanceOptions(getEC2Options(t)...))),
			e2e.WithStackName(stackName),
		)
	})
}

func (s *installLogsConfigProcessCollectAllTestSuite) TestInstallLogsConfigProcessCollectAll() {
	s.InstallAgent(7, "DD_LOGS_CONFIG_PROCESS_COLLECT_ALL=true DD_SITE=\"datadoghq.com\"", "Install latest Agent 7")

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purge()

	s.assertPurge()
}

func (s *installLogsConfigProcessCollectAllDisabledPrivilegedLogsTestSuite) TestInstallLogsConfigProcessCollectAllWithPrivilegedLogsDisabled() {
	s.InstallAgent(7, "DD_LOGS_CONFIG_PROCESS_COLLECT_ALL=true DD_PRIVILEGED_LOGS_ENABLED=false DD_SITE=\"datadoghq.com\"", "Install latest Agent 7 with privileged logs explicitly disabled")

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purge()

	s.assertPurge()
}

func (s *installLogsConfigProcessCollectAllTestSuite) assertInstallScript() {
	s.linuxInstallerTestSuite.assertInstallScript(true)
	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert both datadog.yaml and system-probe.yaml configs are created")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))

	// Check datadog.yaml configuration
	datadogConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))

	// Assert logs_enabled is true
	assert.Equal(t, true, datadogConfig["logs_enabled"])

	// Assert process_config.process_collection.use_wlm is true
	processConfig, exists := datadogConfig["process_config"].(map[any]any)
	assert.True(t, exists, "process_config should exist")
	processCollection, exists := processConfig["process_collection"].(map[any]any)
	assert.True(t, exists, "process_collection should exist")
	assert.Equal(t, true, processCollection["use_wlm"])

	// Assert extra_config_providers contains process_log
	extraConfigProviders, exists := datadogConfig["extra_config_providers"].([]any)
	assert.True(t, exists, "extra_config_providers should exist")
	assert.Contains(t, extraConfigProviders, "process_log")

	// Assert logs_config.process_exclude_agent is true
	logsConfig, exists := datadogConfig["logs_config"].(map[any]any)
	assert.True(t, exists, "logs_config should exist")
	assert.Equal(t, true, logsConfig["process_exclude_agent"])

	// Assert logs_config.auto_multi_line_detection is true
	assert.Equal(t, true, logsConfig["auto_multi_line_detection"])

	// Check system-probe.yaml configuration (should have discovery enabled)
	systemProbeConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assert.Equal(t, true, systemProbeConfig["discovery"].(map[any]any)["enabled"])
	assert.Equal(t, true, systemProbeConfig["privileged_logs"].(map[any]any)["enabled"])
}

func (s *installLogsConfigProcessCollectAllDisabledPrivilegedLogsTestSuite) assertInstallScript() {
	s.linuxInstallerTestSuite.assertInstallScript(true)
	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert both datadog.yaml and system-probe.yaml configs are created")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))

	// Check system-probe.yaml configuration
	systemProbeConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))

	// Discovery should be enabled (required by DD_LOGS_CONFIG_PROCESS_COLLECT_ALL)
	assert.Equal(t, true, systemProbeConfig["discovery"].(map[any]any)["enabled"])

	// Privileged logs should be disabled when explicitly set to false
	privilegedLogsConfig, exists := systemProbeConfig["privileged_logs"].(map[any]any)
	if exists {
		assert.Equal(t, false, privilegedLogsConfig["enabled"], "privileged_logs should be disabled when DD_PRIVILEGED_LOGS_ENABLED=false")
	} else {
		// If the section doesn't exist, that's also acceptable as it means it's not enabled
		t.Log("privileged_logs section not present in config (disabled)")
	}
}

func (s *installLogsConfigProcessCollectAllDisabledPrivilegedLogsTestSuite) assertUninstall() {
	s.linuxInstallerTestSuite.assertUninstall()
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert configs are there after uninstall")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
}

func (s *installLogsConfigProcessCollectAllDisabledPrivilegedLogsTestSuite) assertPurge() {
	if s.shouldSkipPurge() {
		return
	}
	s.linuxInstallerTestSuite.assertPurge()
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert configs are removed after purge")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
}

func (s *installLogsConfigProcessCollectAllTestSuite) assertUninstall() {
	s.linuxInstallerTestSuite.assertUninstall()
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert configs are there after uninstall")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
}

func (s *installLogsConfigProcessCollectAllTestSuite) assertPurge() {
	if s.shouldSkipPurge() {
		return
	}
	s.linuxInstallerTestSuite.assertPurge()
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert configs are removed after purge")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
}
