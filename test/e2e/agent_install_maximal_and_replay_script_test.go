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

type installMaximalAndReplayScriptTestSuite struct {
	linuxPlatformTestSuite
}

func TestInstallMaximalAndReplayScriptSuite(t *testing.T) {
	if flavor != flavorDatadogAgent {
		t.Skip("install maximal and replay supported only on datadog-agent flavor")
	}
	t.Run(fmt.Sprintf("install script with maximal and replay on flavor %s on platform %s", flavor, targetPlatform), func(t *testing.T) {
		testSuite := &installMaximalAndReplayScriptTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(testSuite.ec2Options...),
			params.WithStackName(fmt.Sprintf("install-maximal-replay-%s-%s", flavor, targetPlatform)),
		)
	})
}

func (s *installMaximalAndReplayScriptTestSuite) TestInstallMaximalAndReplayScript() {
	t := s.T()
	vm := s.Env().VM
	var output string
	t.Run("should install latest Agent 7 RC", func(tt *testing.T) {
		cmd := fmt.Sprintf("DD_HOST_TAGS=\"foo:bar,baz:toto\" DD_ENV=kiki DD_HOSTNAME=totoro DD_RUNTIME_SECURITY_CONFIG_ENABLED=true DD_COMPLIANCE_CONFIG_ENABLED=true DD_AGENT_FLAVOR=%s DD_API_KEY=%s DD_SITE=\"mysite.com\" DD_URL=myintake.com DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -L %s/%s)\"",
			flavor,
			apiKey,
			scriptURL,
			scriptAgent7)
		output = vm.Execute(cmd)
	})

	t.Run("install output should contain configuration changes", func(tt *testing.T) {
		expectedInstallLogLines := []string{
			"* Adding your API key to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
			"* Setting SITE in the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
			"* Setting DD_URL in the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
			"* Adding your HOSTNAME to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
			"* Adding your HOST TAGS to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
			"* Adding your DD_ENV to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
			"* Enabling compliance monitoring in configuration",
			"* Enabling runtime security in configuration",
		}

		for _, line := range expectedInstallLogLines {
			assert.Contains(tt, output, line)
		}
	})

	t.Run("should respect generic install assertions", func(tt *testing.T) {
		assertInstallScript(tt, vm)
	})

	t.Run("should update configurations", func(tt *testing.T) {
		assertMaximalConfiguration(tt, vm)
	})

	t.Run("should call Agent 7 RC installer again with new env variables", func(tt *testing.T) {
		cmd := fmt.Sprintf("DD_HOST_TAGS=\"john:doe,john:lennon\" DD_ENV=totoro DD_HOSTNAME=kiki DD_RUNTIME_SECURITY_CONFIG_ENABLED=true DD_COMPLIANCE_CONFIG_ENABLED=true DD_AGENT_FLAVOR=%s DD_API_KEY=%s DD_SITE=darthmaul.com DD_URL=otherintake.com DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -L %s/%s)\"",
			flavor,
			apiKey,
			scriptURL,
			scriptAgent7)
		output = vm.Execute(cmd)
	})

	t.Run("install output should not contain configuration changes", func(tt *testing.T) {
		expectedInstallLogLines := []string{
			"* Adding your API key to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
			"* Setting SITE in the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
			"* Setting DD_URL in the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
			"* Adding your HOSTNAME to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
			"* Adding your HOST TAGS to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
			"* Adding your DD_ENV to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml",
			"* Enabling compliance monitoring in configuration",
			"* Enabling runtime security in configuration",
		}

		for _, line := range expectedInstallLogLines {
			assert.NotContains(tt, output, line)
		}

		assert.Contains(tt, output, "* Keeping old /etc/datadog-agent/datadog.yaml configuration file")
	})

	t.Run("should keep old configurations", func(tt *testing.T) {
		assertMaximalConfiguration(tt, vm)
	})

	t.Run("should uninstall", func(tt *testing.T) {
		uninstall(tt, vm)
	})
	t.Run("should respect generic uninstall assertions", func(tt *testing.T) {
		assertUninstall(tt, vm)
	})
	t.Run("should purge", func(tt *testing.T) {
		purge(tt, vm)
	})
	t.Run("should assert purge", func(tt *testing.T) {
		assertPurge(tt, vm)
	})
}

func assertMaximalConfiguration(t *testing.T, vm *client.VM) {
	configContent := vm.Execute(fmt.Sprintf("sudo cat /etc/%s/%s", baseName[flavor], configFile[flavor]))
	var config map[string]any
	err := yaml.Unmarshal([]byte(configContent), &config)
	require.NoError(t, err, fmt.Sprintf("unexpected error on yaml parse %v", err))
	assert.Equal(t, apiKey, config["api_key"], "not matching api key in config")
	assert.Equal(t, "mysite.com", config["site"])
	assert.Equal(t, "myintake.com", config["dd_url"])
	assert.Equal(t, "totoro", config["hostname"])
	assert.Equal(t, []any{"foo:bar", "baz:toto"}, config["tags"].([]any))
	assert.Equal(t, "kiki", config["env"])

	securityAgentConfigContent := vm.Execute(fmt.Sprintf("sudo cat /etc/%s/security-agent.yaml", baseName[flavor]))
	var securityAgentConfig map[string]any
	err = yaml.Unmarshal([]byte(securityAgentConfigContent), &securityAgentConfig)
	require.NoError(t, err, fmt.Sprintf("unexpected error on yaml parse %v", err))
	assert.Equal(t, true, securityAgentConfig["runtime_security_config"].(map[string]any)["enabled"])
	assert.Equal(t, true, securityAgentConfig["compliance_config"].(map[string]any)["enabled"])

	systemProbeConfigContent := vm.Execute(fmt.Sprintf("sudo cat /etc/%s/system-probe.yaml", baseName[flavor]))
	var systemProbeConfig map[string]any
	err = yaml.Unmarshal([]byte(systemProbeConfigContent), &systemProbeConfig)
	require.NoError(t, err, fmt.Sprintf("unexpected error on yaml parse %v", err))
	assert.Equal(t, true, securityAgentConfig["runtime_security_config"].(map[string]any)["enabled"])
}
