#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."

if [ -f /etc/centos-release ]; then
    # for EL, enable EPEL repos
    $DNF config-manager --set-enabled epel
    #$DNF config-manager --set-enabled epel-testing

    # since p7zip not in EPEL yet
    SEVENZIP=7zip
else
    SEVENZIP=p7zip
fi

# common packages installed to desktops and servers
$DNF install -y \
    $SEVENZIP \
    age \
    bc \
    git-lfs \
    hdparm \
    iotop \
    ipcalc \
    iperf3 \
    just \
    lshw \
    lzip \
    netcat \
    nmap \
    numactl \
    nvtop \
    picocom \
    podman-tui \
    socat \
    udica \
    unrar-free \
    "$(/ctx/github-release-url.sh getsops/sops x86_64.rpm)"
