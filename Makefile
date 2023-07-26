all: install_script.sh install_script_agent6.sh install_script_agent7.sh install_script_docker_injection.sh

clean:
	rm -f install_script.sh install_script_agent6.sh install_script_agent7.sh install_script_docker_injection.sh

define DEPRECATION_MESSAGE
\n\
install_script.sh is deprecated. Please use one of\n\
\n\
* https://s3.amazonaws.com/dd-agent/scripts/install_script_agent6.sh to install Agent 6\n\
* https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh to install Agent 7\n
endef

# If GNU isn't found in 'sed --version' or if the command fails, assume macOS sed
ifeq (,$(findstring GNU,$(shell sed --version 2> /dev/null | head -n 1)))
IN_PLACE_SED = sed -i ""
else
IN_PLACE_SED = sed -i
endif

CUR_VERSION:=$(shell awk -F "=" '/^install_script_version=/{print $$NF}' install_script.sh.template)

install_script.sh: install_script.sh.template
	export DEPRECATION_MESSAGE
	sed -e 's|AGENT_MAJOR_VERSION_PLACEHOLDER|6|' \
		-e 's|INSTALL_SCRIPT_REPORT_VERSION_PLACEHOLDER|Agent|' \
		-e 's|INSTALL_INFO_VERSION_PLACEHOLDER||' \
		-e 's|IS_LEGACY_SCRIPT_PLACEHOLDER|true|' \
		-e 's|DD_APM_INSTRUMENTATION_ENABLED_DOCKER_PLACEHOLDER||' \
		-e 's|APM_TELEMETRY_SAFE_AGENT_VERSION_OVERRIDE_PLACEHOLDER||' \
		-e 's|DEPRECATION_MESSAGE_PLACEHOLDER|echo -e "\\033[33m${DEPRECATION_MESSAGE}\\033[0m"|' \
		install_script.sh.template > $@
	chmod +x $@

install_script_agent6.sh: install_script.sh.template
	sed -e 's|AGENT_MAJOR_VERSION_PLACEHOLDER|6|' \
		-e 's|INSTALL_SCRIPT_REPORT_VERSION_PLACEHOLDER|Agent 6|' \
		-e 's|INSTALL_INFO_VERSION_PLACEHOLDER|_agent6|' \
		-e 's|IS_LEGACY_SCRIPT_PLACEHOLDER||' \
		-e 's|DD_APM_INSTRUMENTATION_ENABLED_DOCKER_PLACEHOLDER||' \
		-e 's|APM_TELEMETRY_SAFE_AGENT_VERSION_OVERRIDE_PLACEHOLDER||' \
		-e 's|DEPRECATION_MESSAGE_PLACEHOLDER||' \
		install_script.sh.template > $@
	chmod +x $@

install_script_agent7.sh: install_script.sh.template
	sed -e 's|AGENT_MAJOR_VERSION_PLACEHOLDER|7|' \
		-e 's|INSTALL_SCRIPT_REPORT_VERSION_PLACEHOLDER|Agent 7|' \
		-e 's|INSTALL_INFO_VERSION_PLACEHOLDER|_agent7|' \
		-e 's|IS_LEGACY_SCRIPT_PLACEHOLDER||' \
		-e 's|DD_APM_INSTRUMENTATION_ENABLED_DOCKER_PLACEHOLDER||' \
		-e 's|APM_TELEMETRY_SAFE_AGENT_VERSION_OVERRIDE_PLACEHOLDER||' \
		-e 's|DEPRECATION_MESSAGE_PLACEHOLDER||' \
		install_script.sh.template > $@
	chmod +x $@

install_script_docker_injection.sh: install_script.sh.template
	sed -e 's|AGENT_MAJOR_VERSION_PLACEHOLDER|7|' \
		-e 's|INSTALL_SCRIPT_REPORT_VERSION_PLACEHOLDER|Docker Injection|' \
		-e 's|INSTALL_INFO_VERSION_PLACEHOLDER|_docker_injection|' \
		-e 's|IS_LEGACY_SCRIPT_PLACEHOLDER||' \
		-e 's|DD_APM_INSTRUMENTATION_ENABLED_DOCKER_PLACEHOLDER|DD_APM_INSTRUMENTATION_ENABLED="docker"|' \
		-e 's|APM_TELEMETRY_SAFE_AGENT_VERSION_OVERRIDE_PLACEHOLDER|safe_agent_version=noagent_autoinstrumentation|' \
		-e 's|DEPRECATION_MESSAGE_PLACEHOLDER||' \
		install_script.sh.template > $@
	chmod +x $@

pre_release_%:
	$(eval NEW_VERSION=$(shell echo "$@" | sed -e 's|pre_release_||'))
	$(IN_PLACE_SED) -e "s|install_script_version=.*|install_script_version=${NEW_VERSION}|g" install_script.sh.template
	$(IN_PLACE_SED) -e "s|install_script_version=.*|install_script_version=${NEW_VERSION}|g" install_script_op_worker1.sh
	$(MAKE) update_changelog VERSION=${CUR_VERSION}
	$(IN_PLACE_SED) -e "s|^Unreleased|${NEW_VERSION}|g" CHANGELOG.rst

pre_release_minor:
	$(eval CUR_MINOR=$(shell echo "${CUR_VERSION}" | tr "." "\n" | awk 'NR==2'))
	$(eval NEXT_MINOR=$(shell echo ${CUR_MINOR}+1 | bc))
	$(eval NEW_VERSION=$(shell echo "${CUR_VERSION}" | awk -v repl="${NEXT_MINOR}" 'BEGIN {FS=OFS="."} {$$2=repl; print}' | sed -e 's|.post||'))
	$(eval CUR_VERSION=$(shell echo "${CUR_VERSION}" | sed -e 's|.post||'))
	$(IN_PLACE_SED) -e "s|install_script_version=.*|install_script_version=${NEW_VERSION}|g" install_script.sh.template
	$(IN_PLACE_SED) -e "s|install_script_version=.*|install_script_version=${NEW_VERSION}|g" install_script_op_worker1.sh
	$(MAKE) update_changelog VERSION=${CUR_VERSION}
	$(IN_PLACE_SED) -e "s|^Unreleased|${NEW_VERSION}|g" CHANGELOG.rst

update_changelog:
	$(eval SPLIT=$(shell grep -n "^Unreleased" CHANGELOG.rst | cut -d':' -f1))
	$(eval SPLIT=$(shell expr ${SPLIT} + 2))
	head -${SPLIT} CHANGELOG.rst > log.rst
	git log --format=format:" - %s" $(VERSION)..HEAD | egrep -iv "post.*release" | grep -iv fix | cut -d' ' -f2- >> log.rst
	tail -n +${SPLIT} CHANGELOG.rst >> log.rst
	mv log.rst CHANGELOG.rst

post_release:
    ifneq (,$(findstring .post,${CUR_VERSION}))
	$(error "Invalid install script version (contain .post extension)")
    endif
	$(IN_PLACE_SED) -e "s|install_script_version=.*|install_script_version=${CUR_VERSION}.post|g" install_script.sh.template
	$(IN_PLACE_SED) -e "s|install_script_version=.*|install_script_version=${CUR_VERSION}.post|g" install_script_op_worker1.sh
	echo "4i\n\nUnreleased\n================\n.\nw\nq" | ed -s CHANGELOG.rst

tag:
    ifneq (,$(findstring .post,$(CUR_VERSION)))
	$(error "Please run make pre_release(_minor) first")
    endif
	git tag -as $(CUR_VERSION) -m $(CUR_VERSION)

.PHONY:	pre_release_minor update_changelog post_release tag
