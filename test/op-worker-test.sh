#!/bin/bash -e

if [[ -v "$DD_OPW_INSTALL_CLASSIC_AGENT" ]]; then
$DD_OPW_INSTALL_CLASSIC_AGENT
fi

$SCRIPT

EXPECTED_FLAVOR=observability-pipelines-worker
INSTALLED_VERSION=
RESULT=0
EXPECTED_MAJOR_VERSION=1
EXPECTED_MINOR_VERSION="${EXPECTED_MINOR_VERSION:-${DD_OP_WORKER_MINOR_VERSION}}"

if command -v dpkg > /dev/null; then
  apt-get install -y debsums

  debsums -c ${EXPECTED_FLAVOR}
  INSTALLED_VERSION=$(dpkg-query -W ${EXPECTED_FLAVOR} | cut -f2 | cut -d: -f2)
else
  rpm --verify --nomode --nouser --nogroup "${EXPECTED_FLAVOR}"
  INSTALLED_VERSION=$(rpm -q --queryformat "%{version}" "${EXPECTED_FLAVOR}")
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
  echo "[PASS] DD_OP_WORKER_MINOR_VERSION not specified, not checking installed minor version"
fi

EXPECTED_TOOL_VERSION=install_script_op_worker1
INSTALL_INFO_FILE=/etc/observability-pipelines-worker/install_info
TOOL_VERSION=$(cat "$INSTALL_INFO_FILE" | grep "tool_version:" | cut -d":" -f 2)
if echo "${TOOL_VERSION}" | grep "${EXPECTED_TOOL_VERSION}$" >/dev/null; then
  echo "[OK] Correct tool_version found in install_info file"
else
  echo "[FAIL] Expected to find tool_version ${EXPECTED_TOOL_VERSION} in install_info, but found '${TOOL_VERSION}'"
  RESULT=1
fi

exit ${RESULT}
