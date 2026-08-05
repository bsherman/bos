#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."

if [ -e /.git ]; then
    rm -fr /.git
fi

# Keep ucore-minimal images free of development and bcvk dependencies.
# NOTE: all packages in this script are candidates for sysext
if [[ ! ${IMAGE} =~ ucore-minimal ]]; then
    echo "Installing bcvk dependencies..."
    $DNF install -y virtiofsd

    echo "Installing Python development tools..."
    $DNF install -y \
        python3 \
        python3-pip \
        python3-virtualenv

    echo "Installing C development tools..."
    $DNF install -y \
        autoconf \
        automake \
        binutils \
        bison \
        byacc \
        ccache \
        cscope \
        ctags \
        elfutils \
        flex \
        gcc \
        gcc-c++ \
        gdb \
        glibc-devel \
        indent \
        libtool \
        ltrace \
        make \
        perf \
        pkgconf \
        strace \
        valgrind

    echo "Installing additional development tools..."
    $DNF install -y \
        cmake \
        diffstat \
        expect \
        git-lfs \
        llvm \
        ninja-build \
        patch \
        patchutils
fi

echo "Installing archive utilities..."
$DNF install -y \
    7zip \
    lzip \
    unrar-free \
    unzip \
    zip

echo "Installing network diagnostics..."
$DNF install -y \
    ipcalc \
    iperf3 \
    netcat \
    nmap \
    socat

echo "Installing system utilities..."
$DNF install -y \
    bc \
    libsodium \
    numactl \
    nvtop

echo "Installing container tools..."
$DNF install -y \
    podman-tui \
    udica

echo "Installing serial console tools..."
$DNF install -y picocom

/ctx/build_scripts/github-release-install.sh frostyard/updex "$(uname -m).rpm"
