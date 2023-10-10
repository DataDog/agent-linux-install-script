package e2e

import (
	"fmt"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e"
	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e/params"
)

type upgrade6ScriptTestSuite struct {
	linuxPlatformTestSuite
}

func TestUpgrade6ScriptSuite(t *testing.T) {
	t.Run(fmt.Sprintf("upgrade6-%s-%s", flavor, targetPlatform), func(t *testing.T) {
		testSuite := &upgrade6ScriptTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(testSuite.ec2Options...),
			params.WithStackName(fmt.Sprintf("upgrade6-%s-%s", flavor, targetPlatform)),
		)
	})
}

func (s *upgrade6ScriptTestSuite) TestUpgrade6Script() {
	// ACT
	s.T().Log("Install latest Agent 6")
	cmd := fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=6 DD_API_KEY=%s bash -c \"$(curl -L %s/%s)\"",
		flavor,
		apiKey,
		scriptURL,
		scriptAgent6)
	s.Env().VM.Execute(cmd)
	s.T().Log("Install latest Agent 7 RC")
	cmd = fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -L %s/%s)\"",
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
