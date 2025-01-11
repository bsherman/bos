#!/usr/bin/bash

if [[ ! -d /usr/libexec/rpm-ostree/wrapped ]]; then
    echo "cliwrap is not setup, skipping..."
    exit 0
fi

# Remove wrapped binaries
rm -f \
    /usr/bin/yum \
    /usr/bin/dnf \
    /usr/bin/kernel-install

# binaries which were wrapped
mv -f /usr/libexec/rpm-ostree/wrapped/* /usr/bin
rm -rf /usr/libexec/rpm-ostree

# Install dnf5 if not present
if [[ "$(rpm -E %fedora)" -lt 41 ]]; then
    rpm-ostree install --idempotent dnf5 
    if [[ ! "${IMAGE}" =~ ucore ]]; then
        dnf5 install -y dnf5-plugins
    fi
fi
