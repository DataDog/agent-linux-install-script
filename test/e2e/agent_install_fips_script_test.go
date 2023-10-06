package e2e

import (
	"fmt"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e"
	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e/params"
	"github.com/stretchr/testify/assert"
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
			params.WithDevMode(),
		)
	})
}

func (s *installFipsScriptTestSuite) TestInstallFipsScript() {
	// ACT
	s.T().Log("Install latest Agent 7")
	cmd := fmt.Sprintf("DD_FIPS_MODE=true DD_REPO_URL=\"fake.url.com\" DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_SITE=\"darth.vador.com\" bash -c \"$(curl -L %s/%s)\"",
		flavor,
		apiKey,
		scriptURL,
		scriptAgent7)
	output := s.Env().VM.Execute(cmd)
	assert.Contains(s.T(), output, `Installing package(s): datadog-agent datadog-signing-keys datadog-fips-proxy
* Adding your API key to the Datadog Agent configuration: /etc/datadog-agent/datadog.yaml
* Setting Datadog Agent configuration to use FIPS proxy: /etc/datadog-agent/datadog.yaml`, fmt.Sprintf("unexpected install outoput %s", output))
	// ASSERT
	skipFlush = true
	s.assertInstallScript()
	configContent := s.Env().VM.Execute(fmt.Sprintf("cat /etc/%s/%s", baseName[flavor], configFile[flavor]))
	assert.Equal(s.T(), `# Configuration for the agent to use datadog-fips-proxy to communicate with Datadog via FIPS-compliant channel.

	fips:
			enabled: true
			port_range_start: 9803
			https: false
	# site: datadoghq.com
	# dd_url: https://app.datadoghq.com`, configContent)
}
