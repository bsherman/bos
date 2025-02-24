#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running desktop packages scripts..."
/ctx/desktop-1password.sh

# ublue staging repo needed for misc packages provided by ublue
dnf5 -y copr enable ublue-os/staging

# Sunshine
dnf5 -y copr enable lizardbyte/beta

# fan profile support
dnf5 -y copr enable codifryed/CoolerControl

# terra repo for things like ghostty
dnf5 -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release

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
dnf5 install --setopt=install_weak_deps=False -y \
    adw-gtk3-theme \
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
    coolercontrol \
    devpod \
    edk2-ovmf \
    genisoimage \
    gh \
    ghostty \
    gnome-shell-extension-no-overview \
    htop \
    ibm-plex-mono-fonts \
    jetbrains-mono-fonts-all \
    libpcap-devel \
    libretls \
    libvirt \
    libvirt-daemon-kvm \
    libvirt-ssh-proxy \
    libvirt-nss \
    lm_sensors \
    ltrace \
    make \
    nerd-fonts \
    patch \
    pipx \
    podman-machine \
    powerline-fonts \
    qemu-char-spice \
    qemu-device-display-virtio-gpu \
    qemu-device-display-virtio-vga \
    qemu-device-usb-redirect \
    qemu-img \
    qemu-kvm \
    qemu-system-x86-core \
    qemu-user-binfmt \
    qemu-user-static \
    qemu \
    rocm-hip \
    rocm-opencl \
    rocm-smi \
    rsms-inter-fonts \
    shellcheck \
    shfmt \
    strace \
    sunshine \
    udisks2-btrfs \
    udisks2-lvm2 \
    yamllint \
    ydotool

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
