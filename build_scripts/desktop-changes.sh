#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Tweaking existing desktop config..."

if [[ ${IMAGE} =~ bluefin|bazzite ]]; then
    # ensure /opt and /usr/local are proper
    mkdir -p /var/opt /var/usrlocal

    if [[ ! -h /opt ]]; then
        rm -fr /opt
        ln -s /var/opt /opt
    fi
    if [[ ! -h /usr/local ]]; then
        # shellcheck disable=SC2114
        rm -fr /usr/local
        ln -s /var/usrlocal /usr/local
    fi

    # remove solaar and input leap, if installed
    # NOTE: these no longer seem to be installed on bazzite
    $DNF -y remove input-leap solaar virt-manager virt-viewer virt-v2v

    /ctx/build_scripts/common-hygiene.sh
fi
