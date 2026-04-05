#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Changes shared between Desktop and Server..."

# copy system files
rsync -rvK /ctx/system_files/shared/ /
