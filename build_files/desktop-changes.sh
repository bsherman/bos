#!/usr/bin/env bash

set -euox pipefail

echo "Tweaking existing desktop config..."

if [[ ${SOURCE_IMAGE} =~ bluefin ]] || [[ ${SOURCE_IMAGE} =~ bazzite-gnome ]]; then
  rsync -rvK /ctx/system_files/silverblue/ /
  # custom gnome overrides
  mkdir -p /tmp/ublue-schema-test && \
  find /usr/share/glib-2.0/schemas/ -type f ! -name "*.gschema.override" -exec cp {} /tmp/ublue-schema-test/ \; && \
  cp /usr/share/glib-2.0/schemas/*-bos-modifications.gschema.override /tmp/ublue-schema-test/ && \
  echo "Running error test for bos gschema override. Aborting if failed." && \
  glib-compile-schemas --strict /tmp/ublue-schema-test || exit 1 && \
  echo "Compiling gschema to include bos setting overrides" && \
  glib-compile-schemas /usr/share/glib-2.0/schemas &>/dev/null
fi