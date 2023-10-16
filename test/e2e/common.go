// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.

package e2e

import (
	"flag"
	"fmt"
	"os"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e"
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
