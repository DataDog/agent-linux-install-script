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

// suAsAgent verifies dd-agent can su to dd-scriptuser.
// systemd-run creates a daemon context with unset loginuid, matching production.
// Falls back to runuser for older systemd (< 236).
const suAsAgent = `bash -c 'sudo systemd-run --quiet --wait --pipe -- runuser -u dd-agent -- su dd-scriptuser -c whoami 2>/dev/null || sudo runuser -u dd-agent -- su dd-scriptuser -c whoami'`

type installPrivateActionRunnerTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallPrivateActionRunnerSuite(t *testing.T) {
	stackName := fmt.Sprintf("install-par-%s-%s-%s", flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
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
	s.InstallAgent(7, "DD_PRIVATE_ACTION_RUNNER_ENABLED=true", "Install with DD_PRIVATE_ACTION_RUNNER_ENABLED")
	assertPrivateActionRunnerSetup(&s.linuxInstallerTestSuite)
	s.addExtraIntegration()
	s.uninstall()
	s.assertUninstall()
	s.purge()
	s.assertPurge()
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

type idempotentPrivateActionRunnerTestSuite struct {
	linuxInstallerTestSuite
}

func TestIdempotentPrivateActionRunnerSuite(t *testing.T) {
	stackName := fmt.Sprintf("idempotent-par-%s-%s-%s", flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install %s twice with install_script on %s and verify idempotent private action runner setup", flavor, platform)
		testSuite := &idempotentPrivateActionRunnerTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.WithProvisioner(awshost.ProvisionerNoAgentNoFakeIntake(awshost.WithEC2InstanceOptions(getEC2Options(t)...))),
			e2e.WithStackName(stackName),
		)
	})
}

func (s *idempotentPrivateActionRunnerTestSuite) TestIdempotentInstall() {
	s.InstallAgent(7, "DD_PRIVATE_ACTION_RUNNER_ENABLED=true", "Install with DD_PRIVATE_ACTION_RUNNER_ENABLED")

	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert dd-scriptuser user exists after first install")
	_, err := vm.Execute("id dd-scriptuser")
	assert.NoError(t, err, "user dd-scriptuser does not exist after first install")

	t.Log("Capture PAM file content after first install")
	pamContentAfterFirst := vm.MustExecute("sudo cat /etc/pam.d/su")
	pamLine := "auth sufficient pam_succeed_if.so user = dd-scriptuser ruser = dd-agent"
	assert.Contains(t, pamContentAfterFirst, pamLine, "PAM rule should be present after first install")
	firstCount := strings.Count(pamContentAfterFirst, pamLine)
	assert.Equal(t, 1, firstCount, "PAM rule should appear exactly once after first install")

	t.Log("Running install script again")
	s.InstallAgent(7, "DD_PRIVATE_ACTION_RUNNER_ENABLED=true", "Install with DD_PRIVATE_ACTION_RUNNER_ENABLED (second run)")

	t.Log("Assert dd-scriptuser user still exists after second install")
	_, err = vm.Execute("id dd-scriptuser")
	assert.NoError(t, err, "user dd-scriptuser does not exist after second install")

	t.Log("Assert PAM file was not modified on second install")
	pamContentAfterSecond := vm.MustExecute("sudo cat /etc/pam.d/su")
	secondCount := strings.Count(pamContentAfterSecond, pamLine)
	assert.Equal(t, 1, secondCount, "PAM rule should still appear exactly once after second install (no duplicate)")

	result := strings.TrimSuffix(vm.MustExecute(suAsAgent), "\n")
	assert.Equal(t, "dd-scriptuser", result, "dd-agent should be able to su to dd-scriptuser after second install")

	s.uninstall()
	s.purge()
}

func assertPrivateActionRunnerSetup(s *linuxInstallerTestSuite) {
	s.assertInstallScript(true)

	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert dd-scriptuser user exists")
	_, err := vm.Execute("id dd-scriptuser")
	assert.NoError(t, err, "user dd-scriptuser does not exist after install")

	t.Log("Checking PAM configuration for su")
	pamContent := vm.MustExecute("sudo cat /etc/pam.d/su")
	assert.Contains(t, pamContent, "auth sufficient pam_succeed_if.so user = dd-scriptuser ruser = dd-agent", "/etc/pam.d/su should contain PAM rule for dd-agent to su to dd-scriptuser")

	t.Log("Testing that dd-agent can su to dd-scriptuser")
	result := strings.TrimSuffix(vm.MustExecute(suAsAgent), "\n")
	assert.Equal(t, "dd-scriptuser", result, "dd-agent should be able to su to dd-scriptuser")
}
