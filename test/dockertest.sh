#!/bin/bash -e

PLATFORM="linux/amd64"

while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--script)
      SCRIPT="$2"
      ;;
    -i|--image)
      IMAGE="$2"
      ;;
    -v|--minor-version)
      MINOR_VERSION="$2"
      ;;
    -e|--expected-minor-version)
      EXPECTED_MINOR_VERSION="$2"
      ;;
    -f|--flavor)
      FLAVOR="$2"
      ;;
    -p|--platform)
      PLATFORM="$2"
      ;;
    --injection)
      DD_APM_INSTRUMENTATION_ENABLED="$2"
      ;;
    --apm-libraries)
      DD_APM_INSTRUMENTATION_LANGUAGES="$2"
      ;;
    --no-agent)
      DD_NO_AGENT_INSTALL="$2"
      ;;
    --old-suse)
      DD_OLD_SUSE="$2"
      ;;
    --apt-url)
      TESTING_APT_URL="$2"
      ;;
    --apt-repo-version)
      TESTING_APT_REPO_VERSION="$2"
      ;;
    --yum-url)
      TESTING_YUM_URL="$2"
      ;;
    --yum-version-path)
      TESTING_YUM_VERSION_PATH="$2"
      ;;
    --observability-pipelines-worker)
      DD_OP="$2"
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
  shift 2
done

[ -z "$SCRIPT" ] && echo "Please provide script file to test via -s/--script" && exit 1;
[ -z "$IMAGE" ] && echo "Please provide image to test via -i/--image" && exit 1;

<<<<<<< HEAD
if [ "$DD_OLD_SUSE" ]; then
=======
if [ "$DD_OLD_SUSE" != "true" ]; then
    ENTRYPOINT_PATH="/tmp/vol/test/localtest.sh"
else
>>>>>>> f68c294 (AP-2157 Modify CI to be able to trigger from datadog-agent (#56))
    ENTRYPOINT_PATH="/tmp/vol/test/old-suse-startup.sh"
elif [ "$DD_OP" ]; then
    ENTRYPOINT_PATH="/tmp/vol/test/op-worker-test.sh"
else
    ENTRYPOINT_PATH="/tmp/vol/test/localtest.sh"
fi

docker run --rm --platform $PLATFORM -v $(pwd):/tmp/vol \
  -e DD_SYSTEM_PROBE_ENSURE_CONFIG="${DD_SYSTEM_PROBE_ENSURE_CONFIG}" \
  -e DD_COMPLIANCE_CONFIG_ENABLED="${DD_COMPLIANCE_CONFIG_ENABLED}" \
  -e DD_RUNTIME_SECURITY_CONFIG_ENABLED="${DD_RUNTIME_SECURITY_CONFIG_ENABLED}" \
  -e DD_INSTALL_ONLY=true -e DD_AGENT_MINOR_VERSION="${MINOR_VERSION}" \
  -e DD_AGENT_FLAVOR="${FLAVOR}" \
  -e EXPECTED_MINOR_VERSION="${EXPECTED_MINOR_VERSION}" \
  -e DD_API_KEY=123 -e SCRIPT="/tmp/vol/$SCRIPT" \
  -e DD_APM_INSTRUMENTATION_ENABLED="${DD_APM_INSTRUMENTATION_ENABLED}" \
  -e DD_NO_AGENT_INSTALL="$DD_NO_AGENT_INSTALL" \
  -e DD_APM_INSTRUMENTATION_LANGUAGES="${DD_APM_INSTRUMENTATION_LANGUAGES}" \
  -e DD_OLD_SUSE="$DD_OLD_SUSE" \
<<<<<<< HEAD
  -e DD_OP_WORKER_MINOR_VERSION="${MINOR_VERSION}" \
  -e DD_OP_PIPELINE_ID=123 \
=======
  -e TESTING_APT_URL="$TESTING_APT_URL" \
  -e TESTING_APT_REPO_VERSION="$TESTING_APT_REPO_VERSION" \
  -e TESTING_YUM_URL="$TESTING_YUM_URL" \
  -e TESTING_YUM_VERSION_PATH="$TESTING_YUM_VERSION_PATH" \
>>>>>>> f68c294 (AP-2157 Modify CI to be able to trigger from datadog-agent (#56))
  --entrypoint "$ENTRYPOINT_PATH" "$IMAGE"
