#!/usr/bin/bash
#shellcheck disable=SC2115

set ${SET_X:+-x} -eou pipefail

repos=(
    charm.repo
    docker-ce.repo
    fedora-cisco-openh264.repo
    fedora-updates.repo
    fedora-updates-archive.repo
    fedora-updates-testing.repo
    gh-cli.repo
    google-chrome.repo
    negativo17-fedora-multimedia.repo
    negativo17-fedora-nvidia.repo
    nvidia-container-toolkit.repo
    rpm-fusion-nonfree-nvidia-driver.repo
    rpm-fusion-nonfree-steam.repo
    tailscale.repo
    terra.repo
    ublue-os-packages-fedora-"$(rpm -E %fedora)".repo
    ublue-os-packages-epel-"$(rpm -E %centos)".repo
    ublue-os-staging-fedora-"$(rpm -E %fedora)".repo
    ublue-os-staging-epel-"$(rpm -E %centos)".repo
    vscode.repo
)

for repo in "${repos[@]}"; do
    if [[ -f "/etc/yum.repos.d/$repo" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "/etc/yum.repos.d/$repo"
    fi
done

if [[ ! "${IMAGE}" =~ ucore ]]; then
    coprs=()
    mapfile -t coprs <<<"$(find /etc/yum.repos.d/_copr*.repo)"
    for copr in "${coprs[@]}"; do
        sed -i 's@enabled=1@enabled=0@g' "$copr"
    done
fi

$DNF clean all

rm -rf /tmp/*
rm -rf /var/*
ostree container commit
mkdir -p /tmp
mkdir -p /var/tmp && chmod -R 1777 /var/tmp
