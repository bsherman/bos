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


if getent group "docker" > /dev/null 2>&1; then
    # If "docker" exists in /usr/lib/group but not in /etc/group
    if ! grep -q "^docker:" /etc/group && grep -q "^docker:" /usr/lib/group; then
        # Add the group from /usr/lib/group to /etc/group
        grep "^docker:" /usr/lib/group >> /etc/group
    fi

    # If "docker" exists in /etc/group, modify the group ID
    if grep -q "^docker:" /etc/group; then
        groupmod -g 252 docker
    fi
fi
