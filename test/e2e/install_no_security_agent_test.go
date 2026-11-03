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

type installNoSecurityAgentTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallNoSecurityAgentSuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("no security agent test supports only datadog-agent flavor")
	}
	stackName := fmt.Sprintf("install-no-security-agent-%s-%s-%s", flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install %s without the security agent with install script on %s", flavor, platform)
		testSuite := &installNoSecurityAgentTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.WithProvisioner(awshost.ProvisionerNoAgentNoFakeIntake(awshost.WithEC2InstanceOptions(getEC2Options(t)...))),
			e2e.WithStackName(stackName),
		)
	})
}

func (s *installNoSecurityAgentTestSuite) TestInstallNoSecurityAgent() {
	s.InstallAgent(7, "DD_NO_SECURITY_AGENT_INSTALL=true DD_RUNTIME_SECURITY_CONFIG_ENABLED=true DD_COMPLIANCE_CONFIG_ENABLED=true DD_SITE=\"datadoghq.com\"", "Install latest Agent 7 without the security agent")

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purge()

	s.assertPurge()
}

func (s *installNoSecurityAgentTestSuite) assertInstallScript() {
	s.linuxInstallerTestSuite.assertInstallScript(true)

	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert system probe config is created and the security agent config is not")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))

	t.Log("Assert runtime security is enabled in the system probe config and sent from system-probe")
	systemProbeConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	runtimeSecurityConfig := systemProbeConfig["runtime_security_config"].(map[any]any)
	assert.Equal(t, true, runtimeSecurityConfig["enabled"])
	assert.Equal(t, true, runtimeSecurityConfig["direct_send_from_system_probe"])

	t.Log("Assert compliance runs in system-probe")
	agentConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))
	complianceConfig := agentConfig["compliance_config"].(map[any]any)
	assert.Equal(t, true, complianceConfig["enabled"])
	assert.Equal(t, true, complianceConfig["run_in_system_probe"])
}

func (s *installNoSecurityAgentTestSuite) assertUninstall() {
	s.linuxInstallerTestSuite.assertUninstall()
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert system probe config is still there after uninstall")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))
}

func (s *installNoSecurityAgentTestSuite) assertPurge() {
	if s.shouldSkipPurge() {
		return
	}
	s.linuxInstallerTestSuite.assertPurge()
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert system probe config is removed after purge")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
}
