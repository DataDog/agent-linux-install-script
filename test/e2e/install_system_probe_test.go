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

type installSystemProbeTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallSystemProbeSuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("system-probe test supports only datadog-agent flavor")
	}
	stackName := fmt.Sprintf("install-system-probe-%s-%s", flavor, platform)
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install with system-probe %s with install script on %s", flavor, platform)
		testSuite := &installSystemProbeTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(getEC2Options(t)...),
			params.WithStackName(stackName),
		)
	})
}

func (s *installSystemProbeTestSuite) TestInstallSystemProbe() {
	t := s.T()
	vm := s.Env().VM
	t.Log("Install latest Agent 7 RC")
	cmd := fmt.Sprintf("DD_SYSTEM_PROBE_ENSURE_CONFIG=true DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_SITE=\"datadoghq.com\" DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(cat scripts/install_script_agent7.sh)\"", flavor, apiKey)
	output := vm.Execute(cmd)
	t.Log(output)

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purge()

	s.assertPurge()
}

func (s *installSystemProbeTestSuite) assertInstallScript() {
	s.linuxInstallerTestSuite.assertInstallScript()
	t := s.T()
	vm := s.Env().VM
	t.Log("Assert system probe config is created and security-agent is not created")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))

	systemProbeConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assert.NotContains(t, systemProbeConfig, "runtime_security_config")
}

func (s *installSystemProbeTestSuite) assertUninstall() {
	s.linuxInstallerTestSuite.assertUninstall()
	t := s.T()
	vm := s.Env().VM
	t.Log("Assert system probe is there after uninstall")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
}

func (s *installSystemProbeTestSuite) assertPurge() {
	if s.shouldSkipPurge() {
		return
	}
	s.linuxInstallerTestSuite.assertPurge()
	t := s.T()
	vm := s.Env().VM
	t.Log("Assert system probe is removed after purge")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
}
