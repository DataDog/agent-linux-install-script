# Datadog Agent install script

This repository contains the code to generate various versions of the Datadog Agent install script. Please **always use** the officially released versions:

* https://s3.amazonaws.com/dd-agent/scripts/install_script_agent6.sh to install Agent 6
* https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh to install Agent 7

Usage instructions for the install script are in the [Datadog App](https://app.datadoghq.com/account/settings#agent/overview).

## Working with this repository

This repository contains 2 basic files, `install_script.sh.template` and `Makefile`. Calling `make` will generate these files from the template:

* `install_script.sh` - Install script that uses `DD_AGENT_MAJOR_VERSION=6` by default and also emits a deprecation warning when run.
* `install_script_agent6.sh` - Install script that uses `DD_AGENT_MAJOR_VERSION=6` by default.
* `install_script_agent7.sh` - Install script that uses `DD_AGENT_MAJOR_VERSION=7` by default.

The generated files must never be committed to this repository. All changes must be done by modifications of the template file and Makefile.

## Running tests

Tests can be run using Docker; for example to test installation of latest Agent 6 release with the `install_script_agent6.sh` file on Ubuntu 22.04 run:

```
./test/dockertest.sh --image ubuntu:22.04 --script install_script_agent6.sh
```

To test installation of the latest IoT Agent 7.38 release with the `install_script_agent7.sh` file on Ubuntu 22.04 run:

```
./test/dockertest.sh --image ubuntu:22.04 --script install_script_agent7.sh --minor_version "38" --flavor "datadog-iot-agent"
```
