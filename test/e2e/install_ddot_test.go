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

type installDDOTTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallDDOTSuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("DDOT test supports only datadog-agent flavor")
	}
	stackName := fmt.Sprintf("install-ddot-%s-%s-%s", flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install %s with DDOT with install script on %s", flavor, platform)
		testSuite := &installDDOTTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.WithProvisioner(awshost.ProvisionerNoAgentNoFakeIntake(awshost.WithEC2InstanceOptions(getEC2Options(t)...))),
			e2e.WithStackName(stackName),
		)
	})
}

func (s *installDDOTTestSuite) TestInstallDDOT() {
	// TODO: Remove testing URLs and minor version when packages get promoted to prod
	s.InstallAgent(7, "DD_OTELCOLLECTOR_ENABLED=true DD_SITE=\"datadoghq.com\" TESTING_APT_URL=apttrial.datad0g.com TESTING_YUM_URL=yumtrial.datad0g.com DD_AGENT_DIST_CHANNEL=stable DD_DDOT_DIST_CHANNEL=beta DD_AGENT_MAJOR_VERSION=7 DD_AGENT_MINOR_VERSION=70.0~rc.6-1", "Install latest Agent 7")

	s.assertInstallScript()

	s.addExtraIntegration()

	s.uninstall()

	s.assertUninstall()

	s.purge()

	s.assertPurge()
}

func (s *installDDOTTestSuite) assertInstallScript() {
	s.linuxInstallerTestSuite.assertInstallScript(true)
	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert both datadog.yaml and otel-config.yaml configs are created")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, otelConfigFileName))

	// Check datadog.yaml configuration
	datadogConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))

	// Assert otelcollector.enabled is true
	otelcollectorConfig, exists := datadogConfig["otelcollector"].(map[any]any)
	assert.True(t, exists, "otelcollector should exist")
	assert.Equal(t, true, otelcollectorConfig["enabled"])

	// Check agent_ipc section
	agentIPCConfig, exists := datadogConfig["agent_ipc"].(map[any]any)
	assert.True(t, exists, "agent_ipc should exist")
	assert.Equal(t, 5009, agentIPCConfig["port"])
	assert.Equal(t, 60, agentIPCConfig["config_refresh_interval"])

	// Check otel-config.yaml configuration
	otelConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, otelConfigFileName))
	exportersConfig, exists := otelConfig["exporters"].(map[any]any)
	assert.True(t, exists, "exporters should exist")
	datadogExporterConfig, exists := exportersConfig["datadog"].(map[any]any)
	assert.True(t, exists, "datadog should exist")
	apiConfig, exists := datadogExporterConfig["api"].(map[any]any)
	assert.True(t, exists, "api should exist")
	assert.NotContains(t, apiConfig["key"], "${env:DD_API_KEY}")
	assert.Equal(t, apiConfig["site"], "datadoghq.com")
}

func (s *installDDOTTestSuite) assertUninstall() {
	s.linuxInstallerTestSuite.assertUninstall()
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert configs are there after uninstall")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, otelConfigFileName))
}

func (s *installDDOTTestSuite) assertPurge() {
	if s.shouldSkipPurge() {
		return
	}
	s.linuxInstallerTestSuite.assertPurge()
	t := s.T()
	vm := s.Env().RemoteHost
	t.Log("Assert configs are removed after purge")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, otelConfigFileName))
}
