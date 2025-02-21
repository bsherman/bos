#!/usr/bin/bash

set -eou pipefail

#Common
echo "::group:: ===Remove CLI Wrap==="
/ctx/remove-cliwrap.sh
echo "::endgroup::"

# Changes
case "${IMAGE}" in
"aurora"* | "bluefin"*)
    echo "::group:: ===Desktop Changes==="
    /ctx/desktop-changes.sh
    echo "::endgroup::"

    echo "::group:: ===Steam Packages==="
    /ctx/desktop-steam.sh
    echo "::endgroup::"

    echo "::group:: ===Desktop Packages==="
    /ctx/desktop-packages.sh
    echo "::endgroup::"
    ;;
"bazzite"*)
    echo "::group:: ===Desktop Changes==="
    /ctx/desktop-changes.sh
    echo "::endgroup::"

    echo "::group:: ===Desktop Packages==="
    /ctx/desktop-packages.sh
    echo "::endgroup::"
    ;;
"ucore"*)
    echo "::group:: ===Server Changes==="
    /ctx/server-changes.sh
    echo "::endgroup::"
    ;;
esac

# Common
echo "::group:: ===Server Packages==="
/ctx/server-packages.sh
echo "::endgroup::"

echo "::group:: ===Branding Changes==="
/ctx/branding.sh
echo "::endgroup::"

echo "::group:: ===Container Signing==="
/ctx/signing.sh
echo "::endgroup::"

# Clean Up
echo "::group:: ===Cleanup==="
/ctx/cleanup.sh
echo "::endgroup::"
