#!/usr/bin/bash

set -eoux pipefail

# OBS-VKcapture
curl -Lo /etc/yum.repos.d/_copr_kylegospo-obs-vkcapture.repo \
    https://copr.fedorainfracloud.org/coprs/kylegospo/obs-vkcapture/repo/fedora-"$(rpm -E %fedora)"/kylegospo-obs-vkcapture-fedora-"$(rpm -E %fedora)".repo?arch=x86_64

# Bazzite Repos
curl -Lo /etc/yum.repos.d/_copr_kylegospo-bazzite.repo \
    https://copr.fedorainfracloud.org/coprs/kylegospo/bazzite/repo/fedora-"$(rpm -E %fedora)"/kylegospo-bazzite-fedora-"$(rpm -E %fedora)".repo
curl -Lo /etc/yum.repos.d/_copr_kylegospo-bazzite-multilib.repo \
    https://copr.fedorainfracloud.org/coprs/kylegospo/bazzite-multilib/repo/fedora-"$(rpm -E %fedora)"/kylegospo-bazzite-multilib-fedora-"$(rpm -E %fedora)".repo?arch=x86_64
curl -Lo /etc/yum.repos.d/_copr_kylegospo-latencyflex.repo \
    https://copr.fedorainfracloud.org/coprs/kylegospo/LatencyFleX/repo/fedora-"$(rpm -E %fedora)"/kylegospo-LatencyFleX-fedora-"$(rpm -E %fedora)".repo

sed -i "0,/enabled=0/{s/enabled=0/enabled=1/}" /etc/yum.repos.d/negativo17-fedora-multimedia.repo

# TODO: pull the following scripts directly from m2os
/ctx/build_files/build-fix.sh
/ctx/build_files/steam.sh

sed -i "s@enabled=1@enabled=0@" /etc/yum.repos.d/negativo17-fedora-multimedia.repo

# disable the Repos we pulled in above
sed -i "s@enabled=1@enabled=0@" /etc/yum.repos.d/_copr*.repo
