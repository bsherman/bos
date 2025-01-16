#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

# OBS-VKcapture
dnf5 -y copr enable kylegospo/obs-vkcapture

# Bazzite Repos
dnf5 -y copr enable kylegospo/bazzite
dnf5 -y copr enable kylegospo/bazzite-multilib
dnf5 -y copr enable kylegospo/LatencyFleX

find /etc/yum.repos.d/

sed -i "0,/enabled=0/{s/enabled=0/enabled=1/}" /etc/yum.repos.d/negativo17-fedora-multimedia.repo

# TODO: pull the following scripts directly from m2os
/ctx/steam.sh

sed -i "s@enabled=1@enabled=0@" /etc/yum.repos.d/negativo17-fedora-multimedia.repo

# disable the Repos we pulled in above
sed -i "s@enabled=1@enabled=0@" /etc/yum.repos.d/_copr*.repo
