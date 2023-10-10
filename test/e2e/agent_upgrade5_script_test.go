package e2e

import (
	"fmt"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e"
	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e/params"
	"github.com/stretchr/testify/require"
)

type upgrade5ScriptTestSuite struct {
	linuxPlatformTestSuite
}

func TestUpgrade5ScriptSuite(t *testing.T) {
	t.Run(fmt.Sprintf("upgrade5-%s-%s", flavor, targetPlatform), func(t *testing.T) {
		testSuite := &upgrade5ScriptTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(testSuite.ec2Options...),
			params.WithStackName(fmt.Sprintf("upgrade5-%s-%s", flavor, targetPlatform)),
		)
	})
}

func (s *upgrade5ScriptTestSuite) TestUpgrade5Script() {
	require.NotEqual(s.T(), "datadog-agent", flavor, fmt.Sprintf("%s not supported on Agent 5", flavor))
	s.T().Log("Install latest Agent 5")
	// "Install latest Agent 5"
	cmd := fmt.Sprintf("DD_API_KEY=%s bash -c \"$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)\"", apiKey)
	s.Env().VM.Execute(cmd)
	s.T().Log("Install latest Agent 7")
	cmd = fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_SITE=\"datadoghq.com\" bash -c \"$(curl -L %s/%s)\"",
		flavor,
		apiKey,
		scriptURL,
		scriptAgent7)
	s.Env().VM.Execute(cmd)
	// ASSERT
	s.assertInstallScript()
	// ACT uninstall
	s.uninstall()
	// ASSERT
	s.assertUninstall()
	// ACT purge - only on APT
	s.purge()
	// ASSERT
	s.assertPurge()
}
