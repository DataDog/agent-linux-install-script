=============
Release Notes
=============

Unreleased
================

1.39.0
================

- (chore) Remove local `install_script_version`` variable from installer telemetry function (#338)
- (fleet) Trigger installer trace from exit trap (#336)
- (fleet) Drop support for older Agents with remote agent management (#335)

1.38.0
================

- Remove usage of `/etc/environment` for App sec and profiling as it's handled by the installer (#332)
- Upgrade(installer): Use installer install script when DD_REMOTE_UPDATES=true (#326)

1.37.1
================

- [AGENTRUN-224] Remove existing installation packages when installing datadog-fips-agent (#327)

1.37.0
================

- Add option to enable Service Discovery (#315)
- e2e: remove leftover SUSE specific code (#322)
- use environment variables for setting standalone (#319)
- remove agent-delivery from CODEOWNERS (#320)
- [e2e] Check for errors while copying scripts (#318)
- [e2e] Correct example command in README (#317)
- Add error tracking standalone variable (#314)
- cleanup dead variable (#313)

1.36.1
================

- Add datadog-fips-agent to the linux install script hash as viable flavor (#306)
- [CECO-1765] Support allowed characters in host and env tags (#302)
- Bump test-infra image so we have go1.22.8 (#304)

1.36.0
================

- remove deb/rpm fallback for apm (#298)
- Tests to ensure that deb/rpm are not installed (#299)
- [ACIX-322] Use registry.ddbuild.io for buildimages (#295)
- ci(buildimages): Rename buildimages (#293)
- Transfer ownership to container-ecosystems (#286)

1.35.4
================

- (fleet) add more tested networks, fix missing comma, add e2e to validate the trace telemetry

1.35.3
================

- (fleet) fix network telemetry (#285)

1.35.2
================

- (fleet) add network healthchecks to the script (#282)
- chore: [BARX-576] Don't run test_agent6 jobs from datadog-agent pipelines (#281)

1.35.1
================

- [BUGFIX] Fix vulnerability management config edition (#277)
- [BUGFIX] ensure we can write to the log files (#278)

1.35.0
================

- Allow enabling Infrastructure Vulnerabilities at install time (#268)
- don't attempt to install apt-transport-https with APT >= 1.5.0 (#273)
- remove dependency on /etc/docker (#271)
- Deprecate `DD_HOST_TAGS` in favor of `DD_TAGS` (#272)
- (fleet) add remote policies config (#270)
- Allow APM install without updating the agent (#269)
- Add back support for APM SSI centos6 (#275)

1.34.0
================

- feat(apm): Add support for the PHP tracer (#254)
- Check that trace and process services are stopped as well (#261)
- [gitlab] store test results artifacts by job id instead of by job name (#258)
- chore(github): reduce workflow token permission (#255)
- Prefetch go dependencies (#252)
- Pass flavor to tests (#251)

1.33.0
================

- (fleet) enable remote updates on existing installs (#247)
- Ensure the Agent is not launched when DD_INSTALL_ONLY is set (#244)

1.32.3
================

- upgrade(installer): Add telemetry on is-installed operation (#238)
- clarify installer related logs (#240)

1.32.2
================

- chore(codeowners): updates barx to agent-delivery (#233)
- fix APM tracers pinning when installing through datadog-installer

1.32.1
================

- Bump datadog-agent version (#229)
- feat(GPG): import new GPG future key (#210)
- fix permission error with empty or missing /etc/environment

1.32.0
================

- Add dynamic env var assignment for OP Worker 2 script (#226)
- Update README.md to use DD_APM_INSTRUMENTATION_LIBRARIES (#224)
- PROF-9889: Add support for propagating DD_PROFILING_ENABLED (#220)

1.31.9
================

- (fleet) add suse support (#217)
- Fix installer being displayed as Unknown (#219)

1.31.8
=============

- (fleet) make DD_REMOTE_UPDATES install the installer by default (#215)
- (fleet) restart the installer service when remote updates are enabled (#214)
- (fleet) populate the config with the installer registry parameters (#213)
- Add a check to forbid APM injection installation on redhat 6 (#212)
- (fleet) make the installer bootstrap mandatory if DD_INSTALLER is set (#211)
- (fleet) filter out packages installed by the installer (#208)

1.31.7
================

- (fleet) propagate env in installer bootstrap (#206)

1.31.6
================

- Update install_script.sh.template (#204)

1.31.5
================

- (fleet) RPM rollout (#200)

1.31.4
================

- (fleet) finish rollout of the installer (#198)

1.31.3
================

- (fleet) installer rollout to ap1 & eu1 (#194)

1.31.2
================

- (fleet) rollout to us5 (#190)

1.31.1
================

- (fleet) scope to debian (#188)
- (fleet) enable installer on us3 for APM single step beta customers (#186)

1.31.0
================

- (fleet) improve the installer install script (#182)
- (fleet) Add a 20s timeout on telemetry uploads (#181)

1.30.0
================

- Add missing env vars to OP 2.0 script (#177)
- (fleet) install the installer on Debian when APM is enabled (#175)
- Add --no-refresh to zypper invocations (#176)

1.29.0
================

- Add option to install updater (#160)

1.28.2
================

- Use sudo for any operations with install.json (#162)

1.28.1
================

- Fix install script permissions error when installing on CentOS 6 (#153)

1.28.0 [YANKED]
================

- Don't allow installing Agent > 6/7.51 on CentOS 6 (#149)

1.27.1
================

- Fix OPW v2 script metadata (#147)
- Update buildimages tag (#146)

1.27.0
================

- Add install script for OPW v2 (#142)
- Invalidate install.datadoghq.com distribution on script release (#140)
- Enforce retries in install_script for curl calls (#141)
- [E2E] Install script e2e tests are fetching the latest available python version (#139)

1.26.0
================

- Add the ability to specify a version number for a tracing library (#107)
- Add documentation about the configuration options of install script (#135)

1.25.0
================

- Fix an error that could happen when writing install_info on Google Cloud (#132)
- Distinguish single-step Linux installs from manual during reporting (#131)

1.24.0
================

- Remove usage of the datadog-apm-library-all (#111)
- Prevent errors when trying to install with no_agent in RHEL OS (#112)
- Generate an install signature on success and include in telemetry events (#110)
- invite users to add dd-agent to docker group (#105)

1.23.0
================

- feat: Add install script for Vector (#95)

1.22.0
================

- Allow installation of arm64 FIPS Proxy packages (#83)
- Show error summary when installation fails because of insufficient available disk space (#92)

1.21.0
================

- Forward DD_ENV to datadog.yml (#77)
- Use dedicated jobs for opensuse13 that are not launched on pipeline trigged from datadog-agent (#81)
- [SLES11] migrating tests using third party dependency to internal image (#80)
- Minor cleanup in script template (#79)
- CI: Add debian 12 to the test matrix (#78)
- Add test to install both agents (#76)

1.20.0
================

install_script_agent6.sh and install_script_agent7.sh
-----------------------------------------------------

- Use ``==`` for equality checks consistently (#67)
- Add ``datadog-apm-library-ruby`` to the list of known APM libraries (#68)
- Remove unused initialization of ``gpgkeys`` variable (#69)

install_script_docker_injection.sh
----------------------------------

- Initial release of ``install_script_docker_injection.sh``, a script to install
  ``datadog-apm-inject`` and APM tracer libraries without installing the Agent (#71)

install_script_op_worker1.sh
----------------------------

- Initial release of ``install_script_op_worker1.sh``, a script to install
  observability-pipelines-worker (#66, #70, #72)

1.19.0
================

- Retry install in case of DPKG error (#57)
- Fix datadog.list permissions (#61)

1.18.0
================

- Add new GPG keys for APT and RPM repositories signature rotation (#44)
- Fix install script on SLES 11 (#51, #52)
- Allow setting up compliance and runtime security products at installation time (#34)
- Change names and behavior of APM related variables (#49)

1.17.1
================

- Only replace top-level tags entry in config

1.17.0
================

- Add check for docker existing before installing
- Install injection libraries with agent install script

1.16.0
================

- Use dnf's ``--best`` on all distros that have dnf
- Handle pre-release versions passed via ``DD_AGENT_MINOR_VERSION```

1.15.0
================

- Use ``fips`` option instead of hardcoded dd_url when DD_FIPS_MODE is set.
- Prevent from installing FIPS proxy if the targeted Agent version is below 7.41.
- Added an error when asking for FIPS mode on non x86_64 architecture.

1.14.0
================

- Add success and failure telemetry events

1.13.0
================

- Stop adding and remove the old RPM GPG key 4172A230

1.12.0
================

Upgrade Notes
-------------

- Improved support for FIPS mode

  After changes to the `datadog-fips-proxy` package, script updates
  to better support the new config shipping and service management.

1.11.0
================

Upgrade Notes
-------------

- The install script is now shipped in 3 different flavors:

  - ``install_script.sh``, the original and now deprecated script
    that will eventually stop receiving updates.
  - ``install_script_agent6.sh``, which uses ``DD_AGENT_MAJOR_VERSION=6``
    unless specified otherwise.
  - ``install_script_agent7.sh``, which uses ``DD_AGENT_MAJOR_VERSION=7``
    unless specified otherwise.

Bug Fixes
---------

- Ensure ``curl`` is installed on SUSE, because ``rpm --import`` requires it.

- Properly ignore zypper failures with inaccessible repos that aren't
  related to the Agent installation.

.. _Release Notes_installscript-1.10.0:

1.10.0
================

.. _Release Notes_installscript-1.10.0_New Features:

New Features
------------

- Add FIPS mode.

  When the ``DD_FIPS_MODE`` environment variable is set, the install script
  installs an additional FIPS proxy package and configures Agent to direct
  all traffic to the backend through the FIPS proxy.


.. _Release Notes_installscript-1.10.0_Bug Fixes:

Bug Fixes
---------

- Permissions and ownership of the Agent configuration file are now set
  even if it existed before the script was executed.


.. _Release Notes_installscript-1.9.0:

installscript-1.9.0
===================

.. _Release Notes_installscript-1.9.0_Upgrade Notes:

Upgrade Notes
-------------

- Since datadog-agent 6.36/7.36, Debian 7 (Wheezy) is no longer supported,
  ``install_script.sh`` now installs 6.35/7.35 when the minor version is unpinned,
  and ``DD_AGENT_FLAVOR`` doesn't specify a version.

- Allow nightly builds install on non-prod repos.

.. _Release Notes_installscript-1.8.0:

installscript-1.8.0
===================

.. _Release Notes_installscript-1.8.0_New Features:

New Features
------------

- Enable installation of the datadog-dogstatsd package.


.. _Release Notes_installscript-1.8.0_Enhancement Notes:

Enhancement Notes
-----------------

- Don't require ``DD_API_KEY`` when the configuration file already exists.


.. _Release Notes_installscript-1.8.0_Bug Fixes:

Bug Fixes
---------

- Zypper repofile is now created correctly with only one gpgkey entry
  on OpenSUSE 42.


.. _Release Notes_installscript-1.7.1:

installscript-1.7.1
===================

.. _Release Notes_installscript-1.7.1_Bug Fixes:

Bug Fixes
---------

- Invocation of zypper when running install_script.sh as root is now fixed.


.. _Release Notes_installscript-1.7.0:

installscript-1.7.0
===================

.. _Release Notes_installscript-1.7.0_Upgrade Notes:

Upgrade Notes
-------------

- Since datadog-agent 6.33/7.33, the SUSE RPMs are only supported on OpenSUSE >= 15
  (including OpenSUSE >= 42) and SLES >= 12. On OpenSUSE < 15 and SLES < 12,
  ``install_script.sh`` now installs 6.32/7.32 when minor version is unpinned
  and ``DD_AGENT_FLAVOR`` doesn't specify version.

- On Debian-based systems, the install script now installs the
  datadog-signing-keys package in addition to the datadog-agent package.

  For users using the official apt.datadoghq.com repository: the datadog-signing-keys
  package is already present in the repository, no further action is necessary.

  For users with custom mirrors or repositories: the datadog-signing-keys
  package must be present in the same repository channel as the datadog-agent
  package, otherwise the install script will fail to install the Agent.


.. _Release Notes_installscript-1.7.0_Enhancement Notes:

Enhancement Notes
-----------------

- The ``install_script.sh`` now supports AlmaLinux and Rocky Linux installation.
  Note that only datadog-agent, datadog-iot-agent and datadog-dogstatsd since
  version 6.33/7.33 support these distributions, so trying to install older
  versions will fail.

- Environment variable ``ZYPP_RPM_DEBUG`` value is now propagated through
  ``install_script.sh`` to the ``zypper install`` command to enable
  RPM transaction debugging.


.. _Release Notes_installscript-1.6.0:

installscript-1.6.0
===================

.. _Release Notes_installscript-1.6.0_Enhancement Notes:

Enhancement Notes
-----------------

- Suggest installing the IoT Agent on armv7l.


.. _Release Notes_installscript-1.6.0_Bug Fixes:

Bug Fixes
---------

- Ensure that Debian/Ubuntu APT keyrings get created world-readable, so that
  the ``_apt`` user can read them.

- Improved detection of systemd as init system.


.. _Release Notes_installscript-1.5.0:

installscript-1.5.0
===================

.. _Release Notes_installscript-1.5.0_New Features:

New Features
------------

- Adds capability to specify a minor (and optional patch) version by setting
  the ``DD_AGENT_MINOR_VERSION`` variable.


.. _Release Notes_installscript-1.5.0_Enhancement Notes:

Enhancement Notes
-----------------

- Adds email validation before sending a report.

- Improvements for APT keys management

  - By default, get keys from keys.datadoghq.com, not Ubuntu keyserver
  - Always add the ``DATADOG_APT_KEY_CURRENT.public`` key (contains key used to sign current repodata)
  - Add ``signed-by`` option to all sources list lines
  - On Debian >= 9 and Ubuntu >= 16, only add keys to ``/usr/share/keyrings/datadog-archive-keyring.gpg``
  - On older systems, also add the same keyring to ``/etc/apt/trusted.gpg.d``


.. _Release Notes_installscript-1.5.0_Bug Fixes:

Bug Fixes
---------

- Fix SUSE version detection algorithm to work without deprecated ``/etc/SuSE-release`` file.


.. _Release Notes_installscript-1.4.0:

installscript-1.4.0
===================

.. _Release Notes_installscript-1.4.0_Enhancement Notes:

Enhancement Notes
-----------------

-  Add a ``gpgkey=`` entry ensuring that ``dnf``/``yum``/``zypper``
   always have access to the key used to sign current repodata.

-  Change RPM key location from yum.datadoghq.com to keys.datadoghq.com.

-  Activate ``repo_gpgcheck`` on RPM repositories by default.
   ``repo_gpgcheck`` is still set to ``0`` when using a custom
   ``REPO_URL`` or when running on RHEL/CentOS 8.1 because of a `bug in
   dnf`_. The default value can be overriden by specifying
   ``DD_RPM_REPO_GPGCHECK`` variable. The allowed values are ``0`` (to
   disable) and ``1`` (to enable).

.. _bug in dnf: https://bugzilla.redhat.com/show_bug.cgi?id=1792506

.. _Release Notes_installscript-1.3.1:

1.3.1
===================

.. _Release Notes_installscript-1.3.1_Prelude:

Prelude
-------

Released on: 2021-02-22

.. _Release Notes_installscript-1.3.1_New Features:

New Features
------------

- Print script version in the logs.


.. _Release Notes_installscript-1.3.1_Bug Fixes:

Bug Fixes
---------

- On error, the user prompt will now only run when a terminal is attached.
  It will have a default negative answer and it will time out after 60 seconds.


.. _Release Notes_installscript-1.3.0:

1.3.0
===================

Prelude
-------

Released on: 2021-02-15

Bug Fixes
---------

- Fix installation on SUSE < 15.


1.2.0
===================

Prelude
-------

Released on: 2021-02-12

New Features
------------

- Add release notes for installer changes.

- Prompt user to open support case when there is a failure during installation.
