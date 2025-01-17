#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running server packages scripts..."
/ctx/server-docker-ce.sh

# common packages installed to desktops and servers
dnf5 install -y \
    bc \
    cockpit-files \
    cockpit-ostree \
    erofs-utils \
    hdparm \
    intel_gpu_top \
    iotop \
    ipcalc \
    iperf3 \
    just \
    lm_sensors \
    lshw \
    lzip \
    netcat \
    nmap \
    p7zip \
    p7zip-plugins \
    picocom \
    socat \
    unrar
