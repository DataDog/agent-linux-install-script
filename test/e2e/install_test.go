// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.

package e2e

import (
	"fmt"
	"strings"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e"
	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e/params"
	"github.com/DataDog/test-infra-definitions/scenarios/aws/vm/ec2os"
	"github.com/DataDog/test-infra-definitions/scenarios/aws/vm/ec2params"
	"github.com/stretchr/testify/assert"
)

func TestLinuxInstallerSuite(t *testing.T) {
	scriptType := "production"
	if scriptURL != defaultScriptURL {
		scriptType = "custom"
	}
	t.Run(fmt.Sprintf("We will %s %s with %s install_script on Ubuntu 22.04", mode, flavor, scriptType), func(t *testing.T) {
		testSuite := &linuxInstallerTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(ec2params.WithOS(ec2os.UbuntuOS)),
			params.WithStackName(fmt.Sprintf("%s-%s-ubuntu22", mode, flavor)),
		)
	})
}

func (s *linuxInstallerTestSuite) TestInstallerScript() {
	t := s.T()
	vm := s.Env().VM

	// Installation
	if mode == "install" {
		t.Log("Install latest Agent 7 RC")
		cmd := fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_SITE=\"datadoghq.com\" DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -sL %s/install_script_agent7.sh)\"", flavor, apiKey, scriptURL)
		vm.Execute(cmd)
	} else if mode == "upgrade7" {
		t.Log("Install latest Agent 7")
		cmd := fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s bash -c \"$(curl -L %s/install_script_agent7.sh)\"", flavor, apiKey, scriptURL)
		vm.Execute(cmd)
		t.Log("Install latest Agent 7 RC")
		cmd = fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -L %s/install_script_agent7.sh)\"", flavor, apiKey, scriptURL)
		vm.Execute(cmd)
	} else if mode == "upgrade6" {
		t.Log("Install latest Agent 6")
		cmd := fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=6 DD_API_KEY=%s bash -c \"$(curl -L %s/install_script_agent6.sh)\"", flavor, apiKey, scriptURL)
		vm.Execute(cmd)
		t.Log("Install latest Agent 7 RC")
		cmd = fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -L %s/install_script_agent7.sh)\"", flavor, apiKey, scriptURL)
		vm.Execute(cmd)
	} else if mode == "upgrade5" {
		if flavor != "datadog-agent" {
			t.Logf("%s not supported on Agent 5", flavor)
			t.FailNow()
		}
		t.Log("Install latest Agent 5")
		cmd := fmt.Sprintf("DD_API_KEY=%s bash -c \"$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)\"", apiKey)
		vm.Execute(cmd)
		t.Log("Install latest Agent 7 RC")
		cmd = fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_UPGRADE=true DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -L %s/install_script_agent7.sh)\"", flavor, apiKey, scriptURL)
		vm.Execute(cmd)
	}

	s.assertInstallScript()

	s.addExtraIntegration()

	t.Run(fmt.Sprintf("Remove %s", flavor), func(tt *testing.T) {
		if _, err := vm.ExecuteWithError("command -v apt"); err == nil {
			tt.Log("Uninstall with apt")
			vm.Execute(fmt.Sprintf("sudo apt remove -y %s", flavor))
			// dd-agent user and config file should still be here
			_, err := vm.ExecuteWithError("id dd-agent")
			assert.NoError(tt, err, "user datadog-agent not present after apt remove")
			_, err = vm.ExecuteWithError(fmt.Sprintf("stat /etc/%s/%s", s.baseName, s.configFile))
			assert.NoError(tt, err, fmt.Sprintf("/etc/%s/%s absent after apt remove", s.baseName, s.configFile))
			if flavor == "datadog-agent" {
				// The custom file should still be here. All other files, including the extra integration, should be removed
				_, err = vm.ExecuteWithError("stat /opt/datadog-agent/embedded/lib/python3.9/site-packages/testfile")
				assert.NoError(tt, err, "testfile absent after apt remove")
				files := strings.Split(strings.TrimSuffix(vm.Execute("find /opt/datadog-agent -type f"), "\n"), "\n")
				assert.Len(tt, files, 1, fmt.Sprintf("/opt/datadog-agent present after apt remove, found %v", files))
			} else {
				// All files in /opt/datadog-agent should be removed
				_, err = vm.ExecuteWithError(fmt.Sprintf("stat /opt/%s", s.baseName))
				assert.Error(tt, err, fmt.Sprintf("/opt/%s present after apt remove", s.baseName))
			}
			if !noFlush {
				tt.Log("Purge package")
				vm.Execute(fmt.Sprintf("sudo apt remove --purge -y %s", flavor))
				_, err := vm.ExecuteWithError("id datadog-agent")
				assert.Error(t, err, "dd-agent present after %s purge")
				_, err = vm.ExecuteWithError(fmt.Sprintf("stat /etc/%s", s.baseName))
				assert.Error(t, err, fmt.Sprintf("stat /etc/%s present after apt purge", s.baseName))
				_, err = vm.ExecuteWithError(fmt.Sprintf("stat /opt/%s", s.baseName))
				assert.Error(t, err, fmt.Sprintf("stat /opt/%s present after apt purge", s.baseName))
			}
		} else if _, err = vm.ExecuteWithError("command -v yum"); err == nil {
			t.Log("Uninstall with yum")
			vm.Execute(fmt.Sprintf("sudo yum remove -y %s", flavor))
			// dd-agent user and config file should still be here
			_, err := vm.ExecuteWithError("id dd-agent")
			assert.NoError(tt, err, "user datadog-agent not present after yum remove")
			_, err = vm.ExecuteWithError(fmt.Sprintf("stat /etc/%s/%s", s.baseName, s.configFile))
			assert.NoError(tt, err, fmt.Sprintf("/etc/%s/%s absent after yum remove", s.baseName, s.configFile))
			if flavor == "datadog-agent" {
				// The custom file should still be here. All other files, including the extra integration, should be removed
				_, err = vm.ExecuteWithError("stat /opt/datadog-agent/embedded/lib/python3.9/site-packages/testfile")
				assert.NoError(tt, err, "testfile absent after yum remove")
				files := strings.Split(strings.TrimSuffix(vm.Execute("find /opt/datadog-agent -type f"), "\n"), "\n")
				assert.Len(tt, files, 1, fmt.Sprintf("/opt/datadog-agent present after yum remove, found %v", files))
			} else {
				// All files in /opt/datadog-agent should be removed
				_, err = vm.ExecuteWithError(fmt.Sprintf("stat /opt/%s", s.baseName))
				assert.Error(tt, err, fmt.Sprintf("/opt/%s present after yum remove", s.baseName))
			}
		} else if _, err = vm.ExecuteWithError("command -v zypper"); err == nil {
			t.Log("Uninstall with zypper")
			vm.Execute(fmt.Sprintf("sudo zypper remove -y %s", flavor))
			//	# dd-agent user and config file should still be here
			_, err := vm.ExecuteWithError("id dd-agent")
			assert.NoError(tt, err, "user datadog-agent not present after zypper remove")
			_, err = vm.ExecuteWithError(fmt.Sprintf("stat /etc/%s/%s", s.baseName, s.configFile))
			assert.NoError(tt, err, fmt.Sprintf("/etc/%s/%s absent after zypper remove", s.baseName, s.configFile))
			if flavor == "datadog-agent" {
				// The custom file should still be here. All other files, including the extra integration, should be removed
				_, err = vm.ExecuteWithError("stat /opt/datadog-agent/embedded/lib/python3.9/site-packages/testfile")
				assert.NoError(tt, err, "testfile absent after zypper remove")
				files := strings.Split(strings.TrimSuffix(vm.Execute("find /opt/datadog-agent -type f"), "\n"), "\n")
				assert.Len(tt, files, 1, fmt.Sprintf("/opt/datadog-agent present after zypper remove, found %v", files))
			} else {
				// All files in /opt/datadog-agent should be removed
				_, err = vm.ExecuteWithError(fmt.Sprintf("stat /opt/%s", s.baseName))
				assert.Error(tt, err, fmt.Sprintf("/opt/%s present after zypper remove", s.baseName))
			}
		} else {
			assert.FailNow(t, "Unknown package manager")
		}
	})
}
