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
    p7zip \
    p7zip-plugins \
    picocom \
    unrar
fi
