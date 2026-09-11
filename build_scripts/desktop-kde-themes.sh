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

echo "Installing Qlassy theme..."

# Pin: bsherman/qlassy-theme release v0.1.0.
qlassy_ref="v0.1.0"
qlassy_sha256="00950b507e0d90b043045cbaa1ac09effb0b228942a13456d9ba98a5663b9be3"

# Reuse the Qogir ${workdir}; its EXIT trap is still armed.
qlassy_tarball="${workdir}/qlassy.tar.gz"
/ctx/build_scripts/github-release-url.sh \
    bsherman/qlassy-theme \
    --snapshot "${qlassy_ref}" \
    -o "${qlassy_tarball}" \
    --sha256 "${qlassy_sha256}"

qlassy_extract="${workdir}/qlassy"
mkdir -p "${qlassy_extract}"
tar -xzf "${qlassy_tarball}" -C "${qlassy_extract}"
mapfile -t qlassy_dirs < <(
    find "${qlassy_extract}" -mindepth 1 -maxdepth 1 -type d
)
if ((${#qlassy_dirs[@]} != 1)); then
    echo "ERROR: expected one Qlassy source dir, found ${#qlassy_dirs[@]}" >&2
    exit 1
fi

# env -u guards against a narrowed XDG_DATA_DIRS hiding /usr/share from
# install.sh's Klassy/Qogir prerequisite checks.
env -u XDG_DATA_DIRS HOME="${HOME:-/root}" \
    "${qlassy_dirs[0]}/install.sh" --system

for variant in light dark; do
    pkg="/usr/share/plasma/look-and-feel/dev.bsherman.qlassy.${variant}"
    [[ -f "${pkg}/metadata.json" ]]
    [[ -f "${pkg}/contents/defaults" ]]
    [[ -f "${pkg}/contents/previews/preview.png" ]]
    [[ -f "${pkg}/contents/previews/fullscreenpreview.jpg" ]]
    grep -q '^BorderSize=None$' "${pkg}/contents/defaults"
done

echo "Defaulting Klassy Defenestrated 11 styling in /etc/skel..."

# The layout keys ship in each theme's contents/defaults, but the finer
# Klassy decoration styling only exists in klassyrc. Generate it headlessly
# into a staging HOME and seed /etc/skel with it. No marker file: a later
# user-run qlassy-theme/install.sh re-applies the preset idempotently.
skel_stage="${workdir}/skel"
dbus_wrap=()
if command -v dbus-run-session >/dev/null; then
    dbus_wrap=(dbus-run-session --)
fi

env -i PATH="${PATH}" \
    HOME="${skel_stage}" \
    XDG_CONFIG_HOME="${skel_stage}/.config" \
    XDG_DATA_HOME="${skel_stage}/.local/share" \
    XDG_CACHE_HOME="${skel_stage}/.cache" \
    XDG_STATE_HOME="${skel_stage}/.local/state" \
    QT_QPA_PLATFORM=offscreen \
    timeout 120 "${dbus_wrap[@]}" \
    klassy-settings --load-windeco-preset "Defenestrated 11"

klassyrc="${skel_stage}/.config/klassy/klassyrc"
[[ -f "${klassyrc}" ]]
grep -q '^\[Windeco\]' "${klassyrc}"
# loadPresetAndSave writes only keys that differ from Klassy's own defaults,
# so ColorizeWindowOutlineWithButton=false (default true) is the reliable
# Defenestrated 11 signature; the outline-style keys match the defaults and
# are omitted. Fail closed if the headless run produced a bare skeleton.
grep -qx 'ColorizeWindowOutlineWithButton=false' "${klassyrc}"
echo "Captured klassyrc staging tree:"
find "${skel_stage}" -type f -printf '  %P\n' | sort

install -Dm0644 "${klassyrc}" /etc/skel/.config/klassy/klassyrc

# Invariants: the layout lives in each theme's contents/defaults, and the
# marker must never ship (it would make a user-run install.sh skip the
# preset). Guard against a future change that copies the whole staging tree.
[[ ! -e /etc/skel/.config/kwinrc ]]
[[ ! -e /etc/skel/.config/qlassy-theme ]]
