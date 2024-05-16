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
	cmd := fmt.Sprintf("DD_INSTALLER=true DD_APM_INSTRUMENTATION_ENABLED=host DD_APM_INSTRUMENTATION_LANGUAGES=\" \" DD_API_KEY=%s DD_SITE=\"datadoghq.com\" bash -c \"$(cat scripts/install_script_agent7.sh)\"", apiKey)
	output := vm.Execute(cmd)
	t.Log(output)
	defer s.purge()

	s.assertInstallScript()
	s.assertInstallerInstalled()

	s.uninstallInstaller()
	s.assertUninstallInstaller()
	// agent should not be uninstalled
	s.assertInstallScript()
}

// mock installer, it will return 0 for datadog-apm-inject and datadog-apm-library-python
const isInstalledScript = `#!/bin/bash
[[ "$1" == "is-installed" ]] && { [[ "$2" == "datadog-apm-inject" || "$2" == "datadog-apm-library-python" ]] && exit 0 || exit 1; } || { echo "Unsupported command"; exit 2; }`

func (s *installUpdaterTestSuite) TestPackagesInstalledByInstallerAreNotInstalledByPackageManager() {
	t := s.T()
	vm := s.Env().VM
	vm.Execute("echo 'export PATH=/:$PATH' >> /etc/profile")
	vm.Execute("echo '" + isInstalledScript + "' | sudo tee /datadog-installer && sudo chmod +x /datadog-installer")
	cmd := fmt.Sprintf("DD_INSTALLER=true DD_APM_INSTRUMENTATION_ENABLED=host DD_API_KEY=%s DD_SITE=\"datadoghq.com\" bash -c \"$(cat scripts/install_script_agent7.sh)\"", apiKey)
	output := vm.Execute(cmd)
	t.Log(output)
	defer s.purge()

	s.assertInstallScript()
	s.assertPackageInstalledByPackageManager("datadog-agent")
	s.assertPackageInstalledByPackageManager("datadog-apm-library-ruby")
	s.assertPackageNotInstalledByPackageManager("datadog-apm-inject")
	s.assertPackageNotInstalledByPackageManager("datadog-apm-library-python")
}

func (s *installUpdaterTestSuite) purge() {
	t := s.T()
	vm := s.Env().VM
	t.Helper()
	if _, err := vm.ExecuteWithError("command -v apt"); err == nil {
		t.Log("Uninstall with apt")
		// remove all datadog packages
		vm.Execute("sudo apt remove -y --purge 'datadog-*'")
	} else if _, err = vm.ExecuteWithError("command -v yum"); err == nil {
		t.Log("Uninstall with yum")
		vm.Execute(fmt.Sprintf("sudo yum remove -y 'datadog-*'"))
	} else if _, err = vm.ExecuteWithError("command -v zypper"); err == nil {
		t.Log("Uninstall with zypper")
		vm.Execute(fmt.Sprintf("sudo zypper remove -y 'datadog-*'"))
	} else {
		require.FailNow(t, "Unknown package manager")
	}
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

func (s *installUpdaterTestSuite) assertPackageInstalledByPackageManager(pkg string) {
	t := s.T()
	vm := s.Env().VM

	if _, err := vm.ExecuteWithError("command -v apt"); err == nil {
		vm.Execute("dpkg -l " + pkg + " | grep '^ii'")
	} else if _, err = vm.ExecuteWithError("command -v yum"); err == nil {
		vm.Execute("yum list installed " + pkg)
	} else if _, err = vm.ExecuteWithError("command -v zypper"); err == nil {
		vm.Execute("zypper se -i " + pkg)
	} else {
		require.FailNow(t, "Unknown package manager")
	}
}

func (s *installUpdaterTestSuite) assertPackageNotInstalledByPackageManager(pkg string) {
	t := s.T()
	vm := s.Env().VM

	if _, err := vm.ExecuteWithError("command -v apt"); err == nil {
		vm.Execute("! dpkg -l " + pkg + " | grep -q '^ii'")
	} else if _, err = vm.ExecuteWithError("command -v yum"); err == nil {
		vm.Execute("! yum list installed " + pkg + " | grep -q " + pkg)
	} else if _, err = vm.ExecuteWithError("command -v zypper"); err == nil {
		vm.Execute("! zypper se -i " + pkg + " | grep -q " + pkg)
	} else {
		require.FailNow(t, "Unknown package manager")
	}
}
