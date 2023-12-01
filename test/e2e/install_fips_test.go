// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.

package e2e

import (
	"fmt"
	"regexp"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e"
	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e/params"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type installFipsTestSuite struct {
	linuxInstallerTestSuite
}

func TestInstallFipsSuite(t *testing.T) {
	if flavor != agentFlavorDatadogAgent {
		t.Skip("fips test supports only datadog-agent flavor")
	}
	stackName := fmt.Sprintf("install-fips-%s-%s", flavor, platform)
	t.Run(stackName, func(t *testing.T) {
		t.Logf("We will install with fips %s with install script on %s", flavor, platform)
		testSuite := &installFipsTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(getEC2Options(t)...),
			params.WithStackName(stackName),
		)
	})
}

func (s *installFipsTestSuite) TestInstallFips() {
	t := s.T()
	vm := s.Env().VM
	t.Log("Install latest Agent 7 RC")
	cmd := fmt.Sprintf("DD_FIPS_MODE=true DD_URL=\"fake.url.com\" DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_SITE=\"darth.vador.com\" DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(cat scripts/install_script_agent7.sh)\"",
		flavor,
		apiKey)
	output := vm.Execute(cmd)
	t.Log(output)

	s.assertInstallFips(output)
	s.addExtraIntegration()
	s.uninstall()
	s.assertUninstall()
	s.purgeFips()
	s.assertPurge()
}

func (s *installFipsTestSuite) assertInstallFips(installCommandOutput string) {
	t := s.T()
	vm := s.Env().VM

	s.assertInstallScript()

	t.Log("assert install output contains expected lines")
	matched, err := regexp.MatchString(`Installing\ package\(s\):\ .*\ datadog-fips-proxy.*`, installCommandOutput)
	require.NoError(t, err, "error matching installer output for datadog-fips-proxy package")
	assert.True(t, matched, "Missing installer log line for installing package(s)")
	assert.Contains(t, installCommandOutput, "* Adding your API key to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml", "Missing installer log line for API key")
	assert.Contains(t, installCommandOutput, "* Setting Datadog Agent configuration to use FIPS proxy: /etc/datadog-agent/datadog.yaml", "Missing installer log line for FIPS proxy")

	t.Log("assert agent configuration contains expected properties")
	config := unmarshalConfigFile(t, vm, fmt.Sprintf("etc/%s/%s", s.baseName, s.configFile))
	assert.Contains(t, config, "fips")
	fipsConfig, ok := config["fips"].(map[any]any)
	assert.True(t, ok, fmt.Sprintf("failed parsing config[fips] to map \n%v\n\n", config["fips"]))
	assert.Equal(t, true, fipsConfig["enabled"], fmt.Sprintf("fips config enabled should be true, content:\n%v\n\n", fipsConfig))
	assert.Equal(t, 9803, fipsConfig["port_range_start"], fmt.Sprintf("fips config port_range_start should be 9803, content:\n%v\n\n", fipsConfig))
	assert.Equal(t, false, fipsConfig["https"], fmt.Sprintf("fips config https should be false, content:\n%v\n\n", fipsConfig))
	assert.Equal(t, apiKey, config["api_key"], fmt.Sprintf("not matching api key in config, content:\n%v\n\n", fipsConfig))
	assert.NotContains(t, config, "site", fmt.Sprintf("site modified in config, content:\n%v\n\n", fipsConfig))
	assert.NotContains(t, config, "dd_url", fmt.Sprintf("dd_url modified in config, content:\n%v\n\n", fipsConfig))

	assertFileExists(t, vm, fipsConfigFilepath)
}

func (s *installFipsTestSuite) purgeFips() {
	t := s.T()
	vm := s.Env().VM
	// Remove installed binary
	if _, err := vm.ExecuteWithError("command -v apt"); err != nil {
		t.Log("Purge supported only with apt")
		return
	}
	t.Log("Purge")
	vm.Execute(fmt.Sprintf("sudo apt remove --purge -y %s datadog-fips-proxy", flavor))
}
