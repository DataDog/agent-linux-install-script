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
	stackName := fmt.Sprintf("upgrade7-%s-%s", flavor, platform)
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will upgrade 7 %s with install_script on %s", flavor, platform)
		testSuite := &upgrade7TestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(getEC2Options(t)...),
			params.WithStackName(stackName),
		)
	})
}

func (s *upgrade7TestSuite) TestUpgrade7() {
	// Installation
	s.InstallAgent(7, "DD_AGENT_MINOR_VERSION=42.0", "Install Old Agent 7 version : 7.42.0")
	s.InstallAgent(7)

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purge()

	s.assertPurge()
}
