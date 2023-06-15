#!/bin/bash -e

echo "VERSION:11" > /etc/SuSE-release
zypper install -y which 
zypper addrepo https://ftp5.gwdg.de/pub/opensuse/discontinued/distribution/11.1/repo/oss/ discontinue 
zypper install --force -y bash=3.2-141.16
DD_SYSTEM_PROBE_ENSURE_CONFIG="${DD_SYSTEM_PROBE_ENSURE_CONFIG}" DD_INSTALL_ONLY=true DD_AGENT_MINOR_VERSION="${MINOR_VERSION}" DD_AGENT_FLAVOR="${FLAVOR}" EXPECTED_MINOR_VERSION="${EXPECTED_MINOR_VERSION}" DD_API_KEY=123 SCRIPT="/tmp/vol/$SCRIPT" DD_APM_HOST_INJECTION_ENABLED="${DD_APM_HOST_INJECTION_ENABLED}" DD_NO_AGENT_INSTALL="$DD_NO_AGENT_INSTALL" DD_APM_LIBRARIES="$DD_APM_LIBRARIES" bash -c "/tmp/vol/test/localtest.sh"
