#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."

if [ -e /.git ]; then
    rm -fr /.git
fi

# common packages installed to desktops and servers
packages=(
    7zip
    bc
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

# Keep ucore-minimal images free of development and bcvk dependencies.
# NOTE: all packages in this script are candidates for sysext
if [[ ! ${IMAGE} =~ ucore-minimal ]]; then
    # bcvk dependency
    packages+=(virtiofsd)

    # C development (explicit reproduction of dnf "c-development" group)
    packages+=(
        autoconf
        automake
        binutils
        bison
        byacc
        ccache
        cscope
        ctags
        elfutils
        flex
        gcc
        gcc-c++
        gdb
        glibc-devel
        indent
        libtool
        ltrace
        make
        perf
        pkgconf
        strace
        valgrind
    )

    # Development tools (other)
    packages+=(
        cmake
        diffstat
        expect
        git-lfs
        llvm
        ninja-build
        patch
        patchutils
    )

    # Python
    packages+=(
        python3
        python3-pip
        python3-virtualenv
    )
fi

$DNF install -y "${packages[@]}"

/ctx/build_scripts/github-release-install.sh frostyard/updex "$(uname -m).rpm"
