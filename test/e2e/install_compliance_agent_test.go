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

type installComplianceAgentTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallComplianceAgentSuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("compliance agent test supports only datadog-agent flavor")
	}
	stackName := fmt.Sprintf("install-compliance-agent-%s-%s-%s", flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install with compliance agent %s with install script on %s", flavor, platform)
		testSuite := &installComplianceAgentTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.WithProvisioner(awshost.ProvisionerNoAgentNoFakeIntake(awshost.WithEC2InstanceOptions(getEC2Options(t)...))),
			e2e.WithStackName(stackName),
		)
	})
}

func (s *installComplianceAgentTestSuite) TestInstallComplianceAgent() {
	s.InstallAgent(7, "DD_COMPLIANCE_CONFIG_ENABLED=true DD_SITE=\"datadoghq.com\"", "Install latest Agent 7")

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purge()

	s.assertPurge()
}

func (s *installComplianceAgentTestSuite) assertInstallScript() {
	s.linuxInstallerTestSuite.assertInstallScript(true)

	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert fips config is not created")
	assertFileNotExists(t, vm, fipsConfigFilepath)

	t.Log("Assert system probe config is not created")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))

	t.Log("Assert security-agent is created")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))

	securityAgentConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))
	assert.Equal(t, true, securityAgentConfig["compliance_config"].(map[any]any)["enabled"], fmt.Sprintf("compliance_config should be enabled, raw config content:\n%v\n\n", securityAgentConfig))
	assert.NotContains(t, securityAgentConfig, "runtime_security_config")
}

func (s *installComplianceAgentTestSuite) assertUninstall() {
	s.linuxInstallerTestSuite.assertUninstall()
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert security-agent is there after uninstall")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))
}

func (s *installComplianceAgentTestSuite) assertPurge() {
	if s.shouldSkipPurge() {
		return
	}
	s.linuxInstallerTestSuite.assertPurge()
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert security-agent is removed after purge")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))
}
