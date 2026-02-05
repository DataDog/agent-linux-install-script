// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.

package e2e

import (
	"fmt"
	"strings"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/e2e"
	awshost "github.com/DataDog/datadog-agent/test/new-e2e/pkg/provisioners/aws/host"
	"github.com/stretchr/testify/assert"
)

type installPrivateActionRunnerTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallPrivateActionRunnerSuite(t *testing.T) {
	stackName := fmt.Sprintf("install-private-action-runner-%s-%s-%s", flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install %s with install_script on %s and verify private action runner setup", flavor, platform)
		testSuite := &installPrivateActionRunnerTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.WithProvisioner(awshost.ProvisionerNoAgentNoFakeIntake(awshost.WithEC2InstanceOptions(getEC2Options(t)...))),
			e2e.WithStackName(stackName),
		)
	})
}

func (s *installPrivateActionRunnerTestSuite) TestInstallWithPrivateActionRunner() {
	s.InstallAgent(7)
	s.assertPrivateActionRunnerSetup()
	s.addExtraIntegration()
	s.uninstall()
	s.assertUninstall()
	s.purge()
	s.assertPurge()
}

func (s *installPrivateActionRunnerTestSuite) assertPrivateActionRunnerSetup() {
	s.linuxInstallerTestSuite.assertInstallScript(true)

	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert dd-scriptuser user exists")
	_, err := vm.Execute("id dd-scriptuser")
	assert.NoError(t, err, "user dd-scriptuser does not exist after install")

	if _, err = vm.Execute("test -d /etc/sudoers.d"); err == nil {
		t.Log("Checking sudoers configuration for dd-scriptuser")

		_, err = vm.Execute("sudo stat /etc/sudoers.d/dd-agent")
		assert.NoError(t, err, "/etc/sudoers.d/dd-agent should exist")

		perms := strings.TrimSuffix(vm.MustExecute("sudo stat -c \"%a\" /etc/sudoers.d/dd-agent"), "\n")
		assert.Equal(t, "440", perms, "/etc/sudoers.d/dd-agent should have 440 permissions")

		content := strings.TrimSuffix(vm.MustExecute("sudo cat /etc/sudoers.d/dd-agent"), "\n")
		assert.Equal(t, "dd-agent ALL=(dd-scriptuser) NOPASSWD: ALL", content, "/etc/sudoers.d/dd-agent should contain correct sudoers rule")

		_, err = vm.Execute("sudo visudo -c -f /etc/sudoers.d/dd-agent")
		assert.NoError(t, err, "/etc/sudoers.d/dd-agent should have valid sudoers syntax")

		t.Log("Testing that dd-agent can execute commands as dd-scriptuser")
		result := strings.TrimSuffix(vm.MustExecute("sudo -u dd-agent sudo -u dd-scriptuser whoami"), "\n")
		assert.Equal(t, "dd-scriptuser", result, "dd-agent should be able to run commands as dd-scriptuser")
	} else {
		t.Log("/etc/sudoers.d does not exist, skipping sudoers checks")
	}
}

func (s *installPrivateActionRunnerTestSuite) TestSudoersPreservesExtraContent() {
	s.InstallAgent(7)

	t := s.T()
	vm := s.Env().RemoteHost

	if _, err := vm.Execute("test -d /etc/sudoers.d"); err != nil {
		t.Skip("/etc/sudoers.d does not exist, skipping sudoers preservation test")
		return
	}

	t.Log("Adding extra content to sudoers file while keeping required line")
	vm.MustExecute("sudo bash -c 'echo \"dd-agent ALL=(dd-scriptuser) NOPASSWD: ALL\" > /etc/sudoers.d/dd-agent'")
	vm.MustExecute("sudo bash -c 'echo \"# Extra comment\" >> /etc/sudoers.d/dd-agent'")

	content := strings.TrimSuffix(vm.MustExecute("sudo cat /etc/sudoers.d/dd-agent"), "\n")
	assert.Contains(t, content, "# Extra comment", "Extra content should be added")

	t.Log("Running install script again")
	s.InstallAgent(7)

	t.Log("Checking that file still contains extra content")
	newContent := strings.TrimSuffix(vm.MustExecute("sudo cat /etc/sudoers.d/dd-agent"), "\n")
	assert.Contains(t, newContent, "dd-agent ALL=(dd-scriptuser) NOPASSWD: ALL", "Required line should still be present")
	assert.Contains(t, newContent, "# Extra comment", "Extra content should be preserved when required line exists")

	s.uninstall()
	s.purge()
}

func (s *installPrivateActionRunnerTestSuite) TestSudoersAppends() {
	s.InstallAgent(7)

	t := s.T()
	vm := s.Env().RemoteHost

	if _, err := vm.Execute("test -d /etc/sudoers.d"); err != nil {
		t.Skip("/etc/sudoers.d does not exist, skipping sudoers correction test")
		return
	}

	t.Log("Setting incorrect content in sudoers file")
	vm.MustExecute("sudo bash -c 'echo \"# Wrong content\" > /etc/sudoers.d/dd-agent'")
	vm.MustExecute("sudo chmod 440 /etc/sudoers.d/dd-agent")

	content := strings.TrimSuffix(vm.MustExecute("sudo cat /etc/sudoers.d/dd-agent"), "\n")
	assert.NotContains(t, content, "dd-agent ALL=(dd-scriptuser) NOPASSWD: ALL", "File should not contain required line initially")

	t.Log("Running install script again")
	s.InstallAgent(7)

	t.Log("Checking that file was corrected")
	newContent := strings.TrimSuffix(vm.MustExecute("sudo cat /etc/sudoers.d/dd-agent"), "\n")
	assert.Contains(t, content, newContent, "File should preserve previous content")
	assert.Contains(t, "dd-agent ALL=(dd-scriptuser) NOPASSWD: ALL", newContent, "File should contain new line")

	s.uninstall()
	s.purge()
}


func (s *installPrivateActionRunnerTestSuite) assertUninstall() {
	s.linuxInstallerTestSuite.assertUninstall()
}

func (s *installPrivateActionRunnerTestSuite) assertPurge() {
	if s.shouldSkipPurge() {
		return
	}
	s.linuxInstallerTestSuite.assertPurge()
}
