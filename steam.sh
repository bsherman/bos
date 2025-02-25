#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

sed -i "0,/enabled=0/{s/enabled=0/enabled=1/}" /etc/yum.repos.d/negativo17-fedora-multimedia.repo

STEAM_PACKAGES=(
    clinfo
    gamescope.x86_64
    gamescope-libs.i686
    gamescope-shaders
    gobject-introspection
    latencyflex-vulkan-layer
    libFAudio.i686
    libFAudio.x86_64
    libobs_glcapture.i686
    libobs_vkcapture.i686
    libobs_glcapture.x86_64
    libobs_vkcapture.x86_64
    lutris
    mangohud.i686
    mangohud.x86_64
    mesa-va-drivers.i686
    mesa-vulkan-drivers.i686
    steam
    umu-launcher
    vkBasalt.i686
    vkBasalt.x86_64
    winetricks
    wine-core.i686
    wine-core.x86_64
    wine-pulseaudio.i686
    wine-pulseaudio.x86_64
)

$DNF install -y "${STEAM_PACKAGES[@]}"

ln -sf wine32 /usr/bin/wine
ln -sf wine32-preloader /usr/bin/wine-preloader
ln -sf wineserver64 /usr/bin/wineserver
sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nNoDisplay=true@g' /usr/share/applications/winetricks.desktop
curl -Lo /tmp/latencyflex.tar.xz "$(curl https://api.github.com/repos/ishitatsuyuki/LatencyFleX/releases/latest | jq -r '.assets[] | select(.name| test(".*.tar.xz$")).browser_download_url')"
mkdir -p /tmp/latencyflex
tar --no-same-owner --no-same-permissions --no-overwrite-dir --strip-components 1 -xvf /tmp/latencyflex.tar.xz -C /tmp/latencyflex
rm -f /tmp/latencyflex.tar.xz
cp -r /tmp/latencyflex/wine/usr/lib/wine/* /usr/lib64/wine/
rm -rf /tmp/latencyflex
curl -Lo /usr/bin/latencyflex https://raw.githubusercontent.com/KyleGospo/LatencyFleX-Installer/main/install.sh
chmod +x /usr/bin/latencyflex
sed -i 's@/usr/lib/wine/@/usr/lib64/wine/@g' /usr/bin/latencyflex
sed -i 's@"dxvk.conf"@"/usr/share/latencyflex/dxvk.conf"@g' /usr/bin/latencyflex
chmod +x /usr/bin/latencyflex

sed -i "s@enabled=1@enabled=0@" /etc/yum.repos.d/negativo17-fedora-multimedia.repo

# this allows mangohud to read CPU power wattage
tee /usr/lib/systemd/system/sysfs-read-powercap-intel.service <<EOF
[Unit]
Description=Set readable intel cpu power
After=systemd-udevd.service
After=tuned.service
ConditionPathExists=/sys/class/powercap/intel-rapl:0/energy_uj

[Service]
Type=oneshot
ExecStart=chmod a+r /sys/class/powercap/intel-rapl:0/energy_uj
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable sysfs-read-powercap-intel.service
