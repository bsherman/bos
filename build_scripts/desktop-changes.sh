#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Tweaking existing desktop config..."

if [[ ${IMAGE} =~ bluefin|bazzite ]]; then
    # ensure /opt and /usr/local are proper
    mkdir -p /var/opt /var/usrlocal

    if [[ ! -h /opt ]]; then
        rm -fr /opt
        ln -s /var/opt /opt
    fi
    if [[ ! -h /usr/local ]]; then
        # shellcheck disable=SC2114
        rm -fr /usr/local
        ln -s /var/usrlocal /usr/local
    fi

    # remove solaar and input leap, if installed
    # NOTE: these no longer seem to be installed on bazzite
    $DNF -y remove input-leap solaar virt-manager virt-viewer virt-v2v

    if [[ ${IMAGE} =~ bazzite ]]; then
        # Bazzite KDE variants swap kde-partitionmanager for gnome-disk-utility
        # upstream; restore kde-partitionmanager for the KDE experience.
        if [[ ! ${IMAGE} =~ gnome ]]; then
            echo "Restoring kde-partitionmanager..."
            $DNF -y remove gnome-disk-utility
            # kde-partitionmanager and kpmcore are released in lockstep
            # upstream (matching KDE Gear version numbers), but
            # kde-partitionmanager's RPM only requires the libkpmcore soname,
            # not a version -- so dnf can pair a newer kde-partitionmanager
            # with the older kpmcore already in the base image, producing an
            # ABI mismatch (undefined symbol at runtime). Pin
            # kde-partitionmanager to whatever kpmcore version is already
            # installed to keep them matched.
            kpmcore_ver=$(rpm -q --qf '%{version}-%{release}' kpmcore 2>/dev/null || true)
            if [[ -n ${kpmcore_ver} ]]; then
                $DNF -y install "kde-partitionmanager-${kpmcore_ver}"
            else
                $DNF -y install kde-partitionmanager
            fi
        fi

        if [[ ${IMAGE} =~ gnome ]]; then
            # gnome-desktop3 is used by the GNOME desktop itself here, not just lutris
            echo "Removing lutris..."
            $DNF -y remove lutris
        else
            echo "Removing lutris and its gnome-desktop3 dependency..."
            $DNF -y remove lutris gnome-desktop3
        fi
    fi

    /ctx/build_scripts/common-hygiene.sh
fi
