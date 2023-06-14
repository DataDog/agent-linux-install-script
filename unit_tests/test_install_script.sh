#!/usr/bin/env bash

file_path=$(realpath $0)
source `dirname $file_path`/extracted_functions.sh


testEnsureExists() {
  ensure_config_file_exists "sudo" "/etc/hosts" "root"
  assertEquals 1 $?
}

. shunit2