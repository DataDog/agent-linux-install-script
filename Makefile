all: install_script.sh install_script_agent6.sh install_script_agent7.sh

clean:
	rm -f install_script.sh install_script_agent6.sh install_script_agent7.sh

define DEPRECATION_MESSAGE
\n\
install_script.sh is deprecated. Please use one of\n\
\n\
* https://s3.amazonaws.com/dd-agent/scripts/install_script_agent6.sh to install Agent 6\n\
* https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh to install Agent 7\n
endef

install_script.sh: install_script.sh.template
	export DEPRECATION_MESSAGE
	sed -e 's|AGENT_MAJOR_VERSION_PLACEHOLDER|6|' \
		-e 's|INSTALL_SCRIPT_REPORT_VERSION_PLACEHOLDER||' \
		-e 's|INSTALL_INFO_VERSION_PLACEHOLDER||' \
		-e 's|IS_LEGACY_SCRIPT_PLACEHOLDER|true|' \
		-e 's|DEPRECATION_MESSAGE_PLACEHOLDER|echo -e "\\033[33m${DEPRECATION_MESSAGE}\\033[0m"|' \
		install_script.sh.template > $@
	chmod +x $@

install_script_agent6.sh: install_script.sh.template
	sed -e 's|AGENT_MAJOR_VERSION_PLACEHOLDER|6|' \
		-e 's|INSTALL_SCRIPT_REPORT_VERSION_PLACEHOLDER| 6|' \
		-e 's|INSTALL_INFO_VERSION_PLACEHOLDER|_agent6|' \
		-e 's|IS_LEGACY_SCRIPT_PLACEHOLDER||' \
		-e 's|DEPRECATION_MESSAGE_PLACEHOLDER||' \
		install_script.sh.template > $@
	chmod +x $@

install_script_agent7.sh: install_script.sh.template
	sed -e 's|AGENT_MAJOR_VERSION_PLACEHOLDER|7|' \
		-e 's|INSTALL_SCRIPT_REPORT_VERSION_PLACEHOLDER| 7|' \
		-e 's|INSTALL_INFO_VERSION_PLACEHOLDER|_agent7|' \
		-e 's|IS_LEGACY_SCRIPT_PLACEHOLDER||' \
		-e 's|DEPRECATION_MESSAGE_PLACEHOLDER||' \
		install_script.sh.template > $@
	chmod +x $@

pre_release_%:
	$(eval NEW_VERSION=$(shell echo "$@" | sed -e 's|pre_release_||'))
	sed -i "" -e "s|install_script_version=.*|install_script_version=${NEW_VERSION}|g" install_script.sh.template
	sed -i "" -e "s|^Unreleased|${NEW_VERSION}|g" CHANGELOG.rst

post_release_%:
	$(eval NEW_VERSION=$(shell echo "$@" | sed -e 's|post_release_||'))
	sed -i "" -e "s|install_script_version=.*|install_script_version=${NEW_VERSION}.post|g" install_script.sh.template
	echo "4i\n\nUnreleased\n================\n.\nw\nq" | ed CHANGELOG.rst
