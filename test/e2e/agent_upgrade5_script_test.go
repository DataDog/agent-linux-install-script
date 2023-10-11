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
	t := s.T()
	vm := s.Env().VM
	require.NotEqual(t, "datadog-agent", flavor, fmt.Sprintf("%s not supported on Agent 5", flavor))
	t.Log("Install latest Agent 5")
	// "Install latest Agent 5"
	cmd := fmt.Sprintf("DD_API_KEY=%s bash -c \"$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)\"", apiKey)
	vm.Execute(cmd)
	t.Log("Install latest Agent 7 RC")
	cmd = fmt.Sprintf("DD_REPO_URL=datad0g.com DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_UPGRADE=true DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -L %s/%s)\"",
		flavor,
		apiKey,
		scriptURL,
		scriptAgent7)
	vm.Execute(cmd)
	// ASSERT
	assertInstallScript(t, vm)
	// ACT uninstall
	uninstall(t, vm)
	// ASSERT
	assertUninstall(t, vm)
	// ACT purge - only on APT
	purge(t, vm)
	// ASSERT
	assertPurge(t, vm)
}