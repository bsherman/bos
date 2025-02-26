#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Running desktop packages scripts..."
/ctx/desktop-1password.sh

# ublue staging repo needed for misc packages provided by ublue
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
    libvirt-ssh-proxy \
    libvirt-nss \
    lm_sensors \
    ltrace \
    make \
    nerd-fonts \
    patch \
    pipx \
    powerline-fonts \
    qemu-img \
    qemu-kvm \
    strace \
    xorriso

# github cli
if [[ "dnf5" == "${DNF}" ]]; then
    $DNF config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
else
    $DNF config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
fi
$DNF -y install gh --repo gh-cli

# github direct installs
/ctx/github-release-install.sh twpayne/chezmoi x86_64

# developer tools which aren't in EPEL, etc, so this installs them in a consistent fashion at least
curl -Lo /tmp/yamlfmt.tar.gz \
    "$(/ctx/github-release-url.sh google/yamlfmt Linux_x86_64)"
tar -xvf /tmp/yamlfmt.tar.gz -C /usr/bin/ yamlfmt

mkdir -p /tmp/shellcheck
curl -Lo /tmp/shellcheck.tar.xz \
    "$(/ctx/github-release-url.sh koalaman/shellcheck linux.x86_64)"
tar -xvf /tmp/shellcheck.tar.xz --strip-components=1 -C /tmp/shellcheck
mv /tmp/shellcheck/shellcheck /usr/bin/

curl -Lo /usr/bin/shfmt \
    "$(/ctx/github-release-url.sh mvdan/sh linux_amd64)"
chmod +x /usr/bin/shfmt

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
