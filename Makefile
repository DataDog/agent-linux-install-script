all: install_script.sh install_script_6.sh install_script_7.sh

clean:
	rm -f install_script.sh install_script_6.sh install_script_7.sh

define DEPRECATION_MESSAGE
\n\
install_script.sh is deprecated. Please use one of\n\
\n\
* https://s3.amazonaws.com/dd-agent/scripts/install_script_6.sh to install Agent 6\n\
* https://s3.amazonaws.com/dd-agent/scripts/install_script_7.sh to install Agent 7\n
endef

install_script.sh: install_script.sh.template
	export DEPRECATION_MESSAGE
	sed -e 's|AGENT_MAJOR_VERSION_PLACEHOLDER|6|' \
		-e 's|DEPRECATION_MESSAGE_PLACEHOLDER|echo -e "\\033[33m${DEPRECATION_MESSAGE}\\033[0m"|' \
		install_script.sh.template > $@
	chmod +x $@

install_script_6.sh: install_script.sh.template
	sed -e 's|AGENT_MAJOR_VERSION_PLACEHOLDER|6|' \
		-e 's|DEPRECATION_MESSAGE_PLACEHOLDER||' \
		install_script.sh.template > $@
	chmod +x $@

install_script_7.sh: install_script.sh.template
	sed -e 's|AGENT_MAJOR_VERSION_PLACEHOLDER|7|' \
		-e 's|DEPRECATION_MESSAGE_PLACEHOLDER||' \
		install_script.sh.template > $@
	chmod +x $@
