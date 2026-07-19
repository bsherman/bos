#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."

if [ -e /.git ]; then
    rm -fr /.git
fi

# common packages installed to desktops and servers
packages=(
    7zip
    age
    bc
    binutils
    cpp
    git-lfs
    hdparm
    ipcalc
    iperf3
    libsodium
    lzip
    netcat
    nmap
    numactl
    nvtop
    picocom
    podman-tui
    socat
    udica
    unrar-free
    unzip
    zip
)

# virtiofsd for bcvk; skip ucore-minimal variants
if [[ ! ${IMAGE} =~ ucore-minimal ]]; then
    packages+=(virtiofsd)
fi

$DNF install -y "${packages[@]}"

/ctx/build_scripts/github-release-install.sh frostyard/updex "$(uname -m).rpm"
