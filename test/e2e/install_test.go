// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.

package e2e

import (
	"fmt"
	"github.com/DataDog/test-infra-definitions/scenarios/aws/vm/ec2os"
	"github.com/stretchr/testify/assert"
	"strings"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e"
	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e/params"
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
			e2e.EC2VMStackDef(getEC2Options(t)...),
			params.WithStackName(stackName),
		)
	})
}

func (s *installTestSuite) TestInstall() {
	// Installation
	s.InstallAgent(7)

	s.assertInstallScript()

	s.assertGPGKeys(false)

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purgeGPGKeys()

	s.purge()

	s.assertPurge()
}

func (s *installTestSuite) TestInstallMinorVersionPin() {
	// Installation
	s.InstallAgent(7, "DD_AGENT_MINOR_VERSION=42.0", "Install Agent 7 pinned to 7.42.0")

	s.assertPinnedInstallScript("7.42.0")

	s.assertGPGKeys(false)

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purgeGPGKeys()

	s.purge()

	s.assertPurge()
}

func (s *installTestSuite) TestInstallMinorLowestVersionPin() {
	var lowestVersion string
	osPlatform := osConfigByPlatform[platform]
	if osPlatform.osType == ec2os.DebianOS {
		lowestVersion = "26.0"
	} else {
		lowestVersion = "16.0"
	}

	t := s.T()
	vm := s.Env().VM

	// Installation
	s.InstallAgent(7, fmt.Sprintf("DD_AGENT_MINOR_VERSION=%s", lowestVersion), fmt.Sprintf("Install Agent 7 pinned to 7.%s", lowestVersion))

	if flavor == "datadog-agent" {
		_, err := vm.ExecuteWithError(fmt.Sprintf("sudo datadog-agent status | grep %s", fmt.Sprintf("7.%s", lowestVersion)))
		assert.NoError(t, err)
	}

	s.assertGPGKeys(true)

	s.uninstall()

	s.purgeGPGKeys()

	s.purge()
}

func (s *installTestSuite) assertPinnedInstallScript(pinVersion string) {
	s.linuxInstallerTestSuite.assertInstallScript()

	t := s.T()
	vm := s.Env().VM

	t.Log("Assert security agent, system probe and fips config are not created")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assertFileNotExists(t, vm, fipsConfigFilepath)

	if flavor == "datadog-agent" {
		_, err := vm.ExecuteWithError(fmt.Sprintf("datadog-agent version | grep %s", pinVersion))
		assert.NoError(t, err)
	}

}

func (s *installTestSuite) assertInstallScript() {
	s.linuxInstallerTestSuite.assertInstallScript()

	t := s.T()
	vm := s.Env().VM

	t.Log("Assert security agent, system probe and fips config are not created")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assertFileNotExists(t, vm, fipsConfigFilepath)
}

func (s *installTestSuite) assertGPGKeys(allKeysNeeded bool) {
	t := s.T()
	vm := s.Env().VM

	if osConfigByPlatform[platform].osType == ec2os.DebianOS || osConfigByPlatform[platform].osType == ec2os.UbuntuOS {
		output, err := vm.ExecuteWithError("apt-key --keyring /usr/share/keyrings/datadog-archive-keyring.gpg list 2>/dev/null | grep -oE [0-9A-Z\\ ]{9}$")
		t.Log(output)
		assert.NoError(t, err)
		assert.Equal(t, allKeysNeeded, strings.Contains(output, "382E 94DE"))
		assert.True(t, strings.Contains(output, "F14F 620E"))
		assert.True(t, strings.Contains(output, "C096 2C7D"))
	} else {
		output, err := vm.ExecuteWithError("rpm -qa gpg-pubkey*")
		t.Log(output)
		assert.NoError(t, err)
		assert.Equal(t, allKeysNeeded, strings.Contains(output, "e09422b3"))
		assert.True(t, strings.Contains(output, "fd4bf915"))
		assert.True(t, strings.Contains(output, "b01082d3"))
	}
}

func (s *installTestSuite) purgeGPGKeys() {
	t := s.T()
	vm := s.Env().VM

	if osConfigByPlatform[platform].osType == ec2os.DebianOS || osConfigByPlatform[platform].osType == ec2os.UbuntuOS {
		_, err := vm.ExecuteWithError("sudo rm /usr/share/keyrings/datadog-archive-keyring.gpg")
		assert.NoError(t, err)
	} else {
		_, err := vm.ExecuteWithError("for gpgkey in $(rpm -qa gpg-pubkey*); do rpm -e $gpgkey; done")
		assert.NoError(t, err)
	}
}
