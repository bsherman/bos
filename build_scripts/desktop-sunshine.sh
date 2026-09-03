#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Installing Sunshine"

fedora_version=$(rpm -E %fedora)
architecture=$(uname -m)
asset_filter="^Sunshine-[0-9.]+-[0-9.]+\\.fc${fedora_version}\\.${architecture}\\.rpm$"

/ctx/build_scripts/github-release-install.sh \
    LizardByte/Sunshine \
    "${asset_filter}"
