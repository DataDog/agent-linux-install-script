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
	"github.com/DataDog/test-infra-definitions/scenarios/aws/vm/ec2os"
	"github.com/DataDog/test-infra-definitions/scenarios/aws/vm/ec2params"
)

type upgrade5TestSuite struct {
	linuxInstallerTestSuite
}

func TestLinuxUpgrade5Suite(t *testing.T) {
	scriptType := "production"
	if scriptURL != defaultScriptURL {
		scriptType = "custom"
	}
	t.Run(fmt.Sprintf("We will upgrade 5 %s with %s install_script on Ubuntu 22.04", flavor, scriptType), func(t *testing.T) {
		testSuite := &upgrade5TestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(ec2params.WithOS(ec2os.UbuntuOS)),
			params.WithStackName(fmt.Sprintf("upgrade5-%s-ubuntu22", flavor)),
		)
	})
}

func (s *upgrade5TestSuite) TestUpgrade5() {
	t := s.T()
	vm := s.Env().VM

	// Installation
	if flavor != "datadog-agent" {
		t.Logf("%s not supported on Agent 5", flavor)
		t.FailNow()
	}
	t.Log("Install latest Agent 5")
	cmd := fmt.Sprintf("DD_API_KEY=%s bash -c \"$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)\"", apiKey)
	vm.Execute(cmd)
	t.Log("Install latest Agent 7 RC")
	cmd = fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_UPGRADE=true DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -L %s/install_script_agent7.sh)\"", flavor, apiKey, scriptURL)
	vm.Execute(cmd)

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purge()

	s.assertPurge()
}
