#!/bin/bash -e

echo "VERSION:11" > /etc/SuSE-release

zypper install -y which 
zypper addrepo https://ftp5.gwdg.de/pub/opensuse/discontinued/distribution/11.1/repo/oss/ discontinued
zypper install --force -y bash=3.2-141.16

bash -c "/tmp/vol/test/localtest.sh"
