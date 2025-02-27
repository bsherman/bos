#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."

# common packages installed to desktops and servers
$DNF install -y \
    bc \
    erofs-utils \
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
    podman-tui \
    socat \
    udica

if [ -f /etc/fedora-release ]; then
$DNF install -y \
    picocom \
    unrar
fi

# official 7zip until we get Fedora/EPEL packages
curl -Lo /tmp/7zip.tar.xz \
    "$(/ctx/github-release-url.sh ip7z/7zip linux-x64)"
tar -xvf /tmp/7zip.tar.xz -C /usr/bin/ 7zz
