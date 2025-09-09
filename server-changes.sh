#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

if [[ ${IMAGE} =~ cayo|ucore ]]; then
    echo "Tweaking existing server config..."

    # cockpit extensions not in cayo or ucore
    $DNF install -y cockpit-files cockpit-ostree
fi

if [[ ${IMAGE} =~ ucore ]]; then
    $DNF -y remove podman-compose

    # moby-engine packages on uCore conflict with docker-ce
    $DNF remove -y \
        containerd moby-engine runc
    rm -f /usr/bin/docker-compose
    rm -fr /usr/libexec/docker

    /ctx/server-docker-ce.sh
fi
