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
	"gopkg.in/yaml.v2"
)

type installMaximalAndRetryTestSuite struct {
	linuxInstallerTestSuite
}

var (
	maximalInstallLogLines = []string{
		"* Adding your API key to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
		"* Setting SITE in the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
		"* Setting DD_URL in the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
		"* Adding your HOSTNAME to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
		"* Adding your HOST TAGS to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
		"* Adding your DD_ENV to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
		"* Enabling compliance monitoring in configuration",
		"* Enabling runtime security in configuration",
	}
)

// TestLinuxInstallMaximalAndRetrySuite tests agent 7 installer with a quite exaustive list of
// environment variables. At first run variables will end up in agent configuration files, at
// second run the configuration is kept unchanged.
func TestLinuxInstallMaximalAndRetrySuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("maximal and retry test supports only datadog-agent flavor")
	}
	scriptType := "production"
	if scriptURL != defaultScriptURL {
		scriptType = "custom"
	}
	t.Run(fmt.Sprintf("We will install with maximal options and retry %s with %s install_script on %s", flavor, scriptType, platform), func(t *testing.T) {
		testSuite := &installMaximalAndRetryTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(testSuite.ec2Options...),
			params.WithStackName(fmt.Sprintf("install-maximal-%s-%s", flavor, platform)),
		)
	})
}

func (s *installMaximalAndRetryTestSuite) TestInstallMaximalAndReplayScript() {
	t := s.T()
	vm := s.Env().VM
	var output string
	t.Log("install agent 7 with maximal environment variables")
	cmd := fmt.Sprintf("DD_HOST_TAGS=\"foo:bar,baz:toto\" DD_ENV=kiki DD_HOSTNAME=totoro DD_RUNTIME_SECURITY_CONFIG_ENABLED=true DD_COMPLIANCE_CONFIG_ENABLED=true DD_AGENT_FLAVOR=%s DD_API_KEY=%s DD_SITE=\"mysite.com\" DD_URL=myintake.com DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -L %s/install_script_agent7.sh)\"",
		flavor,
		apiKey,
		scriptURL)
	output = vm.Execute(cmd)

	s.assertInstallMaximal(output)

	t.Log("install Agent 7 RC again with new environment variables")
	cmd = fmt.Sprintf("DD_HOST_TAGS=\"john:doe,john:lennon\" DD_ENV=totoro DD_HOSTNAME=kiki DD_RUNTIME_SECURITY_CONFIG_ENABLED=true DD_COMPLIANCE_CONFIG_ENABLED=true DD_AGENT_FLAVOR=%s DD_API_KEY=%s DD_SITE=darthmaul.com DD_URL=otherintake.com DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -L %s/install_script_agent7.sh)\"",
		flavor,
		apiKey,
		scriptURL)
	output = vm.Execute(cmd)

	s.assertRetryInstall(output)

	s.uninstall()
	s.assertUninstall()

	s.purge()
	s.assertPurge()
}

func (s *installMaximalAndRetryTestSuite) assertInstallMaximal(installCommandOutput string) {
	t := s.T()
	t.Log("assert install output contains configuration changes")

	for _, line := range maximalInstallLogLines {
		assert.Contains(t, installCommandOutput, line)
	}

	s.assertInstallScript()

	s.assertMaximalConfiguration()
}

func (s *installMaximalAndRetryTestSuite) assertRetryInstall(installCommandOutput string) {
	t := s.T()
	t.Log("assert install output contains configuration changes")

	for _, line := range maximalInstallLogLines {
		assert.NotContains(t, installCommandOutput, line)
	}

	assert.Contains(t, installCommandOutput, "* Keeping old /etc/datadog-agent/datadog.yaml configuration file")

	t.Log("assert configuration did not change")
	s.assertMaximalConfiguration()
}

func (s *installMaximalAndRetryTestSuite) assertMaximalConfiguration() {
	t := s.T()
	vm := s.Env().VM
	t.Log("assert comfiguration contains expected properties")
	configContent := vm.Execute(fmt.Sprintf("sudo cat /etc/%s/%s", s.baseName, s.configFile))
	var config map[string]any
	err := yaml.Unmarshal([]byte(configContent), &config)
	require.NoError(t, err, fmt.Sprintf("unexpected error on yaml parse %v", err))
	assert.Equal(t, apiKey, config["api_key"], "not matching api key in config")
	assert.Equal(t, "mysite.com", config["site"])
	assert.Equal(t, "myintake.com", config["dd_url"])
	assert.Equal(t, "totoro", config["hostname"])
	assert.Equal(t, []any{"foo:bar", "baz:toto"}, config["tags"].([]any))
	assert.Equal(t, "kiki", config["env"])

	securityAgentConfigContent := vm.Execute(fmt.Sprintf("sudo cat /etc/%s/security-agent.yaml", s.baseName))
	var securityAgentConfig map[string]any
	err = yaml.Unmarshal([]byte(securityAgentConfigContent), &securityAgentConfig)
	require.NoError(t, err, fmt.Sprintf("unexpected error on yaml parse %v", err))
	assert.Equal(t, true, securityAgentConfig["runtime_security_config"].(map[string]any)["enabled"])
	assert.Equal(t, true, securityAgentConfig["compliance_config"].(map[string]any)["enabled"])

	systemProbeConfigContent := vm.Execute(fmt.Sprintf("sudo cat /etc/%s/system-probe.yaml", s.baseName))
	var systemProbeConfig map[string]any
	err = yaml.Unmarshal([]byte(systemProbeConfigContent), &systemProbeConfig)
	require.NoError(t, err, fmt.Sprintf("unexpected error on yaml parse %v", err))
	assert.Equal(t, true, securityAgentConfig["runtime_security_config"].(map[string]any)["enabled"])
}
