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

type upgrade6TestSuite struct {
	linuxInstallerTestSuite
}

func TestUpgrade6Suite(t *testing.T) {
	if flavor != "datadog-agent" {
		t.Skipf("%s not supported on Agent 6", flavor)
	}
	stackName := fmt.Sprintf("upgrade6-%s-%s-%s", flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will upgrade 6 %s with install_script on %s", flavor, platform)
		testSuite := &upgrade6TestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(getEC2Options(t)...),
			params.WithStackName(stackName),
		)
	})
}

func (s *upgrade6TestSuite) TestUpgrade6() {
	// Installation
	s.InstallAgent(6)
	s.InstallAgent(7)

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purge()

	s.assertPurge()
}
