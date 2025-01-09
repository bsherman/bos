#!/bin/bash

set -ouex pipefail

# there is no 'rpm-ostree cliwrap uninstall-from-root', but this is close enough. See:
# https://github.com/coreos/rpm-ostree/blob/6d2548ddb2bfa8f4e9bafe5c6e717cf9531d8001/rust/src/cliwrap.rs#L25-L32
if [ -d /usr/libexec/rpm-ostree/wrapped ]; then
    # binaries which could be created if they did not exist thus may not be in wrapped dir
    rm -f \
        /usr/bin/yum \
        /usr/bin/dnf \
        /usr/bin/kernel-install
    # binaries which were wrapped
    mv -f /usr/libexec/rpm-ostree/wrapped/* /usr/bin
    rm -fr /usr/libexec/rpm-ostree
fi

RELEASE="$(rpm -E %fedora)"
if [ 40 -eq ${RELEASE} ]; then
    rpm-ostree install --idempotent dnf5 dnf5-plugins
fi

case "${IMAGE}" in
"bluefin"*)
    /ctx/build_files/desktop-changes.sh
    /ctx/build_files/desktop-fixups-steam.sh
    /ctx/build_files/desktop-packages.sh
    ;;
"bazzite"*)
    /ctx/build_files/desktop-changes.sh
    /ctx/build_files/desktop-packages.sh
    ;;
"ucore"*)
    /ctx/build_files/server-changes.sh
    ;;
esac

/ctx/build_files/server-packages.sh
/ctx/build_files/branding.sh
/ctx/build_files/signing.sh
