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

type upgrade7TestSuite struct {
	linuxInstallerTestSuite
}

func TestUpgrade7Suite(t *testing.T) {
	scriptType := "production"
	if scriptURL != defaultScriptURL {
		scriptType = "custom"
	}
	t.Run(fmt.Sprintf("We will upgrade 7 %s with %s install_script on %s", flavor, scriptType, platform), func(t *testing.T) {
		testSuite := &upgrade7TestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(testSuite.ec2Options...),
			params.WithStackName(fmt.Sprintf("upgrade7-%s-%s", flavor, platform)),
		)
	})
}

func (s *upgrade7TestSuite) TestUpgrade7() {
	t := s.T()
	vm := s.Env().VM

	// Installation
	t.Log("Install latest Agent 7")
	cmd := fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s bash -c \"$(curl -L %s/install_script_agent7.sh)\"", flavor, apiKey, scriptURL)
	vm.Execute(cmd)
	t.Log("Install latest Agent 7 RC")
	cmd = fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -L %s/install_script_agent7.sh)\"", flavor, apiKey, scriptURL)
	vm.Execute(cmd)

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purge()

	s.assertPurge()
}
