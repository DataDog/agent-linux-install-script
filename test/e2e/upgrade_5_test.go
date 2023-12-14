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

type upgrade5TestSuite struct {
	linuxInstallerTestSuite
}

func TestUpgrade5Suite(t *testing.T) {
	if flavor != "datadog-agent" {
		t.Skipf("%s not supported on Agent 5", flavor)
	}
	stackName := fmt.Sprintf("upgrade5-%s-%s", flavor, platform)
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will upgrade 5 %s with install_script on %s", flavor, platform)
		testSuite := &upgrade5TestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(getEC2Options(t)...),
			params.WithStackName(stackName),
		)
	})
}

func (s *upgrade5TestSuite) TestUpgrade5() {
	t := s.T()
	vm := s.Env().VM

	// Installation
	t.Log("Install latest Agent 5")
	cmd := fmt.Sprintf("DD_API_KEY=%s bash -c \"$(cat scripts/install_agent.sh)\"", apiKey)
	output := vm.Execute(cmd)
	t.Log(output)
	t.Log("Install latest Agent 7 RC")
	cmd = fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_UPGRADE=true DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(cat scripts/install_script_agent7.sh)\"", flavor, apiKey)
	output = vm.Execute(cmd)
	t.Log(output)

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purge()

	s.assertPurge()
}
