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
    cpp \
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
    unrar-free

# age is an unlikely candidate for EPEL until the Go packaging thing happens in Fedora 43
AGE_REL_URL="$(/ctx/github-release-url.sh FiloSottile/age linux-amd64.tar.gz)"
curl --fail --retry 5 --retry-delay 5 --retry-all-errors -sL -o /tmp/age.tar.gz "$AGE_REL_URL"
tar -zxvf /tmp/age.tar.gz -C /usr/bin/ --strip-components=1 --exclude=LICENSE
