// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-present Datadog, Inc.

package e2e

import (
	"fmt"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/e2e"
	awshost "github.com/DataDog/datadog-agent/test/new-e2e/pkg/provisioners/aws/host"
	"github.com/stretchr/testify/assert"
)

type installPrivilegedLogsTestSuite struct {
	linuxInstallerTestSuite
	enabledValue bool
}

func runPrivilegedLogsTest(t *testing.T, enabled bool) {
	suffix := "enabled"
	if !enabled {
		suffix = "disabled"
	}
	stackName := fmt.Sprintf("install-privileged-logs-%s-%s-%s-%s", suffix, flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install with system-probe privileged logs %s %s with install script on %s", suffix, flavor, platform)
		testSuite := &installPrivilegedLogsTestSuite{enabledValue: enabled}
		e2e.Run(t,
			testSuite,
			e2e.WithProvisioner(awshost.ProvisionerNoAgentNoFakeIntake(awshost.WithEC2InstanceOptions(getEC2Options(t)...))),
			e2e.WithStackName(stackName),
		)
	})
}

func TestInstallPrivilegedLogsSuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("privileged logs test supports only datadog-agent flavor")
	}
	runPrivilegedLogsTest(t, true)
}

func TestInstallPrivilegedLogsDisabledSuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("privileged logs test supports only datadog-agent flavor")
	}
	runPrivilegedLogsTest(t, false)
}

func (s *installPrivilegedLogsTestSuite) TestInstallPrivilegedLogs() {
	enabledStr := "true"
	action := "enabled"
	if !s.enabledValue {
		enabledStr = "false"
		action = "explicitly disabled"
	}
	envVars := fmt.Sprintf("DD_PRIVILEGED_LOGS_ENABLED=%s DD_SITE=\"datadoghq.com\"", enabledStr)
	description := fmt.Sprintf("Install latest Agent 7 with privileged logs %s", action)
	
	s.InstallAgent(7, envVars, description)
	s.assertInstallScript()
	s.addExtraIntegration()
	s.uninstall()
	s.assertUninstall()
	s.purge()
	s.assertPurge()
}

func (s *installPrivilegedLogsTestSuite) assertInstallScript() {
	s.linuxInstallerTestSuite.assertInstallScript(true)
	t := s.T()
	vm := s.Env().RemoteHost
	
	action := "enabled"
	if !s.enabledValue {
		action = "explicitly disabled"
	}
	t.Logf("Assert system probe config is created with privileged logs %s", action)
	
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))

	systemProbeConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assert.NotContains(t, systemProbeConfig, "runtime_security_config")
	assert.NotContains(t, systemProbeConfig, "discovery")
	
	if s.enabledValue {
		assert.Equal(t, true, systemProbeConfig["privileged_logs"].(map[any]any)["enabled"])
	} else {
		assert.Contains(t, systemProbeConfig, "privileged_logs", "privileged_logs should be present in config when explicitly disabled")
		assert.Equal(t, false, systemProbeConfig["privileged_logs"].(map[any]any)["enabled"], "privileged_logs.enabled should be explicitly set to false")
	}
}

func (s *installPrivilegedLogsTestSuite) assertUninstall() {
	s.linuxInstallerTestSuite.assertUninstall()
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert system probe is there after uninstall")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
}

func (s *installPrivilegedLogsTestSuite) assertPurge() {
	if s.shouldSkipPurge() {
		return
	}
	s.linuxInstallerTestSuite.assertPurge()
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert system probe is removed after purge")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
}
