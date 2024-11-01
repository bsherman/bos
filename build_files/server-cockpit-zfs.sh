#!/usr/bin/bash

set -ouex pipefail

# cockpit extensions not in ucore
dnf5 install -y cockpit-files cockpit-ostree

# cockpit-zfs-manager
git clone https://github.com/45drives/cockpit-zfs-manager.git
cp -r cockpit-zfs-manager/zfs /usr/share/cockpit
rm -rf cockpit-zfs-manager

echo Fixing cockpit fonts

mkdir -p /usr/share/cockpit/base1/fonts

curl -sSL https://scripts.45drives.com/cockpit_font_fix/fonts/fontawesome.woff -o /usr/share/cockpit/base1/fonts/fontawesome.woff
curl -sSL https://scripts.45drives.com/cockpit_font_fix/fonts/glyphicons.woff -o /usr/share/cockpit/base1/fonts/glyphicons.woff
curl -sSL https://scripts.45drives.com/cockpit_font_fix/fonts/patternfly.woff -o /usr/share/cockpit/base1/fonts/patternfly.woff

mkdir -p /usr/share/cockpit/static/fonts

curl -sSL https://scripts.45drives.com/cockpit_font_fix/fonts/OpenSans-Semibold-webfont.woff -o /usr/share/cockpit/static/fonts/OpenSans-Semibold-webfont.woff