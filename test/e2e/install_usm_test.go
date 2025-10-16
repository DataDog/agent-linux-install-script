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

type installUSMTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallUSMSuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("USM test supports only datadog-agent flavor")
	}
	stackName := fmt.Sprintf("install-usm-%s-%s-%s", flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install with system-probe %s with install script on %s", flavor, platform)
		testSuite := &installUSMTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.WithProvisioner(awshost.ProvisionerNoAgentNoFakeIntake(awshost.WithEC2InstanceOptions(getEC2Options(t)...))),
			e2e.WithStackName(stackName),
		)
	})
}

func (s *installUSMTestSuite) TestInstallSystemProbe() {
	s.InstallAgent(7, "DD_SYSTEM_PROBE_SERVICE_MONITORING_ENABLED=true DD_SITE=\"datadoghq.com\"", "Install latest Agent 7")

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purge()

	s.assertPurge()
}

func (s *installUSMTestSuite) assertInstallScript() {
	s.linuxInstallerTestSuite.assertInstallScript(true)
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert system probe config is created and security-agent is not created")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))

	systemProbeConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assert.NotContains(t, systemProbeConfig, "runtime_security_config")
	assert.Equal(t, true, systemProbeConfig["service_monitoring_config"].(map[any]any)["enabled"])
}

func (s *installUSMTestSuite) assertUninstall() {
	s.linuxInstallerTestSuite.assertUninstall()
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert system probe is there after uninstall")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
}

func (s *installUSMTestSuite) assertPurge() {
	if s.shouldSkipPurge() {
		return
	}
	s.linuxInstallerTestSuite.assertPurge()
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert system probe is removed after purge")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
}
