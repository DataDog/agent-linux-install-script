// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.

package e2e

import (
	"fmt"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e"
	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e/params"
	"github.com/stretchr/testify/assert"
)

type installSecurityAgentTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallSecurityAgentSuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("security-agent test supports only datadog-agent flavor")
	}
	stackName := fmt.Sprintf("install-security-agent-%s-%s", flavor, platform)
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install with security-agent %s with install script on %s", flavor, platform)
		testSuite := &installSecurityAgentTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(getEC2Options(t)...),
			params.WithStackName(stackName),
		)
	})
}

func (s *installSecurityAgentTestSuite) TestInstallSecurityAgent() {
	t := s.T()
	vm := s.Env().VM
	t.Log("Install latest Agent 7 RC")
	cmd := fmt.Sprintf("DD_RUNTIME_SECURITY_CONFIG_ENABLED=true DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_SITE=\"datadoghq.com\" DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(cat scripts/install_script_agent7.sh)\"", flavor, apiKey)
	output := vm.Execute(cmd)
	t.Log(output)

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purge()

	s.assertPurge()
}

func (s *installSecurityAgentTestSuite) assertInstallScript() {
	s.linuxInstallerTestSuite.assertInstallScript()

	t := s.T()
	vm := s.Env().VM

	t.Log("Assert fips config is not created")
	assertFileNotExists(t, vm, fipsConfigFilepath)

	t.Log("Assert system probe config and security-agent are created")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))

	securityAgentConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))
	assert.Equal(t, true, securityAgentConfig["runtime_security_config"].(map[any]any)["enabled"])
	assert.NotContains(t, securityAgentConfig, "compliance_config")

	systemProbeConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assert.Equal(t, true, systemProbeConfig["runtime_security_config"].(map[any]any)["enabled"])
}

func (s *installSecurityAgentTestSuite) assertUninstall() {
	s.linuxInstallerTestSuite.assertUninstall()
	t := s.T()
	vm := s.Env().VM
	t.Log("Assert system probe config and security-agent are there after uninstall")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))
}

func (s *installSecurityAgentTestSuite) assertPurge() {
	if s.shouldSkipPurge() {
		return
	}
	s.linuxInstallerTestSuite.assertPurge()
	t := s.T()
	vm := s.Env().VM
	t.Log("Assert system probe config and security-agent are removed after purge")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))
}
