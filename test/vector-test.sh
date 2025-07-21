#!/bin/bash -e

# Patch the sources.list file for debian. This is a workaround, we should change the image instead
if [[ "${IMAGE}" =~ "debian:10" ]]; then
  cp ./test/sources.list /etc/apt/sources.list
fi

# The Vector install script only configures the repos, it doesn't install

$SCRIPT

RESULT=0

if command -v dpkg > /dev/null; then
  apt-cache show vector
  RESULT=$?
else
  yum list -y vector
  RESULT=$?
fi

exit ${RESULT}
