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

		assertFileExists(t, vm, "/etc/sudoers.d/dd-agent")

		perms := strings.TrimSuffix(vm.MustExecute("stat -c \"%a\" /etc/sudoers.d/dd-agent"), "\n")
		assert.Equal(t, "440", perms, "/etc/sudoers.d/dd-agent should have 440 permissions")

		content := strings.TrimSuffix(vm.MustExecute("sudo cat /etc/sudoers.d/dd-agent"), "\n")
		assert.Equal(t, "dd-agent ALL=(dd-scriptuser) NOPASSWD: ALL", content, "/etc/sudoers.d/dd-agent should contain correct sudoers rule")

		_, err = vm.Execute("sudo visudo -c -f /etc/sudoers.d/dd-agent")
		assert.NoError(t, err, "/etc/sudoers.d/dd-agent should have valid sudoers syntax")
	} else {
		t.Log("/etc/sudoers.d does not exist, skipping sudoers checks")
	}
}

func (s *installPrivateActionRunnerTestSuite) assertUninstall() {
	s.linuxInstallerTestSuite.assertUninstall()

	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert dd-scriptuser user still exists after uninstall")
	_, err := vm.Execute("id dd-scriptuser")
	assert.NoError(t, err, "user dd-scriptuser should still exist after uninstall")

	if _, err = vm.Execute("test -d /etc/sudoers.d"); err == nil {
		t.Log("Assert sudoers configuration still exists after uninstall")
		assertFileExists(t, vm, "/etc/sudoers.d/dd-agent")
	}
}

func (s *installPrivateActionRunnerTestSuite) assertPurge() {
	if s.shouldSkipPurge() {
		return
	}
	s.linuxInstallerTestSuite.assertPurge()

	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert dd-scriptuser user is removed after purge")
	_, err := vm.Execute("id dd-scriptuser")
	assert.Error(t, err, "user dd-scriptuser should be removed after purge")
}
