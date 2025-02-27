#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Tweaking existing desktop config..."

if [[ ${IMAGE} =~ bluefin|bazzite ]]; then
    # ensure /opt and /usr/local are proper
    if [[ ! -h /opt ]]; then
        rm -fr /opt
	mkdir -p /var/opt
	ln -s /var/opt /opt
    fi
    if [[ ! -h /usr/local ]]; then
        rm -fr /usr/local
	ln -s /var/usrlocal /usr/local
    fi

    # copy system files
    rsync -rvK /ctx/system_files/silverblue/ /

    # remove solaar and input leap, if installed
    $DNF -y remove input-leap p7zip p7zip-plugins podman-compose rocm-hip rocm-opencl rocm-smi solaar virt-manager virt-viewer virt-v2v

    # custom gnome overrides
    mkdir -p /tmp/ublue-schema-test &&
        find /usr/share/glib-2.0/schemas/ -type f ! -name "*.gschema.override" -exec cp {} /tmp/ublue-schema-test/ \; &&
        cp /usr/share/glib-2.0/schemas/*-bos-modifications.gschema.override /tmp/ublue-schema-test/ &&
        echo "Running error test for bos gschema override. Aborting if failed." &&
        glib-compile-schemas --strict /tmp/ublue-schema-test || exit 1 &&
        echo "Compiling gschema to include bos setting overrides" &&
        glib-compile-schemas /usr/share/glib-2.0/schemas &>/dev/null
fi
