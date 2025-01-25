#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

if [[ ${IMAGE} =~ ucore ]]; then
    echo "Tweaking existing server config..."

    # cockpit extensions not in ucore
    dnf5 install -y cockpit-files cockpit-ostree

    # moby-engine packages on uCore conflict with docker-ce
    dnf5 remove -y \
        containerd moby-engine runc
    rm -f /usr/bin/docker-compose
    rm -fr /usr/libexec/docker
fi
