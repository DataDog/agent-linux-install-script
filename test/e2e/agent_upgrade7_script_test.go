package e2e

import (
	"fmt"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e"
	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e/params"
)

type upgrade7ScriptTestSuite struct {
	linuxPlatformTestSuite
}

func TestUpgrade7ScriptSuite(t *testing.T) {
	t.Run(fmt.Sprintf("upgrade7-%s-%s", flavor, targetPlatform), func(t *testing.T) {
		testSuite := &upgrade7ScriptTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(testSuite.ec2Options...),
			params.WithStackName(fmt.Sprintf("upgrade7-%s-%s", flavor, targetPlatform)),
		)
	})
}

func (s *upgrade7ScriptTestSuite) TestUpgrade7Script() {
	t := s.T()
	vm := s.Env().VM
	t.Log("Install latest Agent 7")
	cmd := fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s bash -c \"$(curl -L %s/%s)\"",
		flavor,
		apiKey,
		scriptURL,
		scriptAgent7)
	vm.Execute(cmd)
	t.Log("Install latest Agent RC")
	cmd = fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -L %s/%s)\"",
		flavor,
		apiKey,
		scriptAgent6,
		scriptURL)
	vm.Execute(cmd)
	assertInstallScript(t, vm)
	uninstall(t, vm)
	assertUninstall(t, vm)
	purge(t, vm)
	assertPurge(t, vm)
}
