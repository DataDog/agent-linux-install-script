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
)

type installUpdaterTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallUpdaterSuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("updater test supports only datadog-agent flavor")
	}
	stackName := fmt.Sprintf("install-updater-%s-%s", flavor, platform)
	t.Run(stackName, func(t *testing.T) {
		testSuite := &installUpdaterTestSuite{}
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
	cmd := fmt.Sprintf("DD_INSTALL_UPDATER=true DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_SITE=\"datadoghq.com\" DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(cat scripts/install_script_agent7.sh)\"", flavor, apiKey)
	output := vm.Execute(cmd)
	t.Log(output)

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()
	s.purge()
}

func (s *installSecurityAgentTestSuite) assertInstallScript() {
	s.linuxInstallerTestSuite.assertInstallScript()

	t := s.T()
	vm := s.Env().VM

	assertFileExists(t, vm, "/opt/datadog/bin/updater/updater")
}

func (s *installSecurityAgentTestSuite) assertUninstall() {
	s.linuxInstallerTestSuite.assertUninstall()
	t := s.T()
	vm := s.Env().VM
	t.Log("Assert system probe config and security-agent are there after uninstall")
	assertFileNotExists(t, vm, "/opt/datadog/bin/updater/updater")
}
