#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running desktop packages scripts..."
/ctx/build_scripts/desktop-sunshine.sh
#echo "Running desktop packages scripts..."
#/ctx/build_scripts/desktop-1password.sh

# ublue staging and packages repos needed for misc packages provided by ublue
#$DNF -y copr enable ublue-os/packages
#$DNF -y copr enable ublue-os/staging
