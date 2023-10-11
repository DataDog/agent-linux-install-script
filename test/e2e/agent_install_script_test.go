package e2e

import (
	"fmt"
	"testing"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e"
	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e/params"
)

type installScriptTestSuite struct {
	linuxPlatformTestSuite
}

func TestInstallScriptSuite(t *testing.T) {
	t.Run(fmt.Sprintf("install script on flavor %s on platform %s", flavor, targetPlatform), func(t *testing.T) {
		testSuite := &installScriptTestSuite{}
		e2e.Run(t,
			testSuite,
			e2e.EC2VMStackDef(testSuite.ec2Options...),
			params.WithStackName(fmt.Sprintf("install-%s-%s", flavor, targetPlatform)),
		)
	})
}

func (s *installScriptTestSuite) TestInstallScript() {
	t := s.T()
	vm := s.Env().VM
	s.T().Log("Install latest Agent 7 RC")
	cmd := fmt.Sprintf("DD_REPO_URL=datad0g.com DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_SITE=\"datadoghq.com\" DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c \"$(curl -L %s/%s)\"",
		flavor,
		apiKey,
		scriptURL,
		scriptAgent7)
	s.Env().VM.Execute(cmd)
	assertInstallScript(t, vm)
	uninstall(t, vm)
	assertUninstall(t, vm)
	purge(t, vm)
	assertPurge(t, vm)
}