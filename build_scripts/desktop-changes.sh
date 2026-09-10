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

        # Bazzite bakes Lutris into the default panel launchers and menu
        # favorites. Strip those entries wherever the package is removed so
        # nothing points at a missing .desktop file.
        strip_lutris_favorite() {
            local file=$1 expr=$2
            if [[ ! -f ${file} ]]; then
                echo "Skipping Lutris favorite cleanup, not found: ${file}"
                return 0
            fi
            sed -i "${expr}" "${file}"
            if grep -q 'net\.lutris\.Lutris\.desktop' "${file}"; then
                echo "ERROR: Lutris still referenced in ${file}" >&2
                exit 1
            fi
        }

        if [[ ${IMAGE} =~ gnome ]]; then
            # gnome-desktop3 is used by the GNOME desktop itself here, not just lutris
            echo "Removing lutris..."
            $DNF -y remove lutris

            strip_lutris_favorite \
                /usr/share/glib-2.0/schemas/zz0-01-bazzite-desktop-silverblue-dash.gschema.override \
                "s/'net\.lutris\.Lutris\.desktop', //"
            glib-compile-schemas /usr/share/glib-2.0/schemas
        else
            echo "Removing lutris and its gnome-desktop3 dependency..."
            $DNF -y remove lutris gnome-desktop3

            strip_lutris_favorite \
                /usr/share/kde-settings/kde-profile/default/xdg/kicker-extra-favoritesrc \
                's/net\.lutris\.Lutris\.desktop;//'
            for tpl in \
                /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js \
                /usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/bazzite-pins.js; do
                strip_lutris_favorite "${tpl}" \
                    '/applications:net\.lutris\.Lutris\.desktop/d'
            done
        fi
    fi

    /ctx/build_scripts/common-hygiene.sh
fi
