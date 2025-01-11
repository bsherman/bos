#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Tweaking existing server config..."

if [[ ${IMAGE} =~ ucore ]]; then
    # moby-engine packages on uCore conflict with docker-ce
    dnf5 remove -y \
        containerd moby-engine runc
    rm -f /usr/bin/docker-compose
    rm -fr /usr/libexec/docker
fi