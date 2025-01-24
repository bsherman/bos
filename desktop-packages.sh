#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running desktop packages scripts..."
/ctx/desktop-1password.sh

# ublue staging repo needed for ghostty, etc
dnf5 -y copr enable ublue-os/staging
dnf5 -y copr enable bsherman1/rkvm

# common packages installed to desktops
dnf5 install -y \
    gh \
    ghostty \
    gnome-shell-extension-no-overview \
    ibm-plex-fonts-all \
    libpcap-devel \
    libretls \
    ltrace \
    patch \
    pipx \
    rkvm \
    rsms-inter-fonts \
    shellcheck \
    shfmt \
    strace \
    udica \
    yamllint \
    ydotool

dnf5 -y copr disable ublue-os/staging
dnf5 -y copr disable bsherman1/rkvm

# github direct installs
/ctx/github-release-install.sh twpayne/chezmoi x86_64

curl -Lo /tmp/yamlfmt.tar.gz \
    "$(/ctx/github-release-url.sh google/yamlfmt Linux_x86_64)"
tar -xvf /tmp/yamlfmt.tar.gz -C /usr/bin/ yamlfmt

# Zed because why not?
curl -Lo /tmp/zed.tar.gz \
    https://zed.dev/api/releases/stable/latest/zed-linux-x86_64.tar.gz
mkdir -p /usr/lib/zed.app/
tar -xvf /tmp/zed.tar.gz -C /usr/lib/zed.app/ --strip-components=1
chown 0:0 -R /usr/lib/zed.app
ln -s /usr/lib/zed.app/bin/zed /usr/bin/zed-cli
cp /usr/lib/zed.app/share/applications/zed.desktop /usr/share/applications/dev.zed.Zed.desktop
mkdir -p /usr/share/icons/hicolor/1024x1024/apps
cp {/usr/lib/zed.app,/usr}/share/icons/hicolor/512x512/apps/zed.png
cp {/usr/lib/zed.app,/usr}/share/icons/hicolor/1024x1024/apps/zed.png
sed -i "s@Exec=zed@Exec=/usr/lib/zed.app/libexec/zed-editor@g" /usr/share/applications/dev.zed.Zed.desktop
