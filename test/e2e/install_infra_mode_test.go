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

type installInfraModeTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallInfraModeSuite(t *testing.T) {
	stackName := fmt.Sprintf("install-%s-%s-%s", flavor, platform, getenv("CI_PIPELINE_ID", "dev"))
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install %s with install_script on %s", flavor, platform)
		testSuite := &installInfraModeTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.WithProvisioner(awshost.ProvisionerNoAgentNoFakeIntake(awshost.WithEC2InstanceOptions(getEC2Options(t)...))),
			e2e.WithStackName(stackName),
		)
	})
}

func (s *installInfraModeTestSuite) TestInstall() {
	s.InstallAgent(7, "DD_INFRASTRUCTURE_MODE=basic", "Install Agent 7 in basic infrastructure mode")
	s.assertInfraModeSet("basic")
	s.uninstall()
	s.assertUninstall()
	s.purge()
	s.assertPurge()
}

func (s *installInfraModeTestSuite) assertInfraModeSet(mode string) {
	t := s.T()
	vm := s.Env().RemoteHost

	t.Log("Assert datadog.yaml config is created")
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))

	// Check datadog.yaml configuration
	datadogConfig := unmarshalConfigFile(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))

	// Assert infrastructure_mode is set to the correct mode
	assert.Equal(t, mode, datadogConfig["infrastructure_mode"])
}
