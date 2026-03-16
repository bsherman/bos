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
    jetbrains-mono-fonts-all \
    powerline-fonts

if [[ ${IMAGE} =~ bazzite-gnome|bluefin ]]; then
    $DNF install --setopt=install_weak_deps=False -y \
        gnome-shell-extension-no-overview
#elif [[ ${IMAGE} =~ bazzite|aurora ]]; then
fi

if [ -f /etc/yum.repos.d/terra.repo ]; then
    $DNF install --from-repo=terra --enable-repo=terra --setopt=install_weak_deps=False -y \
        ghostty \
        ghostty-bash-completion \
        ghostty-shell-integration \
        ghostty-terminfo \
        ghostty-vim \
        rsms-inter-vf-fonts \
        zed
    if [[ ${IMAGE} =~ bazzite-gnome|bluefin ]]; then
        $DNF install --from-repo=terra --enable-repo=terra --setopt=install_weak_deps=False -y \
            ghostty-nautilus
    elif [[ ${IMAGE} =~ bazzite|aurora ]]; then
        $DNF install --from-repo=terra --enable-repo=terra --setopt=install_weak_deps=False -y \
            ghostty-kio
    fi
fi
