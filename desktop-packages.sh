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

if [ -f /etc/centos-release ]; then
    # for EL, enable repos
    $DNF config-manager --set-enabled epel
    #$DNF config-manager --set-enabled epel-testing
    update-crypto-policies --set LEGACY
fi

# common packages installed to desktops
$DNF install --setopt=install_weak_deps=False -y \
    ccache \
    cockpit-bridge \
    cockpit-files \
    cockpit-machines \
    cockpit-networkmanager \
    cockpit-ostree \
    cockpit-podman \
    cockpit-selinux \
    cockpit-storaged \
    cockpit-system \
    code \
    edk2-ovmf \
    git \
    gnome-shell-extension-no-overview \
    guestfs-tools \
    htop \
    jetbrains-mono-fonts-all \
    libpcap-devel \
    libretls \
    libvirt \
    libvirt-daemon-kvm \
    libvirt-nss \
    lm_sensors \
    ltrace \
    make \
    nerd-fonts \
    patch \
    powerline-fonts \
    rpmrebuild \
    sbsigntools \
    strace \
    ublue-os-libvirt-workarounds \
    xorriso \
    zenity

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
