#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

if [[ ${IMAGE} =~ ucore ]]; then
    echo "Tweaking existing server config..."

    # cockpit extensions not in ucore
    $DNF install -y cockpit-ostree

    /ctx/build_scripts/common-hygiene.sh

    # replace the legacy bundled cockpit-zfs plugin with 45Drives/cockpit-zfs
    /ctx/build_scripts/server-cockpit-zfs.sh
fi
