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
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type installUpdaterTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallUpdaterSuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("updater test supports only datadog-agent flavor")
	}
	stackName := fmt.Sprintf("install-updater-%s-%s", flavor, platform)
	t.Run(stackName, func(t *testing.T) {
		testSuite := &installUpdaterTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(getEC2Options(t)...),
			params.WithStackName(stackName),
		)
	})
}

func (s *installUpdaterTestSuite) TestInstallUpdater() {
	t := s.T()
	vm := s.Env().VM
	cmd := fmt.Sprintf("DD_INSTALLER=true DD_APM_INSTRUMENTATION_ENABLED=host DD_APM_INSTRUMENTATION_LANGUAGES=\" \" DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_SITE=\"datadoghq.com\" DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(cat scripts/install_script_agent7.sh)\"", apiKey)
	output := vm.Execute(cmd)
	t.Log(output)

	s.assertInstallScript()
	s.assertInstallerInstalled()

	s.uninstallInstaller()
	s.assertUninstallInstaller()
	// agent should not be uninstalled
	s.assertInstallScript()
}

func (s *installUpdaterTestSuite) assertInstallerInstalled() {
	t := s.T()
	vm := s.Env().VM

	t.Log("Assert installer is installed")
	assertFileExists(t, vm, "/opt/datadog-packages/datadog-installer/stable/bin/installer/installer")
	assertFileExists(t, vm, "/opt/datadog-installer/bin/installer/installer")

	t.Log("Assert installer is not in enabled in systemd")
	_, err := vm.ExecuteWithError(fmt.Sprintf("systemctl is-active datadog-installer"))
	assert.Error(t, err)
	assertFileNotExists(t, vm, "/lib/systemd/system/datadog-installer.service")
}

func (s *installUpdaterTestSuite) uninstallInstaller() {
	t := s.T()
	vm := s.Env().VM
	t.Helper()
	if _, err := vm.ExecuteWithError("command -v apt"); err == nil {
		t.Log("Uninstall with apt")
		vm.Execute("sudo apt-get remove -y datadog-installer")
	} else if _, err = vm.ExecuteWithError("command -v yum"); err == nil {
		t.Log("Uninstall with yum")
		vm.Execute("sudo yum remove -y datadog-installer")
	} else if _, err = vm.ExecuteWithError("command -v zypper"); err == nil {
		t.Log("Uninstall with zypper")
		vm.Execute("sudo zypper remove -y datadog-installer")
	} else {
		require.FailNow(t, "Unknown package manager")
	}
}

func (s *installUpdaterTestSuite) assertUninstallInstaller() {
	t := s.T()
	vm := s.Env().VM

	t.Log("Assert installer is uninstalled")
	assertFileNotExists(t, vm, "/opt/datadog-packages/datadog-installer/stable/bin/installer/installer")
	assertFileNotExists(t, vm, "/opt/datadog-installer/bin/installer/installer")
}
