#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

# Klassy is a Plasma plugin; Qogir is an icon theme. Skip GNOME/Bluefin.
if [[ ! ${IMAGE} =~ bazzite ]] || [[ ${IMAGE} =~ gnome ]]; then
    echo "Skipping KDE themes on ${IMAGE}"
    exit 0
fi

echo "Installing Klassy..."

fedora_version="$(rpm -E %fedora)"
obs_base="https://download.opensuse.org/repositories/home:/paulmcauley"
repo_url="${obs_base}/Fedora_${fedora_version}/home:paulmcauley.repo"
repo_file="/etc/yum.repos.d/home_paulmcauley.repo"

if ! curl --fail --retry 5 --retry-delay 5 --retry-all-errors \
    -sL -o "${repo_file}" "${repo_url}"; then
    echo "ERROR: Klassy OBS repo missing for Fedora ${fedora_version}" >&2
    echo "${repo_url}" >&2
    exit 1
fi

# Fail closed if OBS served a page instead of a repo file.
grep -q '^\[home_paulmcauley\]' "${repo_file}"
grep -q '^gpgcheck=1' "${repo_file}"

$DNF install -y klassy
sed -i 's@enabled=1@enabled=0@g' "${repo_file}"
rpm -q klassy

echo "Installing Qogir icon theme..."

# Pin: vinceliuice/Qogir-icon-theme master @ 2025-11-04.
# -c dark maps to Light in upstream install.sh; -c all is required.
qogir_sha="c633057ba0d27a504b3255144071c9691ed0264a"
qogir_sha256="4e13a959ddae29c95eac6d339217565df88e5a1ff3dfdfc1c1dc9bce83a3719a"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT
tarball="${workdir}/qogir.tar.gz"

/ctx/build_scripts/github-release-url.sh \
    vinceliuice/Qogir-icon-theme \
    --snapshot "${qogir_sha}" \
    -o "${tarball}" \
    --sha256 "${qogir_sha256}"

tar -xzf "${tarball}" -C "${workdir}"
mapfile -t qogir_dirs < <(
    find "${workdir}" -mindepth 1 -maxdepth 1 -type d
)
if ((${#qogir_dirs[@]} != 1)); then
    echo "ERROR: expected one Qogir source dir, found ${#qogir_dirs[@]}" >&2
    exit 1
fi
src="${qogir_dirs[0]}"
mkdir -p /usr/share/icons
"${src}/install.sh" -d /usr/share/icons -t default -c all

[[ -f /usr/share/icons/Qogir/index.theme ]]
[[ -f /usr/share/icons/Qogir-Dark/index.theme ]]
[[ -f /usr/share/icons/Qogir-Light/index.theme ]]
