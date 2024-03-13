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
)

type installUpdaterTestSuite struct {
	linuxInstallerTestSuite
}

type installUpdaterReplaceAgent7TestSuite struct {
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
	stackName = fmt.Sprintf("install-updater-replace-agent7-%s-%s", flavor, platform)
	t.Run(stackName, func(t *testing.T) {
		testSuite := &installUpdaterReplaceAgent7TestSuite{}
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
	cmd := fmt.Sprintf("DD_INSTALL_UPDATER=true DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_SITE=\"datadoghq.com\" DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(cat scripts/install_script_agent7.sh)\"", apiKey)
	output := vm.Execute(cmd)
	t.Log(output)

	s.assertUpdaterInstallScript()
}

func (s *installUpdaterReplaceAgent7TestSuite) TestInstallUpdaterReplaceAgent7() {
	t := s.T()
	vm := s.Env().VM

	t.Log("Install latest Agent 7")
	hostnameSetDuringFirstInstall := "test-hostname-set-during-first-install"
	cmd := fmt.Sprintf("DD_HOSTNAME=%s DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s bash -c \"$(cat scripts/install_script_agent7.sh)\"", hostnameSetDuringFirstInstall, flavor, apiKey)
	output := vm.Execute(cmd)
	t.Log(output)

	t.Log("Install updater")
	cmd = fmt.Sprintf("DD_INSTALL_UPDATER=true DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_SITE=\"datadoghq.com\" DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(cat scripts/install_script_agent7.sh)\"", apiKey)
	output = vm.Execute(cmd)
	t.Log(output)

	s.assertUpdaterInstallScript()
	s.assertPackageInstalled("datadog-updater", true)
	s.assertPackageInstalled("datadog-agent", false)
	s.assertAgentHostname(hostnameSetDuringFirstInstall)
}

func (s *linuxInstallerTestSuite) assertUpdaterInstallScript() {
	t := s.T()
	vm := s.Env().VM
	assertFileExists(t, vm, "/lib/systemd/system/datadog-updater.service")
}

func (s *linuxInstallerTestSuite) assertPackageInstalled(pkg string, assertInstalled bool) {
	t := s.T()
	vm := s.Env().VM
	var installed bool
	if _, err := vm.ExecuteWithError("command -v apt"); err == nil {
		if _, err := vm.ExecuteWithError(fmt.Sprintf("dpkg-query -l \"%s\" >/dev/null 2>&1", pkg)); err == nil {
			installed = true
		}
	} else if _, err = vm.ExecuteWithError("command -v yum"); err == nil {
		if _, err := vm.ExecuteWithError(fmt.Sprintf("rpm -q \"%s\" >/dev/null 2>&1", pkg)); err == nil {
			installed = true
		}
	} else {
		t.Fatalf("unsupported package manager")
	}
	if assertInstalled != installed {
		t.Fatalf("expected package %s to be %t, got: %t", pkg, assertInstalled, installed)
	}
}

func (s *linuxInstallerTestSuite) assertAgentHostname(hostname string) {
	t := s.T()
	vm := s.Env().VM
	assertFileExists(t, vm, "/etc/datadog-agent/datadog.yaml")
	config := unmarshalConfigFile(t, vm, "/etc/datadog-agent/datadog.yaml")
	assert.Equal(t, hostname, config["hostname"])
}
