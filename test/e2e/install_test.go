// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.

package e2e

import (
	"fmt"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/e2e"
	awshost "github.com/DataDog/datadog-agent/test/new-e2e/pkg/environments/aws/host"
	"github.com/stretchr/testify/assert"
)

type installTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallSuite(t *testing.T) {
	stackName := fmt.Sprintf("install-%s-%s-%s", flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install %s with install_script on %s", flavor, platform)
		testSuite := &installTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.WithProvisioner(awshost.ProvisionerNoAgentNoFakeIntake(awshost.WithEC2InstanceOptions(getEC2Options(t)...))),
			e2e.WithStackName(stackName),
		)
	})
}

func (s *installTestSuite) TestInstall() {
	// Installation
	s.InstallAgent(7)

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purge()

	s.assertPurge()
}

func (s *installTestSuite) TestInstallMinorVersionPin() {
	// Installation
	s.InstallAgent(7, "DD_AGENT_MINOR_VERSION=42.0", "Install Agent 7 pinned to 7.42.0")

	s.assertPinnedInstallScript("7.42.0")

	s.uninstall()

	s.purge()

	s.assertPurge()
}

func (s *installTestSuite) assertPinnedInstallScript(pinVersion string) {
	s.linuxInstallerTestSuite.assertInstallScript()

	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert security agent, system probe and fips config are not created")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assertFileNotExists(t, vm, fipsConfigFilepath)

	if flavor == "datadog-agent" {
		_, err := vm.Execute(fmt.Sprintf("datadog-agent version | grep %s", pinVersion))
		assert.NoError(t, err)
	}

}

func (s *installTestSuite) assertInstallScript() {
	s.linuxInstallerTestSuite.assertInstallScript()

	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert security agent, system probe and fips config are not created")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assertFileNotExists(t, vm, fipsConfigFilepath)
}
