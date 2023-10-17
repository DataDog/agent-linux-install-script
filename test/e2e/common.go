// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.

package e2e

import (
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e"
	"github.com/stretchr/testify/assert"
)

const (
	defaultScriptURL               = "https://s3.amazonaws.com/dd-agent/scripts"
	defaultAgentFlavor agentFlavor = agentFlavorDatadogAgent
)

var (
	// flags
	flavor    agentFlavor // datadog-agent, datadog-iot-agent, datadog-dogstatsd
	mode      string      // install, upgrade5, upgrade6, upgrade7
	apiKey    string      // Needs to be valid, at least for the upgrade5 scenario
	scriptURL string      // To test a non-published script
	noFlush   bool        // To prevent eventual cleanup, to test install_script won't override existing configuration

	baseNameByFlavor = map[agentFlavor]string{
		agentFlavorDatadogAgent:     "datadog-agent",
		agentFlavorDatadogDogstatsd: "datadog-dogstatsd",
		agentFlavorDatadogIOTAgent:  "datadog-agent",
	}
	configFileByFlavor = map[agentFlavor]string{
		agentFlavorDatadogAgent:     "datadog.yaml",
		agentFlavorDatadogDogstatsd: "dogstatsd.yaml",
		agentFlavorDatadogIOTAgent:  "datadog.yaml",
	}
)

// note: no need to call flag.Parse() on test code, go test does it
func init() {
	flag.Var(&flavor, "flavor", "defines agent install flavor, supported values are [datadog-agent, datadog-iot-agent, datadog-dogstatsd]")
	flag.StringVar(&mode, "mode", "install", "test mode")
	flag.BoolVar(&noFlush, "noFlush", false, "To prevent eventual cleanup, to test install_script won't override existing configuration")
	flag.StringVar(&apiKey, "apiKey", os.Getenv("DD_API_KEY"), "Datadog API key")
	flag.StringVar(&scriptURL, "scriptURL", defaultScriptURL, fmt.Sprintf("Defines the script URL, default %s", defaultScriptURL))
}

type linuxInstallerTestSuite struct {
	e2e.Suite[e2e.VMEnv]
	baseName   string
	configFile string
}

func (s *linuxInstallerTestSuite) SetupSuite() {
	if flavor == "" {
		s.T().Log("setting default agent flavor")
		flavor = defaultAgentFlavor
	}
	s.baseName = baseNameByFlavor[flavor]
	s.configFile = configFileByFlavor[flavor]
}

func (s *linuxInstallerTestSuite) assertInstallScript() {
	t := s.T()
	vm := s.Env().VM
	t.Log("Check user, config file and service")
	// check presence of the dd-agent user
	_, err := vm.ExecuteWithError("id dd-agent")
	assert.NoError(t, err, "user datadog-agent does not exist after install")
	// Check presence of the config file - the file is added by the install script, so this should always be okay
	// if the install succeeds
	_, err = vm.ExecuteWithError(fmt.Sprintf("stat /etc/%s/%s", s.baseName, s.configFile))
	assert.NoError(t, err, fmt.Sprintf("config file /etc/%s/%s does not exist after install", s.baseName, s.configFile))
	// Check presence and ownership of the config and main directories
	owner := strings.TrimSuffix(vm.Execute(fmt.Sprintf("stat -c \"%%U\" /etc/%s/", s.baseName)), "\n")
	assert.Equal(t, "dd-agent", owner, fmt.Sprintf("dd-agent does not own /etc/%s", s.baseName))
	owner = strings.TrimSuffix(vm.Execute(fmt.Sprintf("stat -c \"%%U\" /opt/%s/", s.baseName)), "\n")
	assert.Equal(t, "dd-agent", owner, fmt.Sprintf("dd-agent does not own /opt/%s", s.baseName))
	// Check that the service is active
	if _, err = vm.ExecuteWithError("command -v systemctl"); err == nil {
		_, err = vm.ExecuteWithError(fmt.Sprintf("systemctl is-active %s", s.baseName))
		assert.NoError(t, err, fmt.Sprintf("%s not running after Agent install", s.baseName))
	} else if _, err = vm.ExecuteWithError("command -v initctl"); err == nil {
		status := strings.TrimSuffix(vm.Execute(fmt.Sprintf("sudo status %s", s.baseName)), "\n")
		assert.Contains(t, "running", status, fmt.Sprintf("%s not running after Agent install", s.baseName))
	} else {
		assert.FailNow(t, "Unknown service manager")
	}
}

func (s *linuxInstallerTestSuite) addExtraIntegration() {
	t := s.T()
	if flavor != "datadog-agent" {
		t.Skip()
	}
	vm := s.Env().VM
	t.Log("Install an extra integration, and create a custom file")
	_, err := vm.ExecuteWithError("sudo -u dd-agent -- datadog-agent integration install -t datadog-bind9==0.1.0")
	assert.NoError(t, err, "integration install failed")
	_ = vm.Execute(fmt.Sprintf("sudo -u dd-agent -- touch /opt/%s/embedded/lib/python3.9/site-packages/testfile", s.baseName))
}
