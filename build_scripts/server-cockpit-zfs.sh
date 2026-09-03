#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

# Proof of concept: replace the legacy, unmaintained cockpit-zfs-manager plugin
# (bundled in the ucore base image) with the newer 45Drives/cockpit-zfs plugin.
#
# Scope is intentionally narrow: the Cockpit UI plugin only. We do NOT install
# python3-libzfs (TrueNAS-specific py-libzfs, not packaged for Fedora; the plugin
# falls back to zpool/zfs CLI) nor the project's system_files (ZED notify hooks
# and the storage-alert systemd timer). A cleaner ucore-native implementation is
# expected to follow.

CZFS_VERSION="v1.3.0"

# Remove the legacy cockpit-zfs-manager plugin bundled in the ucore base image.
rm -vfr /usr/share/cockpit/zfs \
    /usr/share/polkit-1/actions/*zfs* \
    /usr/share/polkit-1/rules.d/*zfs* \
    /usr/share/polkit-1/rules.d/*zpool*

# Build toolchain for the Node/Yarn plugin build. jq is left in place because
# later build steps (github-release-install.sh) depend on it.
$DNF install -y nodejs npm git make moreutils

# Install yarn into a throwaway prefix on PATH. On bootc/OSTree images both
# /usr/local (-> /var/usrlocal) and /root (-> /var/roothome) are symlinks whose
# targets do not exist at build time, so npm's default global prefix and yarn's
# HOME-based cache both fail with ENOTDIR. Redirect HOME and the npm prefix to a
# writable temp dir.
NPM_GLOBAL="$(mktemp -d)"
export HOME="${NPM_GLOBAL}"
export NPM_CONFIG_PREFIX="${NPM_GLOBAL}"
export NPM_CONFIG_CACHE="${NPM_GLOBAL}/cache"
export PATH="${NPM_GLOBAL}/bin:${PATH}"
npm install -g yarn

BUILD_DIR="$(mktemp -d)"
git clone --branch "${CZFS_VERSION}" --depth 1 --recurse-submodules \
    https://github.com/45Drives/cockpit-zfs.git "${BUILD_DIR}"

# Build the plugin, then install ONLY the Cockpit UI. The Makefile's top-level
# `install` target also runs system-files-install (ZED hooks + systemd timer),
# so we call the per-plugin target directly to keep scope to the UI.
make -C "${BUILD_DIR}"
make -C "${BUILD_DIR}" plugin-install-zfs

# Drop the build-only toolchain and sources/caches to keep the layer lean.
$DNF remove -y nodejs npm moreutils
rm -rf "${BUILD_DIR}" "${NPM_GLOBAL}"
