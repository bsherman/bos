#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Tweaking existing desktop config..."

if [[ ${IMAGE} =~ bluefin|bazzite ]]; then
    # copy system files
    rsync -rvK /ctx/system_files/silverblue/ /

    # custom gnome overrides
    mkdir -p /tmp/ublue-schema-test &&
        find /usr/share/glib-2.0/schemas/ -type f ! -name "*.gschema.override" -exec cp {} /tmp/ublue-schema-test/ \; &&
        cp /usr/share/glib-2.0/schemas/*-bos-modifications.gschema.override /tmp/ublue-schema-test/ &&
        echo "Running error test for bos gschema override. Aborting if failed." &&
        glib-compile-schemas --strict /tmp/ublue-schema-test || exit 1 &&
        echo "Compiling gschema to include bos setting overrides" &&
        glib-compile-schemas /usr/share/glib-2.0/schemas &>/dev/null

    if [[ ${IMAGE} =~ bluefin ]]; then
      # remove bluefin provided Inter fonts since we add the RPM
      rm -vfr /usr/share/fonts/inter

      # disable bluefin provided brew, and remove pre-install
      systemctl disable brew-setup.service
      systemctl disable brew-upgrade.timer
      systemctl disable brew-update.timer
      rm -vfr /home/linuxbrew
    fi
fi
