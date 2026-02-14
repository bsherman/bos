#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

if [[ ${IMAGE} =~ ucore ]]; then
    echo "Tweaking existing server config..."

    # cockpit extensions not in ucore
    $DNF install -y cockpit-ostree

    # ensure no moby-engine packages, we can use sysext if needed
    $DNF remove -y containerd docker-buildx docker-cli docker-compose moby-engine runc

    # Temporarily remove cockpit-zfs plugin
    rm -vfr /usr/share/cockpit/zfs \
          /usr/share/polkit-1/actions/*zfs* \
          /usr/share/polkit-1/rules.d/*zfs*
          /usr/share/polkit-1/rules.d/*zpool*
fi
