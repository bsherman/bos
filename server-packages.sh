#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."

# common packages installed to desktops and servers
$DNF install -y \
    age \
    bc \
    binutils \
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

if [[ ${IMAGE} =~ ucore-hci ]]; then
    $DNF install -y incus

    # Incus UI
    curl -Lo /tmp/incus-ui-canonical.deb \
        https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/"$(curl https://pkgs.zabbly.com/incus/stable/pool/main/i/incus/ | grep -E incus-ui-canonical | cut -d '"' -f 2 | sort -r | head -1)"

    ar -x --output=/tmp /tmp/incus-ui-canonical.deb
    tar --zstd -xvf /tmp/data.tar.zst
    mv /opt/incus /usr/lib/
    sed -i 's@\[Service\]@\[Service\]\nEnvironment=INCUS_UI=/usr/lib/incus/ui/@g' /usr/lib/systemd/system/incus.service

    # Groups
    groupmod -g 250 incus-admin
    groupmod -g 251 incus
fi

groupmod -g 252 docker
