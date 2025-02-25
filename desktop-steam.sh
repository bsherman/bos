#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

# OBS-VKcapture
$DNF -y copr enable kylegospo/obs-vkcapture

# Bazzite Repos
$DNF -y copr enable kylegospo/bazzite
$DNF -y copr enable kylegospo/bazzite-multilib
$DNF -y copr enable kylegospo/LatencyFleX

find /etc/yum.repos.d/

sed -i "0,/enabled=0/{s/enabled=0/enabled=1/}" /etc/yum.repos.d/negativo17-fedora-multimedia.repo

# TODO: pull the following scripts directly from m2os
/ctx/steam.sh

sed -i "s@enabled=1@enabled=0@" /etc/yum.repos.d/negativo17-fedora-multimedia.repo

# disable the Repos we pulled in above
$DNF -y copr disable kylegospo/obs-vkcapture
$DNF -y copr disable kylegospo/bazzite
$DNF -y copr disable kylegospo/bazzite-multilib
$DNF -y copr disable kylegospo/LatencyFleX
