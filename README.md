# Datadog Agent install script

This repository contains the code to generate various versions of the Datadog Agent install script. Please **always use** the officially released versions:

* https://s3.amazonaws.com/dd-agent/scripts/install_script_agent6.sh to install Agent 6
* https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh to install Agent 7


## Agent install script usage
Basic usage instructions for the agent install script are in the [Datadog App](https://app.datadoghq.com/account/settings#agent/overview).

### Agent configuration options
Install script allows installation of different flavours of the Agent binaries and allows automatic setting of some configuration options. We list them below with their diffent possible values. 

> [!IMPORTANT]
> All variables are optional except `DD_API_KEY`, which is required unless `DD_UPGRADE` (upgrade from datadog-agent 5) is set.

> [!WARNING]
> Install script input options are only considered at initial installation, and they don't overwrite pre-existing configuration files

| Variable | Description|
|-|-|
|`DD_AGENT_FLAVOR`|The agent binary to install. Possible values are `datadog-agent`(default), `datadog-iot-agent`, `datadog-dogstatsd`, `datadog-fips-proxy`, `datadog-heroku-agent`.|
|`DD_API_KEY`|The application key to access Datadog's programatic API.|
|`DD_SITE`|The site of the Datadog intake to send Agent data to (e.g. `datadoghq.com`)|
|`DD_URL`|The host of the Datadog intake server to send metrics to (e.g. `https://app.datadoghq.com`). Only set this option if you need the Agent to send metrics to a custom URL: it overrides the site setting defined in "site". It does not affect APM, Logs or Live Process intake which have their own "*_dd_url" settings.|
|`DD_HOSTNAME`|Force the hostname name.|
|`DD_HOST_TAGS`|List of host tags, defined as a comma-separated list of `key:value` strings (e.g. `team:infra,env:prod`) Attached in-app to every metric, event, log, trace, and service check emitted by this Agent.|
|`DD_UPGRADE`|Set to any value to trigger a version upgrade from datadog-agent 5. It will import configuration files from `/etc/dd-agent/datadog.conf`. Not compatible with `DD_AGENT_FLAVOR=datadog-dogstatsd`.|
|`DD_FIPS_MODE`|Set to any value to enable the use of the FIPS proxy to send data to the DataDog backend. Enabling this will force all outgoing traffic from the Agent to the local proxy. It's important to note that enabling this will not make the Datadog Agent FIPS compliant, but will force all outgoing traffic to a local FIPS compliant proxy. By-pass `DD_SITE` and `DD_URL` when enabled|
|`DD_ENV`|The environment name where the agent is running. Attached in-app to every metric, event, log, trace, and service check emitted by this Agent.|
|`DD_APM_INSTRUMENTATION_ENABLED`|Automatically instrument all your application processes alongside agent installation. Possible values are `host`, `docker` or `all` (`all` is both `host` and `docker`). `docker` value will check if docker is installed and will set `DD_NO_INSTALL` to `true`. If `DD_APM_INSTRUMENTATION_LANGUAGES` is not set, it will enable all libraries: `java`, `js`, `python`, `dotnet` and `ruby`. `host` injection is not compatible with the `DD_NO_AGENT_INSTALL` option. Only supported on Agent v7. Not supported on SUSE.|
|`DD_APM_INSTRUMENTATION_LANGUAGES`|Specify the APM library to be installed. Possible values are `all`, `java`, `js`, `python`, `dotnet` and `ruby`. Does not run the APM injection script, which are triggered by `DD_APM_INSTRUMENTATION_ENABLED`.|
|`DD_APM_INSTRUMENTATION_NO_CONFIG_CHANGE`|Set to any value to pass the `--no-config-change` option to the APM host injection script.|
|`DD_SYSTEM_PROBE_ENSURE_CONFIG`|Create the system probe configuration file from templace, if it does not already exist.|
|`DD_RUNTIME_SECURITY_CONFIG_ENABLED`|If set to `true`, ensure creation of security agent and system probe configuration file (if they don't already exist), and enable Cloud Workload Security (CWS).|
|`DD_COMPLIANCE_CONFIG_ENABLED`|If set to `true`, ensure creation of security agent configuration file (if it doesn't already exist), and enable Cloud Security Posture Management (CSPM).|
|`DD_INSTALL_ONLY`|Set to any value to prevent starting the agent after installation.|
|`DD_NO_AGENT_INSTALL`|Do not install the agent. It will install package signature keys and create configuration files if they don't already exist.Automatically set to `true` when `DD_APM_INSTRUMENTATION_ENABLED=docker`.|


## Install script configuration options
Install script also comes with its own configuration options for testing purpose.

>[!WARNING]
> These options are for datadog internal use only.

| Variable | Description|
|-|-|
|`DD_INSTRUMENTATION_TELEMETRY_ENABLED`|`true` if not set. When `false`, won't report telemetry to Datadog in case of script issue.|
|`DD_REPO_URL`|Domain name of the package S3 bucket to target. Default to `datadoghq.com`.|
|`REPO_URL`|Deprecated, use `DD_REPO_URL` instead.|
|`DD_RPM_REPO_GPGCHECK`|Turn on or off the `repo_gpgcheck` on RPM distributions. Possible values are `0` or `1`. Unless explicitely set, we turn off when `DD_REPO_URL` is set.|
|`DD_AGENT_MAJOR_VERSION`|The Agent major version. Must be `6` or `7`|
|`DD_AGENT_MINOR_VERSION`|Full or partial version numbers from the minor digit. Example: `20` will default to the highest patch version. `20.0~rc.5` will explicitely target this version. An invalid minor version will terminate the script.|
|`DD_AGENT_DIST_CHANNEL`|The package distribution channel. Possible values are `stable` or `beta` on production repositories, and `stable`, `beta` or `nightly` on custom repositories. Other channels can be target by `TESTING_APT_URL` or `TESTING_YUM_URL`|
|`TESTING_KEYS_URL`|The URL to retrieve the package signature keys. Default to `keys.datadoghq.com`.|
|`TESTING_APT_URL`|Replace the whole APT bucket url. Useful to test with trial buckets.|
|`TESTING_YUM_URL`|Replace the whole YUM bucket url. Useful to test with trial buckets.|
|`TESTING_REPORT_URL`|A custom URL to receive the report and telemetry in case of script failure.|
|`TESTING_APT_REPO_VERSION`|A custom name for the APT package. To be used with `TESTING_APT_URL` to target trial buckets.|
|`TESTING_YUM_VERSION_PATH`|A custom name for the YUM package. To be used with `TESTING_YUM_URL` to target trial buckets.|


## Others scripts
This repository also contains install script for Observability Pipelines Worker and Vector. More information on documentation pages for [OPW](https://docs.datadoghq.com/observability_pipelines/setup/?tab=docker) and [Vector](https://vector.dev/docs/setup/installation/)

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
