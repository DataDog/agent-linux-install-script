// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-present Datadog, Inc.

package e2e

import (
	"flag"
	"fmt"
)

const (
	defaultScriptURL = "https://s3.amazonaws.com/dd-agent/scripts/"
)

var (
	flavor    string // datadog-agent, datadog-iot-agent, datadog-dogstatsd
	mode      string // install, upgrade5, upgrade6, upgrade7
	apiKey    string // Needs to be valid, at least for the upgrade5 scenario
	scriptURL string // To test a non-published script
	noFlush   bool   // To prevent eventual cleanup, to test install_script won't override existing configuration
)

// note: no need to call flag.Parse() on test code, go test does it
func init() {
	flag.StringVar(&flavor, "flavor", "datadog-agent", "defines agent install flavor")
	flag.StringVar(&mode, "mode", "install", "test mode")
	flag.BoolVar(&noFlush, "noFlush", false, "To prevent eventual cleanup, to test install_script won't override existing configuration")
	flag.StringVar(&apiKey, "apiKey", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "Datadog API key")
	flag.StringVar(&scriptURL, "scriptURL", defaultScriptURL, fmt.Sprintf("Defines the script URL, default %s", defaultScriptURL))
}

// TYPE=production
// [[ -n $SCRIPT_URL ]] && TYPE=custom
// echo "${CYAN}We will $MODE $FLAVOR with $TYPE install_script${NORMAL}"

// ## Flavor selection
// if [[ "$FLAVOR" == "datadog-dogstatsd" ]]; then
//     BASE_NAME=datadog-dogstatsd
//     CONFIG_FILE=dogstatsd.yaml
// else
//     BASE_NAME=datadog-agent
//     CONFIG_FILE=datadog.yaml
// fi

// function failure() {
//     echo "${RED}Install test failure${NORMAL}"
//     exit 1
// }

// ## Installation
// if [[ "$MODE" == "install" ]]; then
//     echo "Install latest Agent 7 RC"
//     DD_AGENT_FLAVOR=$FLAVOR DD_AGENT_MAJOR_VERSION=7 DD_API_KEY="$API_KEY" DD_SITE="datadoghq.com" DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c "$(curl -sL "$SCRIPT_URL"/install_script_agent7.sh)"
// elif [[ "$MODE" == "upgrade7" ]]; then
//     echo "Install latest Agent 7"
//     DD_AGENT_FLAVOR=$FLAVOR DD_AGENT_MAJOR_VERSION=7 DD_API_KEY="$API_KEY" bash -c "$(curl -L "$SCRIPT_URL"/install_script_agent7.sh)"
//     echo "Install latest Agent 7 RC"
//     DD_AGENT_FLAVOR=$FLAVOR DD_AGENT_MAJOR_VERSION=7 DD_API_KEY="$API_KEY" DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c "$(curl -L "$SCRIPT_URL"/install_script_agent7.sh)"
// elif [[ "$MODE" == "upgrade6" ]]; then
//     echo "Install latest Agent 6"
//     DD_AGENT_FLAVOR=$FLAVOR DD_AGENT_MAJOR_VERSION=6 DD_API_KEY="$API_KEY" bash -c "$(curl -L "$SCRIPT_URL"/install_script_agent6.sh)"
//     echo "Install latest Agent 7 RC"
//     DD_AGENT_FLAVOR=$FLAVOR DD_AGENT_MAJOR_VERSION=7 DD_API_KEY="$API_KEY" DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c "$(curl -L "$SCRIPT_URL"/install_script_agent7.sh)"
// elif [[ "$MODE" == "upgrade5" ]]; then
//     if [[ "$FLAVOR" != "datadog-agent" ]]; then echo "$FLAVOR not supported on Agent 5"; exit 1; fi

//     echo "Install latest Agent 5"
//     DD_API_KEY="$API_KEY" bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)"
//     echo "Install latest Agent 7 RC"
//     DD_AGENT_FLAVOR=$FLAVOR DD_AGENT_MAJOR_VERSION=7 DD_API_KEY="$API_KEY" DD_UPGRADE=true DD_REPO_URL=datad0g.com DD_AGENT_DIST_CHANNEL=beta bash -c "$(curl -L "$SCRIPT_URL"/install_script_agent7.sh)"
// fi

// echo "${CYAN}Check user, config file and service${NORMAL}"
// # Check presence of the dd-agent user
// id dd-agent || { echo "dd-agent not present after Agent install"; failure; }

// # Check presence of the config file - the file is added by the install script, so this should always be okay
// # if the install succeeds
// stat /etc/$BASE_NAME/$CONFIG_FILE || { echo "/etc/$BASE_NAME/$CONFIG_FILE absent after install"; failure; }

// # Check presence and ownership of the config and main directories
// [[ $(stat -c "%U" /etc/$BASE_NAME/) == "dd-agent" ]] || { echo "dd-agent does not own /etc/$BASE_NAME"; failure; }
// [[ $(stat -c "%U" /opt/$BASE_NAME/) == "dd-agent" ]] || { echo "dd-agent does not own /opt/$BASE_NAME"; failure; }

// # Check that the service is active
// if command -v systemctl; then
//     systemctl is-active $BASE_NAME || { echo "datadog-agent not running after Agent install"; failure; }
// elif command -v initctl; then
//     [[ $(sudo status $BASE_NAME) == *running* ]] || { echo "datadog-agent not running after Agent install"; failure; }
// else
//     echo "Unknown service manager" && exit 1
// fi

// if [[ "$FLAVOR" == "datadog-agent" ]]; then
//     echo "${CYAN}Install an extra integration, and create a custom file${NORMAL}"
//     sudo -u dd-agent -- datadog-agent integration install -t datadog-bind9==0.1.0 || { echo "integration install failed"; failure; }
//     sudo -u dd-agent -- touch /opt/$BASE_NAME/embedded/lib/python3.9/site-packages/testfile
// fi

// echo "${CYAN}Remove $FLAVOR${NORMAL}"
// if command -v apt; then
//     sudo apt remove -y $FLAVOR
//     # dd-agent user and config file should still be here
//     id dd-agent || { echo "dd-agent not present after apt remove"; failure; }
//     stat /etc/$BASE_NAME/$CONFIG_FILE || { echo "/etc/$BASE_NAME/datadog.yaml absent after apt remove"; failure; }
//     if [[ "$FLAVOR" == "datadog-agent" ]]; then
//         # The custom file should still be here. All other files, including the extre integration, should be removed
//         stat /opt/$BASE_NAME/embedded/lib/python3.9/site-packages/testfile || { echo "testfile absent after apt remove"; failure; }
//         [[ $(find /opt/$BASE_NAME -type f | wc -l) == "1" ]] || { echo "/opt/$BASE_NAME present after apt remove"; failure; }
//     else
//         # All files in /opt/datadog-agent should be removed
//         { stat /opt/$BASE_NAME && echo "/opt/$BASE_NAME present after apt remove" && failure; } || true
//     fi
//     if [[ -z $NO_FLUSH ]]; then
//         echo "${CYAN}Purge package${NORMAL}"
//         sudo apt remove --purge -y $FLAVOR
//         # dd-agent user and all files should be removed
//         { id dd-agent && echo "dd-agent present after apt purge" && failure; } || true
//         { stat /etc/$BASE_NAME && echo "/etc/$BASE_NAME present after apt purge" && failure; } || true
//         { stat /opt/$BASE_NAME && echo "/opt/$BASE_NAME present after apt purge" && failure; } || true
//     fi
// elif command -v yum; then
//     sudo yum remove -y $FLAVOR
//     # dd-agent user and config file should still be here
//     id dd-agent || { echo "dd-agent not present after yum remove"; failure; }
//     stat /etc/$BASE_NAME/$CONFIG_FILE || { echo "/etc/$BASE_NAME/datadog.yaml absent after yum remove"; failure; }
//     if [[ "$FLAVOR" == "datadog-agent" ]]; then
//         # The custom file should still be here. All other files, including the extra integration, should be removed
//         stat /opt/$BASE_NAME/embedded/lib/python3.9/site-packages/testfile || { echo "testfile absent after apt remove"; failure; }
//         [[ $(find /opt/$BASE_NAME -type f | wc -l) == "1" ]] || { echo "/opt/$BASE_NAME present after apt remove"; failure; }
//     else
//         # All files in /opt/$BASE_NAME should be removed
//         { stat /opt/$BASE_NAME && echo "/opt/$BASE_NAME present after apt remove" && failure; } || true
//     fi
// elif command -v zypper; then
//     sudo zypper remove -y $FLAVOR
//     # dd-agent user and config file should still be here
//     id dd-agent || { echo "dd-agent not present after zypper remove"; failure; }
//     stat /etc/$BASE_NAME/$CONFIG_FILE || { echo "/etc/$BASE_NAME/datadog.yaml absent after zypper remove"; failure; }
//     if [[ "$FLAVOR" == "datadog-agent" ]]; then
//         # The custom file should still be here. All other files, including the extra integration, should be removed
//         stat /opt/$BASE_NAME/embedded/lib/python3.9/site-packages/testfile || { echo "testfile absent after zypper remove"; failure; }
//         [[ $(find /opt/$BASE_NAME -type f | wc -l) == "1" ]] || { echo "/opt/$BASE_NAME present after zypper remove"; failure; }
//     else
//         # All files in /opt/datadog-agent should be removed
//         { stat /opt/$BASE_NAME && echo "/opt/$BASE_NAME present after zypper remove" && failure; } || true
//     fi
// else
//     echo "Unknown package manager" && exit 1
// fi
// echo "${GREEN}Install test successful!${NORMAL}"
