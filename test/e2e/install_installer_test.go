// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.

package e2e

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/e2e"
	awshost "github.com/DataDog/datadog-agent/test/new-e2e/pkg/environments/aws/host"
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
			e2e.WithProvisioner(awshost.ProvisionerNoAgentNoFakeIntake(awshost.WithEC2InstanceOptions(getEC2Options(t)...))),
			e2e.WithStackName(stackName),
		)
	})
}

func (s *installUpdaterTestSuite) TestInstallUpdater() {
	t := s.T()
	vm := s.Env().RemoteHost
	cmd := fmt.Sprintf("DD_INSTALLER=true DD_API_KEY=%s DD_SITE=\"datadoghq.com\" bash -c \"$(cat scripts/install_script_agent7.sh)\"", apiKey)
	output := vm.MustExecute(cmd)
	t.Log(output)
	defer s.purge()

	s.assertInstallScript(true)
	s.assertInstallerInstalled()
	s.assertValidTraceGenerated()

	s.uninstallInstaller()
	s.assertUninstallInstaller()
	// agent should not be uninstalled
	s.assertInstallScript(true)
}

// mock installer, it will return 0 for datadog-apm-inject and datadog-apm-library-python
const isInstalledScript = `#!/bin/bash
[[ "$1" == "is-installed" ]] && { [[ "$2" == "datadog-apm-inject" || "$2" == "datadog-apm-library-python" ]] && exit 0 || exit 1; } || { echo "Unsupported command"; exit 2; }`

func (s *installUpdaterTestSuite) TestPackagesInstalledByInstallerAreNotInstalledByPackageManager() {
	t := s.T()
	vm := s.Env().RemoteHost
	if _, err := vm.Execute("command -v zypper"); err == nil {
		t.Skip("zypper does not support apm packages")
	}
	vm.Execute("echo 'export PATH=/usr/local/bin:$PATH' | sudo tee -a /etc/profile")
	vm.Execute("echo '" + isInstalledScript + "' | sudo tee /usr/local/bin/datadog-installer && sudo chmod +x /usr/local/bin/datadog-installer")
	_, _ = vm.Execute("echo '" + isInstalledScript + "' | sudo tee /sbin/datadog-installer && sudo chmod +x /sbin/datadog-installer")
	cmd := fmt.Sprintf("DD_INSTALLER=true DD_APM_INSTRUMENTATION_ENABLED=host DD_API_KEY=%s DD_SITE=\"datadoghq.com\" bash -c \"$(cat scripts/install_script_agent7.sh)\"", apiKey)
	output := vm.MustExecute(cmd)
	t.Log(output)
	defer s.purge()

	s.assertInstallScript(true)
	s.assertPackageInstalledByPackageManager("datadog-agent")
	s.assertPackageInstalledByPackageManager("datadog-apm-library-ruby")
	s.assertPackageNotInstalledByPackageManager("datadog-apm-inject")
	s.assertPackageNotInstalledByPackageManager("datadog-apm-library-python")
}

func (s *installUpdaterTestSuite) TestInstallWithRemoteUpdates() {
	t := s.T()
	vm := s.Env().RemoteHost
	s.optPathOverride = "/opt/datadog-packages/%s/stable" // override the path to use the latest version
	defer func() {
		s.optPathOverride = ""
	}()
	cmd := fmt.Sprintf("DD_REMOTE_UPDATES=true DD_API_KEY=%s DD_SITE=\"datadoghq.com\" bash -c \"$(cat scripts/install_script_agent7.sh)\"", apiKey)
	output := vm.MustExecute(cmd)
	t.Log(output)
	defer s.purge()

	s.assertInstallScriptWithRemoteUpdates(true)
	s.assertValidTraceGenerated()
}

func (s *installUpdaterTestSuite) assertInstallScriptWithRemoteUpdates(active bool) {
	t := s.T()
	vm := s.Env().RemoteHost
	t.Helper()
	t.Log("Check user, config file and service")
	// check presence of the dd-agent user
	_, err := vm.Execute("id dd-agent")
	assert.NoError(t, err, "user dd-agent does not exist after install")
	// Check presence of the config file - the file is added by the install script, so this should always be okay
	// if the install succeeds
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))
	// Check presence and ownership of the config and main directories
	owner := strings.TrimSuffix(vm.MustExecute(fmt.Sprintf("stat -c \"%%U\" /etc/%s/", s.baseName)), "\n")
	assert.Equal(t, "dd-agent", owner, fmt.Sprintf("dd-agent does not own /etc/%s", s.baseName))

	serviceNames := []string{s.baseName}
	if flavor == agentFlavorDatadogAgent {
		serviceNames = append(serviceNames, "datadog-agent-trace")
		// Cannot assert process-agent because it may be running or dead based on timing
	}

	// Check that the services are active
	if _, err = vm.Execute("command -v systemctl"); err == nil {
		for _, serviceName := range serviceNames {
			_, err = vm.Execute(fmt.Sprintf("systemctl is-active %s", serviceName))
			if active {
				assert.NoError(t, err, fmt.Sprintf("%s not running after Agent install", serviceName))
			} else {
				assert.Error(t, err, fmt.Sprintf("%s running after Agent install", serviceName))
			}
		}
	}

	if t.Failed() {
		stdout, err := vm.Execute("sudo journalctl --no-pager")
		if err != nil {
			t.Logf("Failed to get journalctl logs: %s", err)
		} else {
			t.Logf("journalctl logs:\n%s", stdout)
		}
		stdout, err = vm.Execute("sudo systemctl status datadog*")
		if err != nil {
			t.Logf("Failed to get systemctl status: %s", err)
		} else {
			t.Logf("systemctl logs:\n%s", stdout)
		}
	}
}

func (s *installUpdaterTestSuite) purge() {
	t := s.T()
	vm := s.Env().RemoteHost
	t.Helper()
	vm.Execute("sudo datadog-installer purge")
	if _, err := vm.Execute("command -v apt"); err == nil {
		t.Log("Uninstall with apt")
		// remove all datadog packages
		vm.Execute("sudo apt remove -y --purge 'datadog-*'")
	} else if _, err = vm.Execute("command -v yum"); err == nil {
		t.Log("Uninstall with yum")
		vm.Execute("sudo yum remove -y 'datadog-*'")
	} else if _, err = vm.Execute("command -v zypper"); err == nil {
		t.Log("Uninstall with zypper")
		vm.Execute("sudo zypper remove -y 'datadog-*'")
	} else {
		require.FailNow(t, "Unknown package manager")
	}
}

func (s *installUpdaterTestSuite) assertInstallerInstalled() {
	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert installer is installed")
	assertFileExists(t, vm, "/opt/datadog-packages/datadog-installer/stable/bin/installer/installer")
	assertFileExists(t, vm, "/opt/datadog-installer/bin/installer/installer")

	t.Log("Assert installer is not in enabled in systemd")
	_, err := vm.Execute("systemctl is-active datadog-installer")
	assert.Error(t, err)
	assertFileNotExists(t, vm, "/lib/systemd/system/datadog-installer.service")
}

func (s *installUpdaterTestSuite) uninstallInstaller() {
	t := s.T()
	vm := s.Env().RemoteHost
	t.Helper()
	if _, err := vm.Execute("command -v apt"); err == nil {
		t.Log("Uninstall with apt")
		vm.Execute("sudo apt-get remove -y datadog-installer")
	} else if _, err = vm.Execute("command -v yum"); err == nil {
		t.Log("Uninstall with yum")
		vm.Execute("sudo yum remove -y datadog-installer")
	} else if _, err = vm.Execute("command -v zypper"); err == nil {
		t.Log("Uninstall with zypper")
		vm.Execute("sudo zypper remove -y datadog-installer")
	} else {
		require.FailNow(t, "Unknown package manager")
	}
}

func (s *installUpdaterTestSuite) assertUninstallInstaller() {
	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert installer is uninstalled")
	assertFileNotExists(t, vm, "/opt/datadog-packages/datadog-installer/stable/bin/installer/installer")
	assertFileNotExists(t, vm, "/opt/datadog-installer/bin/installer/installer")
}

func (s *installUpdaterTestSuite) assertPackageInstalledByPackageManager(pkg string) {
	t := s.T()
	vm := s.Env().RemoteHost

	if _, err := vm.Execute("command -v apt"); err == nil {
		vm.Execute("dpkg -l " + pkg + " | grep '^ii'")
	} else if _, err = vm.Execute("command -v yum"); err == nil {
		vm.Execute("yum list installed " + pkg)
	} else if _, err = vm.Execute("command -v zypper"); err == nil {
		vm.Execute("zypper se -i " + pkg)
	} else {
		require.FailNow(t, "Unknown package manager")
	}
}

func (s *installUpdaterTestSuite) assertPackageNotInstalledByPackageManager(pkg string) {
	t := s.T()
	vm := s.Env().RemoteHost

	if _, err := vm.Execute("command -v apt"); err == nil {
		vm.Execute("! dpkg -l " + pkg + " | grep -q '^ii'")
	} else if _, err = vm.Execute("command -v yum"); err == nil {
		vm.Execute("! yum list installed " + pkg + " | grep -q " + pkg)
	} else if _, err = vm.Execute("command -v zypper"); err == nil {
		vm.Execute("! zypper se -i " + pkg + " | grep -q " + pkg)
	} else {
		require.FailNow(t, "Unknown package manager")
	}
}

func (s *installUpdaterTestSuite) assertValidTraceGenerated() {
	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert valid trace generated")
	assertFileExists(t, vm, "/tmp/datadog-installer-trace.json")
	rawTrace, err := vm.ReadFile("/tmp/datadog-installer-trace.json")
	require.NoError(t, err)
	if !json.Valid(rawTrace) {
		t.Fatalf("Trace is not valid JSON: %s", string(rawTrace))
	}
}
