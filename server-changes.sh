#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

if [[ ${IMAGE} =~ ucore ]]; then
    echo "Tweaking existing server config..."

    $DNF -y remove p7zip p7zip-plugins podman-compose

    # cockpit extensions not in ucore
    $DNF install -y cockpit-files cockpit-ostree

    # moby-engine packages on uCore conflict with docker-ce
    $DNF remove -y \
        containerd moby-engine runc
    rm -f /usr/bin/docker-compose
    rm -fr /usr/libexec/docker

    /ctx/server-docker-ce.sh
fi
