// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.

package e2e

import (
	"fmt"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/e2e"
	awshost "github.com/DataDog/datadog-agent/test/new-e2e/pkg/provisioners/aws/host"
	"github.com/stretchr/testify/assert"
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
		"* Enabling runtime security in /etc/datadog-agent/security-agent.yaml configuration",
		"* Enabling compliance monitoring in /etc/datadog-agent/security-agent.yaml configuration",
		"* Enabling runtime security in /etc/datadog-agent/system-probe.yaml configuration",
	}
)

// TestInstallMaximalAndRetrySuite tests agent 7 installer with a quite exaustive list of
// environment variables. At first run variables will end up in agent configuration files, at
// second run the configuration is kept unchanged.
func TestInstallMaximalAndRetrySuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("maximal and retry test supports only datadog-agent flavor")
	}
	stackName := fmt.Sprintf("install-maximal-%s-%s-%s", flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install with maximal options and retry %s with install_script on %s", flavor, platform)
		testSuite := &installMaximalAndRetryTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.WithProvisioner(awshost.ProvisionerNoAgentNoFakeIntake(awshost.WithEC2InstanceOptions(getEC2Options(t)...))),
			e2e.WithStackName(stackName),
		)
	})
}

func (s *installMaximalAndRetryTestSuite) TestInstallMaximalAndReplayScript() {
	output := s.InstallAgent(7, "DD_TAGS=\"foo:bar,baz:toto\" DD_ENV=kiki DD_HOSTNAME=totoro DD_RUNTIME_SECURITY_CONFIG_ENABLED=true DD_COMPLIANCE_CONFIG_ENABLED=true DD_SITE=\"mysite.com\" DD_URL=myintake.com", "install agent 7 with maximal environment variables")

	s.assertInstallMaximal(output)

	s.addExtraIntegration()

	output = s.InstallAgent(7, "DD_TAGS=\"john:doe,john:lennon\" DD_ENV=totoro DD_HOSTNAME=kiki DD_RUNTIME_SECURITY_CONFIG_ENABLED=true DD_COMPLIANCE_CONFIG_ENABLED=true DD_SITE=darthmaul.com DD_URL=otherintake.com", "install Agent 7 RC again with new environment variables")

	s.assertRetryInstall(output)

	s.uninstall()
	s.assertUninstall()

	s.purge()
	s.assertPurge()
}

func (s *installMaximalAndRetryTestSuite) assertInstallMaximal(installCommandOutput string) {
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("assert install output contains configuration changes")

	for _, line := range maximalInstallLogLines {
		assert.Contains(t, installCommandOutput, line)
	}

	s.assertInstallScript(true)

	assertFileNotExists(t, vm, fipsConfigFilepath)
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))

	s.assertMaximalConfiguration()
}

func (s *installMaximalAndRetryTestSuite) assertRetryInstall(installCommandOutput string) {
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("assert install output contains configuration changes")

	for _, line := range maximalInstallLogLines {
		assert.NotContains(t, installCommandOutput, line)
	}

	assertFileNotExists(t, vm, fipsConfigFilepath)
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, securityAgentConfigFileName))
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, systemProbeConfigFileName))

	assert.Contains(t, installCommandOutput, "* Keeping old /etc/datadog-agent/datadog.yaml configuration file")

	t.Log("assert configuration did not change")
	s.assertMaximalConfiguration()
}

func (s *installMaximalAndRetryTestSuite) assertMaximalConfiguration() {
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("assert comfiguration contains expected properties")
	config := unmarshalConfigFile(t, vm, fmt.Sprintf("etc/%s/%s", s.baseName, s.configFile))
	assert.Equal(t, apiKey, config["api_key"], "not matching api key in config")
	assert.Equal(t, "mysite.com", config["site"])
	assert.Equal(t, "myintake.com", config["dd_url"])
	assert.Equal(t, "totoro", config["hostname"])
	assert.Equal(t, []any{"foo:bar", "baz:toto"}, config["tags"].([]any))
	assert.Equal(t, "kiki", config["env"])

	securityAgentConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("etc/%s/%s", s.baseName, securityAgentConfigFileName))
	assert.Equal(t, true, securityAgentConfig["runtime_security_config"].(map[any]any)["enabled"])
	assert.Equal(t, true, securityAgentConfig["compliance_config"].(map[any]any)["enabled"])

	systemProbeConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("etc/%s/%s", s.baseName, systemProbeConfigFileName))
	assert.Equal(t, true, systemProbeConfig["runtime_security_config"].(map[any]any)["enabled"])
}
