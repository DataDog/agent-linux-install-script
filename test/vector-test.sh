#!/bin/bash -e

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
