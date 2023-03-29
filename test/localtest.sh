#!/bin/bash -e

EXPECTED_FLAVOR=${DD_AGENT_FLAVOR:-datadog-agent}
if [ "${EXPECTED_FLAVOR}" != "datadog-agent" ] && echo "${SCRIPT}" | grep "agent6.sh$" >/dev/null; then
    echo "[PASS] Can't install flavor '${DD_AGENT_FLAVOR}' with install_script_agent6.sh"
    exit 0
fi

$SCRIPT

INSTALLED_VERSION=
RESULT=0
EXPECTED_MAJOR_VERSION=6
if echo "${SCRIPT}" | grep "agent7.sh$" >/dev/null || [ "${EXPECTED_FLAVOR}" != "datadog-agent" ] ; then
    EXPECTED_MAJOR_VERSION=7
fi
EXPECTED_MINOR_VERSION="${EXPECTED_MINOR_VERSION:-${DD_AGENT_MINOR_VERSION}}"

# basic checks to ensure that the correct flavor was installed
if command -v dpkg > /dev/null; then
    apt-get install -y debsums
    debsums -c ${EXPECTED_FLAVOR}
    INSTALLED_VERSION=$(dpkg-query -W ${EXPECTED_FLAVOR} | cut -f2 | cut -d: -f2")
else
    # skip verification of mode/user/group, because these are
    # changed by the postinstall scriptlet
    rpm --verify --nomode --nouser --nogroup "${EXPECTED_FLAVOR}"
    INSTALLED_VERSION=$(rpm -q --qf "%{version}" "${EXPECTED_FLAVOR}")
fi

echo -e "\n"

MAJOR_VERSION=$(echo "$INSTALLED_VERSION" | cut -d "." -f 1)
MINOR_VERSION=$(echo "$INSTALLED_VERSION" | cut -d "." -f 2)


if [ "${EXPECTED_MAJOR_VERSION}" != "${MAJOR_VERSION}" ]; then
    echo "[FAIL] Expected major version ${EXPECTED_MAJOR_VERSION} to be installed, but found ${MAJOR_VERSION}"
    RESULT=1
else
    echo "[OK] Correct major version installed"
fi

if [ -n "${EXPECTED_MINOR_VERSION}" ]; then
    if [ "${EXPECTED_MINOR_VERSION}" != "${MINOR_VERSION}" ]; then
        echo "[FAIL] Expected minor version ${EXPECTED_MINOR_VERSION} to be installed, but found ${MINOR_VERSION}"
        RESULT=1
    else
        echo "[OK] Correct minor version installed"
    fi
else
    echo "[PASS] DD_AGENT_MINOR_VERSION not specified, not checking installed minor version"
fi

EXPECTED_TOOL_VERSION=
if echo "${SCRIPT}" | grep "agent6.sh$" >/dev/null; then
    EXPECTED_TOOL_VERSION="install_script_agent6"
elif echo "${SCRIPT}" | grep "agent7.sh$" >/dev/null; then
    EXPECTED_TOOL_VERSION="install_script_agent7"
elif echo "${SCRIPT}" | grep "script.sh$" >/dev/null; then
    EXPECTED_TOOL_VERSION="install_script"
else
    echo "[ERROR] Don't know what install info to expect for script ${SCRIPT}"
    RESULT=1
fi

if [ -n "${EXPECTED_TOOL_VERSION}" ]; then
    INSTALL_INFO_FILE=/etc/datadog-agent/install_info
    if [ "${EXPECTED_FLAVOR}" = "datadog-dogstatsd" ]; then
        INSTALL_INFO_FILE=/etc/datadog-dogstatsd/install_info
    fi

    TOOL_VERSION=$(cat "$INSTALL_INFO_FILE" | grep "tool_version:" | cut -d":" -f 2)
    if echo "${TOOL_VERSION}" | grep "${EXPECTED_TOOL_VERSION}$" >/dev/null; then
        echo "[OK] Correct tool_version found in install_info file"
    else
        echo "[FAIL] Expected to find tool_version ${EXPECTED_TOOL_VERSION} in install_info, but found '${TOOL_VERSION}'"
        RESULT=1
    fi
fi

exit ${RESULT}
