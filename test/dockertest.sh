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
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
  shift 2
done

[ -z "$SCRIPT" ] && echo "Please provide script file to test via -s/--script" && exit 1;
[ -z "$IMAGE" ] && echo "Please provide image to test via -i/--image" && exit 1;

docker run --rm --platform $PLATFORM -v $(pwd):/tmp/vol -e DD_SYSTEM_PROBE_ENSURE_CONFIG="${DD_SYSTEM_PROBE_ENSURE_CONFIG}" -e DD_INSTALL_ONLY=true -e DD_AGENT_MINOR_VERSION="${MINOR_VERSION}" -e DD_AGENT_FLAVOR="${FLAVOR}" -e EXPECTED_MINOR_VERSION="${EXPECTED_MINOR_VERSION}" -e DD_API_KEY=123 -e SCRIPT="/tmp/vol/$SCRIPT" --entrypoint /tmp/vol/test/localtest.sh "$IMAGE"
