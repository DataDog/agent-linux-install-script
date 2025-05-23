// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.

package e2e

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/components"
	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/e2e"
	"github.com/DataDog/datadog-agent/test/new-e2e/pkg/environments"
	componentsos "github.com/DataDog/test-infra-definitions/components/os"
	"github.com/DataDog/test-infra-definitions/scenarios/aws/ec2"

	envparse "github.com/hashicorp/go-envparse"
	version "github.com/hashicorp/go-version"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	yaml "gopkg.in/yaml.v2"
)

type osConfig struct {
	ami          string
	osDescriptor componentsos.Descriptor
}

const (
	defaultAgentFlavor          agentFlavor = agentFlavorDatadogAgent
	defaultPlatform                         = "Ubuntu_22_04"
	defaultMode                             = "install"
	fipsConfigFilepath                      = "/etc/datadog-fips-proxy/datadog-fips-proxy.cfg"
	systemProbeConfigFileName               = "system-probe.yaml"
	securityAgentConfigFileName             = "security-agent.yaml"
)

var (
	// flags
	flavor     agentFlavor // datadog-agent, datadog-iot-agent, datadog-dogstatsd
	apiKey     string      // Needs to be valid, at least for the upgrade5 scenario
	scriptPath string      // Absolute path to the generated install scripts
	noFlush    bool        // To prevent eventual cleanup, to test install_script won't override existing configuration
	platform   string      // Platform under test

	baseNameByFlavor = map[agentFlavor]string{
		agentFlavorDatadogAgent:     "datadog-agent",
		agentFlavorDatadogDogstatsd: "datadog-dogstatsd",
		agentFlavorDatadogIOTAgent:  "datadog-agent",
	}
	configFileByFlavor = map[agentFlavor]string{
		agentFlavorDatadogAgent:     "datadog.yaml",
		agentFlavorDatadogDogstatsd: "dogstatsd.yaml",
		agentFlavorDatadogIOTAgent:  "datadog.yaml",
	}
	envFile            = "/etc/environment"
	osConfigByPlatform = map[string]osConfig{
		"Debian_11":         {osDescriptor: componentsos.NewDescriptor(componentsos.Debian, "11")},
		"Ubuntu_22_04":      {osDescriptor: componentsos.UbuntuDefault},
		"RedHat_CentOS_7":   {osDescriptor: componentsos.NewDescriptor(componentsos.CentOS, "7")},
		"RedHat_8":          {osDescriptor: componentsos.NewDescriptor(componentsos.RedHat, "8"), ami: "ami-06640050dc3f556bb"},
		"Amazon_Linux_2023": {osDescriptor: componentsos.AmazonLinux2, ami: "ami-0889a44b331db0194"},
		"openSUSE_15":       {osDescriptor: componentsos.SuseDefault},
	}
)

// note: no need to call flag.Parse() on test code, go test does it
func init() {
	flag.Var(&flavor, "flavor", "defines agent install flavor, supported values are [datadog-agent, datadog-iot-agent, datadog-dogstatsd]")
	flag.BoolVar(&noFlush, "noFlush", false, "To prevent eventual cleanup, to test install_script won't override existing configuration")
	flag.StringVar(&apiKey, "apiKey", os.Getenv("DD_API_KEY"), "Datadog API key")
	flag.StringVar(&scriptPath, "scriptPath", "", "Absolute path to the generated install scripts")
	flag.StringVar(&platform, "platform", defaultPlatform, fmt.Sprintf("Defines the target platform, default %s", defaultPlatform))
}

func getenv(key, fallback string) string {
	value := os.Getenv(key)
	if len(value) == 0 && len(fallback) != 0 {
		return fallback
	}
	return value
}

type linuxInstallerTestSuite struct {
	e2e.BaseSuite[environments.Host]
	baseName        string
	optPathOverride string
	configFile      string
}

func (s *linuxInstallerTestSuite) InstallAgent(agentVersion int, extraParam ...string) string {
	t := s.T()
	vm := s.Env().RemoteHost

	installationScriptPath := "scripts/install_agent.sh"
	scriptEnvVariable := fmt.Sprintf("DD_API_KEY=%s", apiKey)
	if agentVersion != 5 {
		scriptEnvVariable = scriptEnvVariable + fmt.Sprintf(" DD_AGENT_MAJOR_VERSION=%d DD_AGENT_FLAVOR=%s", agentVersion, flavor)
		installationScriptPath = "scripts/install_script_agent7.sh"
		if agentVersion == 6 {
			installationScriptPath = "scripts/install_script_agent6.sh"
		}
	}
	extraParamLength := len(extraParam)
	if extraParamLength == 0 {
		t.Logf("Install latest Agent %d", agentVersion)
	} else {
		scriptEnvVariable = scriptEnvVariable + " " + strings.Join(extraParam[:extraParamLength-1], " ")
		t.Log(extraParam[extraParamLength-1])
	}
	cmd := fmt.Sprintf("%s bash -c \"$(cat %s)\"", scriptEnvVariable, installationScriptPath)
	output := vm.MustExecute(cmd)
	t.Log(output)

	return output
}

// SetupSuite is called at suite initialisation, once before all tests
func (s *linuxInstallerTestSuite) SetupSuite() {
	s.BaseSuite.SetupSuite()
	t := s.T()
	fmt.Println("SetupSuite")
	if flavor == "" {
		t.Log("setting default agent flavor")
		flavor = defaultAgentFlavor
	}
	s.baseName = baseNameByFlavor[flavor]
	s.configFile = configFileByFlavor[flavor]
	fmt.Println("SetupSuite2")
	fmt.Printf("Copying scripts from %s to %s\n", scriptPath, s.Env().RemoteHost.Address)
	err := s.Env().RemoteHost.CopyFolder(scriptPath, "scripts")
	require.NoError(s.T(), err, "failed to copy scripts")
	fmt.Println("SetupSuite3")
}

func getEC2Options(t *testing.T) []ec2.VMOption {
	t.Helper()
	if _, ok := osConfigByPlatform[platform]; !ok {
		t.Skipf("not supported platform %s", platform)
	}

	ec2Options := []ec2.VMOption{}
	if osConfigByPlatform[platform].ami != "" {
		ec2Options = append(ec2Options, ec2.WithAMI(osConfigByPlatform[platform].ami, osConfigByPlatform[platform].osDescriptor, osConfigByPlatform[platform].osDescriptor.Architecture))
	} else {
		ec2Options = append(ec2Options, ec2.WithOS(osConfigByPlatform[platform].osDescriptor))
	}

	if instanceType, ok := os.LookupEnv("E2E_OVERRIDE_INSTANCE_TYPE"); ok {
		ec2Options = append(ec2Options, ec2.WithInstanceType(instanceType))
	}
	return ec2Options
}

func (s *linuxInstallerTestSuite) getLatestEmbeddedPythonPath(baseName string) string {
	s.T().Helper()
	vm := s.Env().RemoteHost
	cmd := fmt.Sprintf("echo /opt/%s/embedded/lib/python*", baseName)
	result, err := vm.Execute(cmd)
	require.NoError(s.T(), err, fmt.Sprintf("Python embedded libraries not found: %s", err))
	require.NotEmpty(s.T(), result)
	latest := ""
	var latestVersion *version.Version
	for _, match := range strings.Split(result, " ") {
		pythonVersion := strings.Split(match, "python")[1]
		pythonVersion = strings.ReplaceAll(pythonVersion, "\n", "")
		currentVers, versError := version.NewVersion(pythonVersion)
		if latest != "" {
			require.NoError(s.T(), versError, fmt.Sprintf("Invalid Python Version : %s", pythonVersion))
			if currentVers.GreaterThan(latestVersion) {
				latestVersion = currentVers
				latest = pythonVersion
			}
		} else {
			latest = pythonVersion
			latestVersion = currentVers
		}
	}
	latest = strings.ReplaceAll(latest, "\n", "")
	require.NotEmpty(s.T(), latest)
	stringOutput := fmt.Sprintf("/opt/%s/embedded/lib/python%s", baseName, latest)
	return stringOutput
}

func (s *linuxInstallerTestSuite) assertInstallScript(active bool) {
	t := s.T()
	vm := s.Env().RemoteHost
	t.Helper()
	t.Log("Check user, config file and service")
	// check presence of the dd-agent user
	_, err := vm.Execute("id dd-agent")
	assert.NoError(t, err, "user datadog-agent does not exist after install")
	// Check presence of the config file - the file is added by the install script, so this should always be okay
	// if the install succeeds
	assertFileExists(t, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))
	// Check presence and ownership of the config and main directories
	owner := strings.TrimSuffix(vm.MustExecute(fmt.Sprintf("stat -c \"%%U\" /etc/%s/", s.baseName)), "\n")
	assert.Equal(t, "dd-agent", owner, fmt.Sprintf("dd-agent does not own /etc/%s", s.baseName))

	owner = strings.TrimSuffix(vm.MustExecute(fmt.Sprintf("stat -c \"%%U\" /opt/%s/", s.baseName)), "\n")
	assert.Equal(t, "dd-agent", owner, fmt.Sprintf("dd-agent does not own /opt/%s", s.baseName))
	serviceNames := []string{s.baseName}
	if flavor == agentFlavorDatadogAgent {
		serviceNames = append(serviceNames, "datadog-agent-trace")
		// Cannot assert process-agent because it may be running or dead based on timing
	}
	// Check that the services are active
	if _, err = vm.Execute("command -v systemctl"); err == nil {
		for _, serviceName := range serviceNames {
			_, err = vm.Execute(fmt.Sprintf("systemctl is-active %s", serviceName))
			if active {
				assert.NoError(t, err, fmt.Sprintf("%s not running after Agent install", serviceName))
			} else {
				assert.Error(t, err, fmt.Sprintf("%s running after Agent install", serviceName))
			}
		}
	} else if _, err = vm.Execute("/sbin/init --version 2>&1 | grep -q upstart;"); err == nil {
		for _, serviceName := range serviceNames {
			status := strings.TrimSuffix(vm.MustExecute(fmt.Sprintf("sudo status %s", serviceName)), "\n")
			if active {
				assert.Contains(t, status, "running", fmt.Sprintf("%s not running after Agent install", serviceName))
			} else {
				assert.NotContains(t, status, "running", fmt.Sprintf("%s running after Agent install", serviceName))
			}
		}
	} else {
		require.FailNow(t, "Unknown service manager")
	}
	if t.Failed() {
		stdout, err := vm.Execute("sudo journalctl --no-pager")
		if err != nil {
			t.Logf("Failed to get journalctl logs: %s", err)
		} else {
			t.Logf("journalctl logs:\n%s", stdout)
		}
		stdout, err = vm.Execute("sudo systemctl status datadog*")
		if err != nil {
			t.Logf("Failed to get systemctl status: %s", err)
		} else {
			t.Logf("systemctl logs:\n%s", stdout)
		}
	}
}

func (s *linuxInstallerTestSuite) addExtraIntegration() {
	t := s.T()
	t.Helper()
	if flavor != "datadog-agent" {
		return
	}
	vm := s.Env().RemoteHost
	t.Log("Install an extra integration, and create a custom file")
	_, err := vm.Execute("sudo -u dd-agent -- datadog-agent integration install -t datadog-bind9==0.1.0")
	assert.NoError(t, err, "integration install failed")
	_ = vm.MustExecute(fmt.Sprintf("sudo -u dd-agent -- touch %s/site-packages/testfile", s.getLatestEmbeddedPythonPath(s.baseName)))
}

func (s *linuxInstallerTestSuite) uninstall() {
	t := s.T()
	vm := s.Env().RemoteHost
	t.Helper()
	t.Logf("Remove %s", flavor)
	if _, err := vm.Execute("command -v apt"); err == nil {
		t.Log("Uninstall with apt")
		vm.Execute(fmt.Sprintf("sudo apt remove -y %s", flavor))
	} else if _, err = vm.Execute("command -v yum"); err == nil {
		t.Log("Uninstall with yum")
		vm.Execute(fmt.Sprintf("sudo yum remove -y %s", flavor))
	} else if _, err = vm.Execute("command -v zypper"); err == nil {
		t.Log("Uninstall with zypper")
		vm.Execute(fmt.Sprintf("sudo zypper remove -y %s", flavor))
	} else {
		require.FailNow(t, "Unknown package manager")
	}
}

func (s *linuxInstallerTestSuite) assertUninstall() {
	t := s.T()
	vm := s.Env().RemoteHost
	t.Logf("Assert %s is removed", flavor)
	// dd-agent user and config file should still be here
	assert.EventuallyWithT(t, func(c *assert.CollectT) {
		_, err := vm.Execute("id dd-agent")
		assert.NoError(c, err, "user datadog-agent not present after remove")
		assertFileExists(c, vm, fmt.Sprintf("/etc/%s/%s", s.baseName, s.configFile))
		if flavor == "datadog-agent" {
			// The custom file should still be here. All other files, including the extra integration, should be removed
			expectedFile := fmt.Sprintf("%s/site-packages/testfile", s.getLatestEmbeddedPythonPath("datadog-agent"))
			assertFileExists(c, vm, expectedFile)
			files := strings.Split(strings.TrimSuffix(vm.MustExecute("find /opt/datadog-agent -type f"), "\n"), "\n")
			assert.Len(c, files, 1, fmt.Sprintf("/opt/datadog-agent present after remove, found %v, expected only %s", files, expectedFile))
		} else {
			// All files in /opt/datadog-agent should be removed
			assertFileNotExists(c, vm, fmt.Sprintf("/opt/%s", s.baseName))
		}
	}, 10*time.Second, time.Second)
	if t.Failed() {
		stdout, err := vm.Execute("journalctl --no-pager")
		if err != nil {
			t.Logf("Failed to get journalctl logs: %s", err)
		} else {
			t.Logf("journalctl logs:\n%s", stdout)
		}
	}
}

func (s *linuxInstallerTestSuite) purge() {
	t := s.T()
	t.Helper()

	if s.shouldSkipPurge() {
		return
	}

	vm := s.Env().RemoteHost

	t.Log("Purge package")
	vm.Execute(fmt.Sprintf("sudo apt remove --purge -y %s", flavor))
}

func (s *linuxInstallerTestSuite) shouldSkipPurge() bool {
	t := s.T()
	vm := s.Env().RemoteHost
	t.Helper()
	if noFlush {
		return true
	}
	if _, err := vm.Execute("command -v apt"); err != nil {
		return true
	}
	return false
}

func (s *linuxInstallerTestSuite) assertPurge() {
	t := s.T()
	t.Helper()

	if s.shouldSkipPurge() {
		return
	}

	vm := s.Env().RemoteHost

	t.Log("Assert purge package")
	_, err := vm.Execute("id datadog-agent")
	assert.Error(t, err, "dd-agent present after %s purge")
	assertFileNotExists(t, vm, fmt.Sprintf("/etc/%s", s.baseName))
	assertFileNotExists(t, vm, fmt.Sprintf("/opt/%s", s.baseName))
}

func assertFileExists(t assert.TestingT, vm *components.RemoteHost, filepath string) {
	_, err := vm.Execute(fmt.Sprintf("stat %s", filepath))
	assert.NoError(t, err, fmt.Sprintf("file %s does not exist", filepath))
}

func assertFileNotExists(t assert.TestingT, vm *components.RemoteHost, filepath string) {
	_, err := vm.Execute(fmt.Sprintf("stat %s", filepath))
	assert.Error(t, err, fmt.Sprintf("file %s does exist", filepath))
}

func unmarshalConfigFile(t *testing.T, vm *components.RemoteHost, configFilePath string) map[string]any {
	t.Helper()
	configContent := vm.MustExecute(fmt.Sprintf("sudo cat /%s", configFilePath))
	config := map[string]any{}
	err := yaml.Unmarshal([]byte(configContent), &config)
	require.NoError(t, err, fmt.Sprintf("unexpected error on yaml parse %v, raw content:\n%s\n\n", err, configContent))
	return config
}

func unmarshallEnvFile(t *testing.T, vm *components.RemoteHost, envFilePath string) map[string]string {
	t.Helper()
	configContent := vm.MustExecute(fmt.Sprintf("sudo cat /%s", envFilePath))
	reader := strings.NewReader(configContent)
	config, err := envparse.Parse(reader)
	require.NoError(t, err, fmt.Sprintf("unexpected error on env parse %v, raw content:\n%s\n\n", err, configContent))
	return config
}
