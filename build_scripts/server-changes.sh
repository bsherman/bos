#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

if [[ ${IMAGE} =~ ucore ]]; then
    echo "Tweaking existing server config..."

    # cockpit extensions not in ucore
    $DNF install -y cockpit-ostree

    /ctx/build_scripts/common-hygiene.sh

    # Temporarily remove cockpit-zfs plugin
    rm -vfr /usr/share/cockpit/zfs \
          /usr/share/polkit-1/actions/*zfs* \
          /usr/share/polkit-1/rules.d/*zfs* \
          /usr/share/polkit-1/rules.d/*zpool*
fi
