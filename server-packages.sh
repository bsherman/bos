#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."

# common packages installed to desktops and servers
$DNF install -y \
    age \
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
    p7zip \
    picocom \
    podman-tui \
    socat \
    udica \
    unrar-free \
    unzip \
    zip
