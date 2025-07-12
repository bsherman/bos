#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."

if [ -f /etc/centos-release ]; then
    # for EL, enable repos
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
    bc \
    git-lfs \
    hdparm \
    ipcalc \
    iperf3 \
    just \
    libsodium \
    lzip \
    mosh \
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

# age is an unlikely candidate for EPEL until the Go packaging thing happens in Fedora 43
curl -Lo /tmp/age.tar.gz \
    "$(/ctx/github-release-url.sh FiloSottile/age linux-amd64.tar.gz)"
tar -zxvf /tmp/age.tar.gz -C /usr/bin/ --strip-components=1 --exclude=LICENSE
