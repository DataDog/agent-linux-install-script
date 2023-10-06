package e2e

import (
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/utils/e2e"

	commonos "github.com/DataDog/test-infra-definitions/components/os"
	"github.com/DataDog/test-infra-definitions/scenarios/aws/vm/ec2os"
	"github.com/DataDog/test-infra-definitions/scenarios/aws/vm/ec2params"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type agentFlavor string

func (af *agentFlavor) String() string {
	return string(*af)
}

func (af *agentFlavor) Set(value string) error {
	if len(*af) > 0 {
		return fmt.Errorf("flavor flag already set to %s while trying to set to %s", *af, value)
	}
	fmt.Printf("Setting flavor flag to %s\n", value)
	*af = agentFlavor(value)
	return nil
}

const (
	scriptURL    = "https://dd-agent.s3.amazonaws.com/custom"
	scriptAgent7 = "install_script_agent7.sh"
	scriptAgent6 = "install_script_agent6.sh"

	flavorDatadogAgent     agentFlavor = "datadog-agent"
	flavorDatadogIOTAgent  agentFlavor = "datadog-iot-agent"
	flavorDatadogDogstatsd agentFlavor = "datadog-dogstatsd"
)

type osUnderTest struct {
	id     string
	name   string
	ami    string
	osType ec2os.Type
}

var (
	baseName = map[agentFlavor]string{
		"datadog-agent":     "datadog-agent",
		"datadog-dogstatsd": "datadog-dogstatsd",
		"datadog-iot-agent": "datadog-agent",
	}

	configFile = map[agentFlavor]string{
		"datadog-agent":     "datadog.yaml",
		"datadog-dogstatsd": "dogstatsd.yaml",
		"datadog-iot-agent": "datadog.yaml",
	}

	supportedOSMap = map[string]osUnderTest{
		"Debian_11":         {id: "Debian_11", name: "Debian 11", osType: ec2os.DebianOS},
		"Ubuntu_22.04":      {id: "Ubuntu_22_04", name: "Ubuntu 22.04", osType: ec2os.UbuntuOS},
		"RedHat_CentOS_7":   {id: "RedHat_CentOS_7", name: "RedHat / CentOS 7", osType: ec2os.CentOS},
		"RedHat_8":          {id: "RedHat_8", name: "RedHat 8", osType: ec2os.RedHatOS, ami: "ami-06640050dc3f556bb"},
		"Amazon_Linux_2023": {id: "Amazon_Linux_2023", name: "Amazon Linux 2023", osType: ec2os.AmazonLinuxOS, ami: "ami-0889a44b331db0194"},
		"openSUSE_15":       {id: "openSUSE / SLES 15", osType: ec2os.SuseOS},
	}

	flavors = map[string]struct{}{
		string(flavorDatadogAgent):     {},
		string(flavorDatadogIOTAgent):  {},
		string(flavorDatadogDogstatsd): {},
	}

	flavor         agentFlavor
	skipFlush      bool
	apiKey         string
	targetPlatform string
)

type linuxPlatformTestSuite struct {
	e2e.Suite[e2e.VMEnv]
	ec2Options []ec2params.Option
}

func init() {
	flag.Var(&flavor, "flavor", fmt.Sprintf("defines agent install flavor, possible values are %v", flavors))
	flag.BoolVar(&skipFlush, "skipFlush", false, "To prevent eventual cleanup, to test install_script won't override existing configuration")
	flag.StringVar(&apiKey, "apiKey", os.Getenv("DD_API_KEY"), "Datadog API key")
	flag.StringVar(&targetPlatform, "targetPlatform", "Debian_11", fmt.Sprintf("defines the target platform, possible values are %v", supportedOSMap))
}

func (s *linuxPlatformTestSuite) SetupSuite() {
	require.NotEmpty(s.T(), apiKey, "empty api key")
	targetOS := supportedOSMap[targetPlatform]
	if len(targetOS.ami) == 0 {
		// use default AMI defined in test-infra-definitions
		s.ec2Options = append(s.ec2Options, ec2params.WithOS(targetOS.osType))
	} else {
		s.ec2Options = append(s.ec2Options, ec2params.WithImageName(targetOS.ami, commonos.AMD64Arch, targetOS.osType))
	}
	s.Suite.SetupSuite()
}

func (s *linuxPlatformTestSuite) assertInstallScript() {
	t := s.T()
	vm := s.Env().VM
	// check presence of the dd-agent user
	_, err := vm.ExecuteWithError("id dd-agent")
	assert.NoError(t, err, "user datadog-agent does not exist after install")
	// Check presence of the config file - the file is added by the install script, so this should always be okay
	// if the install succeeds
	_, err = vm.ExecuteWithError(fmt.Sprintf("stat /etc/%s/%s", baseName[flavor], configFile[flavor]))
	assert.NoError(t, err, fmt.Sprintf("config file /etc/%s/%s does not exist after install", baseName[flavor], configFile[flavor]))
	// Check presence and ownership of the config and main directories
	owner := strings.TrimSuffix(vm.Execute(fmt.Sprintf("stat -c \"%%U\" /etc/%s/", baseName[flavor])), "\n")
	assert.Equal(t, "dd-agent", owner, fmt.Sprintf("dd-agent does not own /etc/%s", baseName[flavor]))
	owner = strings.TrimSuffix(vm.Execute(fmt.Sprintf("stat -c \"%%U\" /opt/%s/", baseName[flavor])), "\n")
	assert.Equal(t, "dd-agent", owner, fmt.Sprintf("dd-agent does not own /opt/%s", baseName[flavor]))
	// Check that the service is active
	if _, err = vm.ExecuteWithError("command -v systemctl"); err == nil {
		_, err = vm.ExecuteWithError(fmt.Sprintf("systemctl is-active %s", baseName[flavor]))
		assert.NoError(t, err, fmt.Sprintf("%s not running after Agent install", baseName[flavor]))
	} else if _, err = vm.ExecuteWithError("command -v initctl"); err == nil {
		status := strings.TrimSuffix(vm.Execute(fmt.Sprintf("sudo status %s", baseName[flavor])), "\n")
		assert.Contains(t, "running", status, fmt.Sprintf("%s not running after Agent install", baseName[flavor]))
	} else {
		assert.FailNow(t, "Unknown service manager")
	}

	if flavor == "datadog-agent" {
		// Install an extra integration, and create a custom file
		_, err = vm.ExecuteWithError("sudo -u dd-agent -- datadog-agent integration install -t datadog-bind9==0.1.0")
		assert.NoError(t, err, "integration install failed")
		_ = vm.Execute(fmt.Sprintf("sudo -u dd-agent -- touch /opt/%s/embedded/lib/python3.9/site-packages/testfile", baseName[flavor]))
	}

	// Remove installed binary
	if _, err = vm.ExecuteWithError("command -v apt"); err == nil {
		vm.Execute(fmt.Sprintf("sudo apt remove -y %s", flavor))
		//	# dd-agent user and config file should still be here
		_, err = vm.ExecuteWithError("id dd-agent")
		assert.NoError(t, err, "user datadog-agent not present after apt remove")
		_, err = vm.ExecuteWithError(fmt.Sprintf("stat /etc/%s/%s", baseName[flavor], configFile[flavor]))
		assert.NoError(t, err, fmt.Sprintf("/etc/%s/%s absent after apt remove", baseName[flavor], configFile[flavor]))
		if flavor == "datadog-agent" {
			//	   The custom file should still be here. All other files, including the extre integration, should be removed
			_, err = vm.ExecuteWithError("stat /opt/datadog-agent/embedded/lib/python3.9/site-packages/testfile")
			assert.NoError(t, err, "testfile absent after apt remove")
			files := strings.Split(strings.TrimSuffix(vm.Execute("find /opt/datadog-agent -type f"), "\n"), "\n")
			assert.Len(t, files, 1, fmt.Sprintf("/opt/datadog-agent present after apt remove, found %v", files))
		} else {
			// All files in /opt/datadog-agent should be removed
			_, err = vm.ExecuteWithError(fmt.Sprintf("stat /opt/%s", baseName[flavor]))
			assert.Error(t, err, fmt.Sprintf("/opt/%s present after apt remove", baseName[flavor]))
		}
		if !skipFlush {
			// Purge package
			vm.Execute(fmt.Sprintf("sudo apt remove --purge -y %s", flavor))
			_, err = vm.ExecuteWithError("id datadog-agent")
			assert.Error(t, err, "dd-agent present after apt purge")
			_, err = vm.ExecuteWithError(fmt.Sprintf("stat /etc/%s", baseName[flavor]))
			assert.Error(t, err, fmt.Sprintf("stat /etc/%sdd-agent present after apt purge", baseName[flavor]))
			_, err = vm.ExecuteWithError(fmt.Sprintf("stat /opt/%s", baseName[flavor]))
			assert.Error(t, err, fmt.Sprintf("stat /opt/%sdd-agent present after apt purge", baseName[flavor]))
		}
	} else if _, err = vm.ExecuteWithError("command -v yum"); err == nil {
		vm.Execute(fmt.Sprintf("sudo yum remove -y %s", flavor))
		//	# dd-agent user and config file should still be here
		_, err = vm.ExecuteWithError("id dd-agent")
		assert.NoError(t, err, "user datadog-agent not present after yum remove")
		_, err = vm.ExecuteWithError(fmt.Sprintf("stat /etc/%s/%s", baseName[flavor], configFile[flavor]))
		assert.NoError(t, err, fmt.Sprintf("/etc/%s/%s absent after yum remove", baseName[flavor], configFile[flavor]))
		if flavor == "datadog-agent" {
			//	   The custom file should still be here. All other files, including the extre integration, should be removed
			_, err = vm.ExecuteWithError("stat /opt/datadog-agent/embedded/lib/python3.9/site-packages/testfile")
			assert.NoError(t, err, "testfile absent after apt remove")
			files := strings.Split(strings.TrimSuffix(vm.Execute("find /opt/datadog-agent -type f"), "\n"), "\n")
			assert.Len(t, files, 1, fmt.Sprintf("/opt/datadog-agent present after apt remove, found %v", files))
		} else {
			// All files in /opt/datadog-agent should be removed
			_, err = vm.ExecuteWithError(fmt.Sprintf("stat /opt/%s", baseName[flavor]))
			assert.Error(t, err, fmt.Sprintf("/opt/%s present after apt remove", baseName[flavor]))
		}
	} else if _, err = vm.ExecuteWithError("command -v zypper"); err == nil {
		vm.Execute(fmt.Sprintf("sudo zypper remove -y %s", flavor))
		//	# dd-agent user and config file should still be here
		_, err = vm.ExecuteWithError("id dd-agent")
		assert.NoError(t, err, "user datadog-agent not present after yum remove")
		_, err = vm.ExecuteWithError(fmt.Sprintf("stat /etc/%s/%s", baseName[flavor], configFile[flavor]))
		assert.NoError(t, err, fmt.Sprintf("/etc/%s/%s absent after yum remove", baseName[flavor], configFile[flavor]))
		if flavor == "datadog-agent" {
			//	   The custom file should still be here. All other files, including the extre integration, should be removed
			_, err = vm.ExecuteWithError("stat /opt/datadog-agent/embedded/lib/python3.9/site-packages/testfile")
			assert.NoError(t, err, "testfile absent after apt remove")
			files := strings.Split(strings.TrimSuffix(vm.Execute("find /opt/datadog-agent -type f"), "\n"), "\n")
			assert.Len(t, files, 1, fmt.Sprintf("/opt/datadog-agent present after apt remove, found %v", files))
		} else {
			// All files in /opt/datadog-agent should be removed
			_, err = vm.ExecuteWithError(fmt.Sprintf("stat /opt/%s", baseName[flavor]))
			assert.Error(t, err, fmt.Sprintf("/opt/%s present after apt remove", baseName[flavor]))
		}
	} else {
		assert.FailNow(t, "Unknown package manager")
	}
}
