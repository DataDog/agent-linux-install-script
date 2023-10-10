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
	// ACT
	s.T().Log("Install latest Agent 7")
	cmd := fmt.Sprintf("DD_AGENT_FLAVOR=%s DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=%s DD_SITE=\"datadoghq.com\" bash -c \"$(curl -L %s/%s)\"",
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
