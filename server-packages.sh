#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."

if [ -f /etc/centos-release ]; then
    # for EL, enable EPEL and EPEL testing repos
    $DNF config-manager --set-enabled epel
    $DNF config-manager --set-enabled epel-testing
fi

# common packages installed to desktops and servers
$DNF install -y \
    bc \
    erofs-utils \
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
    unrar-free

# official 7zip until we get Fedora/EPEL packages
curl -Lo /tmp/7zip.tar.xz \
    "$(/ctx/github-release-url.sh ip7z/7zip linux-x64)"
tar -xvf /tmp/7zip.tar.xz -C /usr/bin/ 7zz
