#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

if [[ ${IMAGE} =~ cayo|ucore ]]; then
    echo "Tweaking existing server config..."

    # cockpit extensions not in cayo or ucore
    $DNF install -y cockpit-files cockpit-ostree
fi
