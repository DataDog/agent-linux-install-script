# Datadog Agent install script

This repository contains the code to generate various versions of the Datadog Agent install script. Please **always use** the officially released versions:

* https://install.datadoghq.com/scripts/install_script_agent6.sh to install Agent 6
* https://install.datadoghq.com/scripts/install_script_agent7.sh to install Agent 7


## Agent install script usage
Basic usage instructions for the Agent install script are in the [Datadog App](https://app.datadoghq.com/account/settings#agent/overview).

### Agent configuration options
The install script allows installation of different flavors of the Agent binaries and allows you to set some configuration options automatically. We list them below with their different possible values. 

> [!IMPORTANT]
> All variables are optional except `DD_API_KEY`, which is required unless `DD_UPGRADE` (upgrade from datadog-agent 5) is set.

> [!WARNING]
> The install script input options are only considered at initial installation and they don't overwrite pre-existing configuration files.

| Variable | Description|
|-|-|
|`DD_AGENT_FLAVOR`|The Agent binary to install. Possible values are `datadog-agent`(default), `datadog-iot-agent`, `datadog-dogstatsd`, `datadog-fips-proxy`, `datadog-fips-agent`, `datadog-heroku-agent`.|
|`DD_API_KEY`|The application key to access Datadog's programatic API.|
|`DD_SITE`|The site of the Datadog intake to send Agent data to. For example, `datadoghq.com`. For more information on Datadog sites, see [Getting Started with Datadog Sites](https://docs.datadoghq.com/getting_started/site/).|
|`DD_URL`|The host of the Datadog intake server to send metrics to. For example, `https://app.datadoghq.com`. Only set this option if you need the Agent to send metrics to a custom URL: it overrides the site setting defined in `site`. It does not affect APM, Logs or Live Process intake which have their own `*_dd_url` settings.|
|`DD_HOSTNAME`|Force the hostname value.|
|`DD_TAGS`|List of host tags, defined as a comma-separated list of `key:value` strings. For example, `team:infra,env:prod`. Host tags are attached in-app to every metric, event, log, trace, and service check emitted by this Agent.|
|`DD_HOST_TAGS`|Deprecated, use `DD_TAGS` instead.|
|`DD_UPGRADE`|Set to any value to trigger a version upgrade from datadog-agent 5. Imports configuration files from `/etc/dd-agent/datadog.conf`. Not compatible with `DD_AGENT_FLAVOR=datadog-dogstatsd`.|
|`DD_FIPS_MODE`|Set to any value to enable the use of the FIPS proxy to send data to the DataDog backend. Enabling this option forces all outgoing traffic from the Agent to the local proxy. It's important to note that enabling this will not make the Datadog Agent FIPS compliant, but will force all outgoing traffic to a local FIPS compliant proxy. By-pass `DD_SITE` and `DD_URL` when enabled. For more information on FIPS compliance, see [FIPS Compliance](https://docs.datadoghq.com/agent/configuration/agent-fips-proxy/).|
|`DD_ENV`|The environment name where the Agent is running. The environment name is attached in-app to every metric, event, log, trace, and service check emitted by this Agent.|
|`DD_APM_INSTRUMENTATION_ENABLED`|Automatically instrument all your application processes alongside Agent installation. Possible values are `host`, `docker` or `all` (`all` is both `host` and `docker`). The `docker` value checks if Docker is installed and sets `DD_NO_INSTALL` to `true`. If `DD_APM_INSTRUMENTATION_LIBRARIES` is not set, it enables all libraries: `java`, `js`, `python`, `dotnet` and `ruby`. `host` injection is not compatible with the `DD_NO_AGENT_INSTALL` option. Only supported on Agent v7. Not supported on SUSE.|
|`DD_APM_INSTRUMENTATION_LIBRARIES`|Specify the APM library to be installed. Possible values are `all`, `java`, `js`, `python`, `dotnet` and `ruby`. Does not run the APM injection script, which is triggered by `DD_APM_INSTRUMENTATION_ENABLED`.|
|`DD_APM_ERROR_TRACKING_STANDALONE`|Enable Error Tracking standalone for backend services.|
|`DD_SYSTEM_PROBE_ENSURE_CONFIG`|Create the system probe configuration file from a template if it does not already exist.|
|`DD_RUNTIME_SECURITY_CONFIG_ENABLED`|If set to `true`, ensure creation of security Agent and system probe configuration file (if they don't already exist), and enable Cloud Workload Security (CWS).|
|`DD_COMPLIANCE_CONFIG_ENABLED`|If set to `true`, ensures the creation of a security Agent configuration file if one doesn't already exist, and enables Cloud Security Posture Management (CSPM).|
|`DD_DISCOVERY_ENABLED`|If set to `true`, and a system probe configuration file does not already exist, creates a system probe configuration file and enables Service Discovery.
|`DD_PRIVILEGED_LOGS_ENABLED`|If set to `true`, and a system probe configuration file does not already exist, creates a system probe configuration file and enables Privileged Logs.
|`DD_SYSTEM_PROBE_SERVICE_MONITORING_ENABLED`|If set to `true`, and a system probe configuration file does not already exist, creates a system probe configuration file and enables Universal Service Monitoring (USM).
|`DD_OTELCOLLECTOR_ENABLED`|If set to `true`, and an OTel Collector configuration file does not already exist, creates an OTel Collector configuration file and installs/enables Datadog Distribution of OpenTelemetry (DDOT).
|`DD_LOGS_CONFIG_PROCESS_COLLECT_ALL`|Enable process log collection.|
|`DD_INSTALL_ONLY`|Set to any value to prevent starting the Agent after installation.|
|`DD_NO_AGENT_INSTALL`|Do not install the Agent. Instead, installs package signature keys and creates configuration files if they don't already exist. Automatically set to `true` when `DD_APM_INSTRUMENTATION_ENABLED=docker`.|


## Install script configuration options
The install script also comes with its own configuration options.

>[!WARNING]
>Options prefixed with `TESTING_` are intended for Datadog internal use only.

| Variable | Description|
|-|-|
|`DD_INSTRUMENTATION_TELEMETRY_ENABLED`|`true` if not set. When `false`, doesn't report telemetry to Datadog in case of a script issue.|
|`DD_REPO_URL`|Domain name of the package S3 bucket to target. Default to `datadoghq.com`.|
|`REPO_URL`|Deprecated, use `DD_REPO_URL` instead.|
|`DD_RPM_REPO_GPGCHECK`|Turn on or off the `repo_gpgcheck` on RPM distributions. Possible values are `0` or `1`. Unless explicitely set, we turn off when `DD_REPO_URL` is set.|
|`DD_AGENT_MAJOR_VERSION`|The Agent major version. Must be `6` or `7`.|
|`DD_AGENT_MINOR_VERSION`|Full or partial version numbers from the minor digit. Example: `20` defaults to the highest patch version. `20.0~rc.5` explicitly targets this version. An invalid minor version terminates the script.|
|`DD_AGENT_DIST_CHANNEL`|The package distribution channel. Possible values are `stable` or `beta` on production repositories, and `stable`, `beta` or `nightly` on custom repositories. Other channels can be targeted with `TESTING_APT_URL` or `TESTING_YUM_URL`.|
|`DD_DDOT_DIST_CHANNEL`|The package distribution channel for DDOT. Possible value is `beta` on production repositories while DDOT is in preview, and `stable`, `beta` or `nightly` on custom repositories.
|`TESTING_KEYS_URL`|The URL to retrieve the package signature keys. Default to `keys.datadoghq.com`.|
|`TESTING_APT_URL`|Replace the whole APT bucket URL. Useful to test with trial buckets.|
|`TESTING_YUM_URL`|Replace the whole YUM bucket URL. Useful to test with trial buckets.|
|`TESTING_REPORT_URL`|A custom URL to receive the report and telemetry in case of a script failure.|
|`TESTING_APT_REPO_VERSION`|A custom name for the APT package. To be used with `TESTING_APT_URL` to target trial buckets.|
|`TESTING_YUM_VERSION_PATH`|A custom name for the YUM package. To be used with `TESTING_YUM_URL` to target trial buckets.|

## Others scripts
This repository also contains install scripts for Observability Pipelines Worker and Vector. For more information, see the documentation for [OPW](https://docs.datadoghq.com/observability_pipelines/setup/?tab=docker) and [Vector](https://vector.dev/docs/setup/installation/).

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
