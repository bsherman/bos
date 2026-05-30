#!/usr/bin/bash

set -eou pipefail

#Common
echo "::group:: ===Remove CLI Wrap==="
/ctx/build_scripts/remove-cliwrap.sh
echo "::endgroup::"

# Changes
case "${IMAGE}" in
"bluefin"*)
    echo "::group:: ===Desktop Changes==="
    /ctx/build_scripts/desktop-changes.sh
    echo "::endgroup::"

    echo "::group:: ===Desktop Packages==="
    /ctx/build_scripts/desktop-packages.sh
    echo "::endgroup::"
    ;;
"bazzite"*)
    echo "::group:: ===Desktop Changes==="
    /ctx/build_scripts/desktop-changes.sh
    echo "::endgroup::"

    echo "::group:: ===Desktop Packages==="
    /ctx/build_scripts/desktop-packages.sh
    echo "::endgroup::"
    ;;
"ucore"*)
    echo "::group:: ===Server Changes==="
    /ctx/build_scripts/server-changes.sh
    echo "::endgroup::"
    ;;
esac

# Common
echo "::group:: ===Server Packages==="
/ctx/build_scripts/server-packages.sh
echo "::endgroup::"

#echo "::group:: ===Branding Changes==="
#/ctx/build_scripts/branding.sh
#echo "::endgroup::"

echo "::group:: ===Shared Changes==="
/ctx/build_scripts/shared-changes.sh
echo "::endgroup::"

echo "::group:: ===Container Signing==="
/ctx/build_scripts/signing.sh
echo "::endgroup::"

# Clean Up
echo "::group:: ===Cleanup==="
/ctx/build_scripts/cleanup.sh
echo "::endgroup::"
