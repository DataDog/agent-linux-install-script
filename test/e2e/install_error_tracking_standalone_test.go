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

type installErrorTrackingStandaloneTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallErrorTrackingStandaloneSuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("error tracking standalone test supports only datadog-agent flavor")
	}
	stackName := fmt.Sprintf("install-error-tracking-standalone-%s-%s-%s", flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install with error tracking standalone %s with install script on %s", flavor, platform)
		testSuite := &installErrorTrackingStandaloneTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.WithProvisioner(awshost.ProvisionerNoAgentNoFakeIntake(awshost.WithEC2InstanceOptions(getEC2Options(t)...))),
			e2e.WithStackName(stackName),
		)
	})
}

func (s *installErrorTrackingStandaloneTestSuite) TestInstallErrorTrackingStandalone() {
	output := s.InstallAgent(7, "DD_APM_ERROR_TRACKING_STANDALONE=true DD_URL=\"fake.url.com\" DD_SITE=\"darth.vader.com\"", "Install latest Agent 7")

	s.assertInstallErrorTrackingStandalone(output)
	s.addExtraIntegration()
	s.uninstall()
	s.assertUninstall()
	s.purge()
	s.assertPurge()
}

func (s *installErrorTrackingStandaloneTestSuite) assertInstallErrorTrackingStandalone(installCommandOutput string) {
	t := s.T()
	vm := s.Env().RemoteHost

	s.assertInstallScript(true)

	t.Log("assert install output contains expected lines")
	assert.Contains(t, installCommandOutput, "* Setting Datadog Agent configuration to use Error Tracking backend: /etc/datadog-agent/datadog.yaml", "Missing installer log line for Error Tracking backend")

	t.Log("assert agent configuration contains expected properties")
	config := unmarshalConfigFile(t, vm, fmt.Sprintf("etc/%s/%s", s.baseName, s.configFile))
	assert.Contains(t, config, "apm_config")
	apmConfig, ok := config["apm_config"].(map[any]any)
	assert.True(t, ok, fmt.Sprintf("failed parsing config[apm_config] to map \n%v\n\n", config["apm_config"]))
	assert.Equal(t, true, apmConfig["enabled"], fmt.Sprintf("apm_config.enabled should be true, content:\n%v\n\n", apmConfig))

	etStandaloneConfig, ok := apmConfig["error_tracking_standalone"].(map[any]any)
	assert.True(t, ok, fmt.Sprintf("failed parsing apmConfig[error_tracking_standalone] to map \n%v\n\n", apmConfig["error_tracking_standalone"]))
	assert.Equal(t, true, etStandaloneConfig["enabled"], fmt.Sprintf("apm_config.error_tracking_standalone.enabled should be true, content:\n%v\n\n", etStandaloneConfig))

	t.Log("assert agent configuration contains expected properties")
	env := unmarshallEnvFile(t, vm, envFile)
	assert.Contains(t, env, "DD_APM_ERROR_TRACKING_STANDALONE_ENABLED")
	assert.Contains(t, env, "DD_CORE_AGENT_ENABLED")
	assert.Equal(t, "true", env["DD_APM_ERROR_TRACKING_STANDALONE_ENABLED"])
	assert.Equal(t, "false", env["DD_CORE_AGENT_ENABLED"])
}
