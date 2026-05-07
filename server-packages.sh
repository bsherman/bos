#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."

if [ -e /.git ]; then
    rm -fr /.git
fi

# common packages installed to desktops and servers
$DNF install -y \
    7zip \
    age \
    bc \
    binutils \
    cpp \
    hdparm \
    ipcalc \
    iperf3 \
    libsodium \
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
    unzip \
    zip

/ctx/github-release-install.sh frostyard/updex "$(uname -m).rpm"
