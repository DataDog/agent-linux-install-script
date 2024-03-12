if [[ -v DD_APPSEC_ENABLED ]]; then
  sudo sed -i -n -e '/^DD_APPSEC_ENABLED=/!p' -e '$aDD_APPSEC_ENABLED='"$DD_APPSEC_ENABLED"'' /etc/environment
fi
