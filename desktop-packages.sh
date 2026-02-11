#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running desktop packages scripts..."
/ctx/desktop-1password.sh

# ublue staging and packages repos needed for misc packages provided by ublue
$DNF -y copr enable ublue-os/packages
$DNF -y copr enable ublue-os/staging

# VSCode because it's still better for a lot of things
tee /etc/yum.repos.d/vscode.repo <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# common packages installed to desktops
$DNF install --setopt=install_weak_deps=False -y \
    code \
    gnome-shell-extension-no-overview \
    jetbrains-mono-fonts-all \
    powerline-fonts
