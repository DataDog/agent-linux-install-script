package e2e

import (
	"fmt"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e"
	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e/client"
	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e/params"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v3"
)

type installFipsScriptTestSuite struct {
	linuxPlatformTestSuite
}

func TestInstallFipsScriptSuite(t *testing.T) {
	if flavor != flavorDatadogAgent {
		t.Skip("install fips supported only on datadog-agent flavor")
	}
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
	t.Log("Install latest Agent 7 RC")
	cmd := fmt.Sprintf("DD_FIPS_MODE=true DD_URL=\"fake.url.com\" DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_SITE=\"darth.vador.com\" DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -L %s/%s)\"",
		flavor,
		apiKey,
		scriptURL,
		scriptAgent7)
	output := vm.Execute(cmd)
	// ASSERT
	assertInstallScript(t, vm)
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
	assert.Equal(t, true, fipsConfig["enabled"])
	assert.Equal(t, 9803, fipsConfig["port_range_start"])
	assert.Equal(t, false, fipsConfig["https"])
	assert.Equal(t, apiKey, config["api_key"], "not matching api key in config")

	assert.NotContains(t, config, "site", "site modified in config")
	assert.NotContains(t, config, "dd_url", "dd_url modified in config")

	// ACT uninstall
	uninstall(t, vm)
	// ASSERT
	assertUninstall(t, vm)
	// ACT purge - only on APT
	purgeFips(t, vm)
	// ASSERT
	assertPurge(t, vm)
}

func purgeFips(t *testing.T, vm *client.VM) {
	// Remove installed binary
	if _, err := vm.ExecuteWithError("command -v apt"); err != nil {
		t.Log("Purge supported only with apt")
		return
	}
	t.Log("Purge")
	vm.Execute(fmt.Sprintf("sudo apt remove --purge -y %s datadog-fips-proxy", flavor))
}