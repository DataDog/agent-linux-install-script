package e2e

import (
	"fmt"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e"
	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e/params"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v3"
)

type installFipsScriptTestSuite struct {
	linuxPlatformTestSuite
}

func TestInstallFipsScriptSuite(t *testing.T) {
	t.Run(fmt.Sprintf("install script with fips on flavor %s on platform %s", flavor, targetPlatform), func(t *testing.T) {
		testSuite := &installFipsScriptTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(testSuite.ec2Options...),
			params.WithStackName(fmt.Sprintf("install-fips-%s-%s", flavor, targetPlatform)),
		)
	})
}

func (s *installFipsScriptTestSuite) TestInstallFipsScript() {
	// ACT
	t := s.T()
	vm := s.Env().VM
	t.Log("Install latest Agent 7")
	cmd := fmt.Sprintf("DD_FIPS_MODE=true DD_URL=\"fake.url.com\" DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_SITE=\"darth.vador.com\" bash -c \"$(curl -L %s/%s)\"",
		flavor,
		apiKey,
		scriptURL,
		scriptAgent7)
	output := vm.Execute(cmd)
	// ASSERT
	s.assertInstallScript()
	assert.Contains(t, output, "Installing package(s): datadog-agent datadog-signing-keys datadog-fips-proxy", "Missing installer log line for installing package(s)")
	assert.Contains(t, output, "* Adding your API key to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml", "Missing installer log line for API key")
	assert.Contains(t, output, "* Setting Datadog Agent configuration to use FIPS proxy: /etc/datadog-agent/datadog.yaml", "Missing installer log line for FIPS proxy")

	configContent := vm.Execute(fmt.Sprintf("sudo cat /etc/%s/%s", baseName[flavor], configFile[flavor]))
	var config map[string]any
	err := yaml.Unmarshal([]byte(configContent), &config)
	require.NoError(t, err, fmt.Sprintf("unexpected error on yaml parse %v", err))
	assert.Contains(t, config, "fips")
	fipsConfig, ok := config["fips"].(map[string]any)
	assert.True(t, ok)
	assert.Equal(t, true, fipsConfig["enabled"].(bool))
	assert.Equal(t, 9803, fipsConfig["port_range_start"].(int))
	assert.Equal(t, false, fipsConfig["https"].(bool))
	assert.Contains(t, config, "api_key")
	apiConfig, ok := config["api_key"].(string)
	assert.True(t, ok)
	assert.Equal(t, apiKey, apiConfig, "not matching api key in config")

	assert.NotContains(t, config, "site", "site modified in config")
	assert.NotContains(t, config, "dd_url", "dd_url modified in config")

	// ACT uninstall
	s.uninstall()
	// ASSERT
	s.assertUninstall()
	// ACT purge - only on APT
	s.purgeFips()
	// ASSERT
	s.assertPurge()
}

func (s *installFipsScriptTestSuite) purgeFips() {
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
