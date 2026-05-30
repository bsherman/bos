repo_image_name_styled := "bOS"
repo_image_name := "bos"
repo_name := "bsherman"
username := "bsherman"

# Image definitions now live in images.yaml (single source of truth).
# See `just list-images` and `just generate-ci-matrix`.
export SUDO_DISPLAY := if `if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then echo true; fi` == "true" { "true" } else { "false" }
export SUDOIF := if `id -u` == "0" { "" } else if SUDO_DISPLAY == "true" { "sudo --askpass" } else { "sudo" }
export SET_X := if `id -u` == "0" { "1" } else { env('SET_X', '') }
export PODMAN := if path_exists("/usr/bin/podman") == "true" { env("PODMAN", "/usr/bin/podman") } else if path_exists("/usr/bin/docker") == "true" { env("PODMAN", "docker") } else { env("PODMAN", "exit 1 ; ") }
export PULL_POLICY := if PODMAN =~ "docker" { "missing" } else { "newer" }
chunkah_image := env("CHUNKAH_IMAGE", "quay.io/coreos/chunkah:v0.5.0")

# Use the spec-compliant merge anchor behavior to avoid warnings when using
# <<: anchors in images.yaml. This will become the default in late 2025.
YQ := "yq --yaml-fix-merge-anchor-to-spec"

[private]
default:
    @just --list

# List defined images (optionally filtered by flavor, e.g. `just list-images Server`)
[group('Image')]
list-images flavor="":
    #!/usr/bin/env bash
    if [[ -n "{{ flavor }}" ]]; then
        {{ YQ }} -r '.flavors["{{ flavor }}"][] | .tag' images.yaml
    else
        {{ YQ }} -r '.flavors[][] | .tag' images.yaml
    fi

# Generate the matrix JSON expected by GitHub Actions for a given flavor.
# Example: just generate-ci-matrix Server
[group('CI')]
generate-ci-matrix flavor:
    #!/usr/bin/env bash
    set -euo pipefail

    entries=$({{ YQ }} -r '
        .flavors["{{ flavor }}"][] 
        | select((.ci_enabled // false) == true) 
        | .tag + " " + ((.multi_arch // false) | tostring)
    ' images.yaml)

    result="[]"
    while read -r tag multi; do
        [[ -z "$tag" ]] && continue
        if [[ "$multi" == "true" ]]; then
            result=$(echo "$result" | jq -c \
                --arg img "$tag" \
                '. + [
                    {image: $img, arch: "x86_64", runner: "ubuntu-24.04"},
                    {image: $img, arch: "aarch64", runner: "ubuntu-24.04-arm"}
                ]')
        else
            result=$(echo "$result" | jq -c \
                --arg img "$tag" \
                '. + [{image: $img, arch: "x86_64", runner: "ubuntu-24.04"}]')
        fi
    done <<< "$entries"

    echo "$result"

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/env bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Checking syntax: $file"
        just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/env bash
    find . -type f -name "*.just" | while read -r file; do
        echo "Checking syntax: $file"
        just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Cleanup
[group('Utility')]
clean:
    #!/usr/bin/env bash
    set -euox pipefail
    touch {{ repo_image_name }}_
    {{ SUDOIF }} find {{ repo_image_name }}_* -type d -exec chmod 0755 {} \;
    {{ SUDOIF }} find {{ repo_image_name }}_* -type f -exec chmod 0644 {} \;
    find {{ repo_image_name }}_* -maxdepth 0 -exec rm -rf {} \;
    rm -f output*.env changelog*.md version.txt previous.manifest.json

# Build Image
[group('Image')]
build image="bluefin":
    #!/usr/bin/env bash
    echo "::group:: Container Build Prep"
    set ${SET_X:+-x} -eou pipefail

    if ! {{ YQ }} -e '.flavors[][] | select(.tag == "{{ image }}")' images.yaml >/dev/null 2>&1; then
        echo "Error: Unknown image '{{ image }}'. Run 'just list-images' to see options."
        exit 1
    fi

    BASE_IMAGE=$({{ YQ }} -r '.flavors[][] | select(.tag == "{{ image }}") | .base_image' images.yaml)

    # Read build metadata from images.yaml (single source of truth)
    BASE_TAG=$({{ YQ }} -r '.flavors[][] | select(.tag == "{{ image }}") | .base_tag // "stable"' images.yaml)
    DIST_ABRV=$({{ YQ }} -r '.flavors[][] | select(.tag == "{{ image }}") | .dist_abrv // "fc"' images.yaml)
    DNF=$({{ YQ }} -r '.flavors[][] | select(.tag == "{{ image }}") | .dnf // "dnf5"' images.yaml)

    # Note: For the ucore family, base_image and base_tag are read directly from images.yaml.
    # No extra swapping is needed after the rename.

    BUILD_ARGS=()
    TMPFILES=()
    cleanup_tmpfiles() {
        rm -f "${TMPFILES[@]}"
    }
    trap cleanup_tmpfiles EXIT

    case "{{ image }}" in
    "ucore"*)
        just verify-container "${BASE_IMAGE}":"${BASE_TAG}"
        fedora_version="$(skopeo inspect docker://ghcr.io/ublue-os/"${BASE_IMAGE}":"${BASE_TAG}" | jq -r '.Labels["org.opencontainers.image.version"]' | grep -oP '^\K[0-9]+')"
        ;;
    *)
        just verify-container "${BASE_IMAGE}":"${BASE_TAG}"
        inspect_json="$(mktemp -t inspect-{{ image }}.XXXXXXXXXX.json)"
        TMPFILES+=("${inspect_json}")
        skopeo inspect docker://ghcr.io/ublue-os/"${BASE_IMAGE}":"${BASE_TAG}" > "${inspect_json}"
        fedora_version="$(jq -r '.Labels["org.opencontainers.image.version"]' < "${inspect_json}" | grep -oP '^\K[0-9]+')"
        ;;
    esac

    VERSION="{{ image }}-${fedora_version}.$(date +%Y%m%d)"
    repotags_json="$(mktemp -t repotags.XXXXXXXXXX.json)"
    TMPFILES+=("${repotags_json}")
    skopeo list-tags docker://ghcr.io/{{ repo_name }}/{{ repo_image_name }} > "${repotags_json}"
    if [[ $(jq "any(.Tags[]; . == \"$VERSION\" or startswith(\"${VERSION}-\"))" < "${repotags_json}") == "true" ]]; then
        POINT="1"
        while jq -e "any(.Tags[]; . == \"$VERSION.$POINT\" or startswith(\"${VERSION}.${POINT}-\"))" < "${repotags_json}"
        do
            (( POINT++ ))
        done
    fi
    if [[ -n "${POINT:-}" ]]; then
        VERSION="${VERSION}.$POINT"
    fi
    BUILD_ARGS+=("--file" "Containerfile")
    BUILD_ARGS+=("--label" "org.opencontainers.image.title={{ repo_image_name_styled }}")
    BUILD_ARGS+=("--label" "org.opencontainers.image.version=$VERSION")
    BUILD_ARGS+=("--label" "org.opencontainers.image.description={{ repo_image_name }} is my OCI image built from ublue projects. It mainly extends them for my uses.")
    BUILD_ARGS+=("--build-arg" "IMAGE={{ image }}")
    BUILD_ARGS+=("--build-arg" "BASE_IMAGE=$BASE_IMAGE")
    BUILD_ARGS+=("--build-arg" "BASE_TAG=$BASE_TAG")
    BUILD_ARGS+=("--build-arg" "SET_X=${SET_X:-}")
    BUILD_ARGS+=("--build-arg" "VERSION=$VERSION")
    BUILD_ARGS+=("--build-arg" "DNF=$DNF")
    BUILD_ARGS+=("--tag" "localhost/{{ repo_image_name }}:{{ image }}")
    if [[ {{ PODMAN }} =~ podman ]]; then
        BUILD_ARGS+=("--pull=newer")
    elif [[ {{ PODMAN }} =~ docker ]]; then
        BUILD_ARGS+=("--pull=missing")
        if [[ "${TERM}" == "dumb" ]]; then
            BUILD_ARGS+=("--progress" "plain")
        fi
    fi
    echo "::endgroup::"

    echo "::group:: Container Build"
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        BUILD_ARGS+=("--secret" "id=GITHUB_TOKEN,env=GITHUB_TOKEN")
    fi
    {{ PODMAN }} build "${BUILD_ARGS[@]}" .
    echo "::endgroup::"

    echo "::group:: Tag Image with Version"
    {{ PODMAN }} tag localhost/{{ repo_image_name }}:{{ image }} localhost/{{ repo_image_name }}:"${VERSION}"
    {{ PODMAN }} images
    echo "::endgroup::"

    {{ PODMAN }} rmi ghcr.io/ublue-os/"${BASE_IMAGE}":"${BASE_TAG}"

# Chunk Image
[group('Image')]
chunk image="bluefin":
    #!/usr/bin/env bash
    echo "::group:: Chunk Build Prep"
    set ${SET_X:+-x} -eou pipefail

    if [[ ! {{ PODMAN }} =~ podman ]]; then
        echo "Chunking only supported with podman. Exiting..."
        exit 0
    fi

    ID=$({{ PODMAN }} images --filter reference=localhost/{{ repo_image_name }}:{{ image }} --format "'{{ '{{.ID}}' }}'")

    if [[ -z "$ID" ]]; then
        just build {{ image }}
    fi

    OUT_NAME="{{ repo_image_name }}_{{ image }}"
    VERSION="$({{ PODMAN }} inspect localhost/{{ repo_image_name }}:{{ image }} | jq -r '.[]["Config"]["Labels"]["org.opencontainers.image.version"]')"
    CONFIG_JSON="${OUT_NAME}.config.json"
    OCI_ARCHIVE="${OUT_NAME}.oci"
    rm -f "${CONFIG_JSON}" "${OCI_ARCHIVE}"
    {{ PODMAN }} inspect localhost/{{ repo_image_name }}:{{ image }} | tee "${CONFIG_JSON}" >/dev/null
    echo "::endgroup::"

    echo "::group:: Chunk Image"
    {{ PODMAN }} run --rm \
        --pull={{ PULL_POLICY }} \
        --security-opt label=disable \
        --mount type=image,src=localhost/{{ repo_image_name }}:{{ image }},destination=/chunkah \
        --volume "$PWD:/workspace" \
        --volume "$PWD/${CONFIG_JSON}:/config.json:ro" \
        {{ chunkah_image }} \
        build \
        --config /config.json \
        --prune /sysroot/ \
        --max-layers 128 \
        --label ostree.commit- \
        --label ostree.final-diffid- \
        --tag localhost/{{ repo_image_name }}:{{ image }} \
        --output "/workspace/${OCI_ARCHIVE}"
    echo "::endgroup::"

    echo "::group:: Cleanup"
    rm -f "${CONFIG_JSON}"
    printf '%s\n' "$VERSION" > version.txt
    chmod 0644 "${OCI_ARCHIVE}" version.txt || true
    {{ PODMAN }} rmi localhost/{{ repo_image_name }}:{{ image }}
    echo "::endgroup::"

# Load Chunked OCI into Podman and Tag
[group('Image')]
load-chunked-oci image="bluefin":
    #!/usr/bin/env bash
    echo "::group:: Load Chunked OCI"
    set ${SET_X:+-x} -eou pipefail
    echo "Loading chunked OCI archive {{ repo_image_name }}_{{ image }}.oci into Podman and applying tags"
    {{ PODMAN }} load --input {{ repo_image_name }}_{{ image }}.oci
    VERSION=$({{ PODMAN }} inspect localhost/{{ repo_image_name }}:{{ image }} | jq -r '.[]["Config"]["Labels"]["org.opencontainers.image.version"]')
    {{ PODMAN }} tag localhost/{{ repo_image_name }}:{{ image }} localhost/{{ repo_image_name }}:"${VERSION}"
    {{ PODMAN }} images
    rm -f {{ repo_image_name }}_{{ image }}.oci version.txt
    echo "::endgroup::"

# Get Tags
get-tags image="bluefin":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    VERSION=$({{ PODMAN }} inspect {{ repo_image_name }}:{{ image }} | jq -r '.[]["Config"]["Labels"]["org.opencontainers.image.version"]')
    echo "{{ image }} $VERSION"

# Build ISO
[group('ISO')]
build-iso image="bluefin" ghcr="0" clean="0":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    # Validate
    if ! {{ YQ }} -e '.flavors[][] | select(.tag == "{{ image }}")' images.yaml >/dev/null 2>&1; then
        echo "Error: Unknown image '{{ image }}'. Run 'just list-images' to see options."
        exit 1
    fi

    # Verify ISO Build Container
    just verify-container "build-container-installer" "ghcr.io/jasonn3" "https://raw.githubusercontent.com/JasonN3/build-container-installer/refs/heads/main/cosign.pub"

    mkdir -p {{ repo_image_name }}_build/{lorax_templates,flatpak-refs-{{ image }},output}
    echo 'append etc/anaconda/profile.d/fedora-kinoite.conf "\\n[User Interface]\\nhidden_spokes =\\n    PasswordSpoke"' \
         > {{ repo_image_name }}_build/lorax_templates/remove_root_password_prompt.tmpl

    # Build from GHCR or localhost
    if [[ "{{ ghcr }}" == "1" ]]; then
        IMAGE_FULL=ghcr.io/{{ repo_name }}/{{ repo_image_name }}:{{ image }}
        IMAGE_REPO=ghcr.io/{{ repo_name }}
        # Verify Container for ISO
        just verify-container "{{ repo_image_name }}:{{ image }}" "${IMAGE_REPO}" "https://raw.githubusercontent.com/{{ repo_name }}/{{ repo_image_name }}/refs/heads/main/cosign.pub"
        {{ PODMAN }} pull "${IMAGE_FULL}"
        TEMPLATES=(
            /github/workspace/{{ repo_image_name }}_build/lorax_templates/remove_root_password_prompt.tmpl
        )
    else
        IMAGE_FULL=localhost/{{ repo_image_name }}:{{ image }}
        IMAGE_REPO=localhost
        ID=$({{ PODMAN }} images --filter reference=${IMAGE_FULL} --format "'{{ '{{.ID}}' }}'")
        if [[ -z "$ID" ]]; then
            just build {{ image }}
        fi
        TEMPLATES=(
            /github/workspace/{{ repo_image_name }}_build/lorax_templates/remove_root_password_prompt.tmpl
        )
    fi

    # Check if ISO already exists. Remove it.
    if [[ -f "{{ repo_image_name }}_build/output/{{ image }}.iso" || -f "{{ repo_image_name }}_build/output/{{ image }}.iso-CHECKSUM" ]]; then
        rm -f {{ repo_image_name }}_build/output/{{ image }}.iso*
    fi

    # Load image into rootful podman
    if [[ "${UID}" -gt "0" && ! {{ PODMAN }} =~ docker ]]; then
        COPYTMP="$(mktemp -p "${PWD}" -d -t podman_scp.XXXXXXXXXX)"
        {{ SUDOIF }} TMPDIR="${COPYTMP}" {{ PODMAN }} image scp "${UID}"@localhost::"${IMAGE_FULL}" root@localhost::"${IMAGE_FULL}"
        rm -rf "${COPYTMP}"
    fi

    # Generate Flatpak List
    TEMP_FLATPAK_INSTALL_DIR="$(mktemp -d -p /tmp flatpak-XXXXX)"
    FLATPAK_REFS_DIR="{{ repo_image_name }}_build/flatpak-refs-{{ image }}"
    FLATPAK_REFS_DIR_ABS="$(realpath ${FLATPAK_REFS_DIR})"
    mkdir -p "${FLATPAK_REFS_DIR_ABS}"
    case "{{ image }}" in
    *"bazzite-gnome"*)
        FLATPAK_LIST_URL="https://raw.githubusercontent.com/ublue-os/bazzite/refs/heads/main/installer/gnome_flatpaks/flatpaks"
    ;;
    *"bazzite"*)
        FLATPAK_LIST_URL="https://raw.githubusercontent.com/ublue-os/bazzite/refs/heads/main/installer/kde_flatpaks/flatpaks"
    ;;
    *"bluefin"*)
        FLATPAK_LIST_URL="https://raw.githubusercontent.com/ublue-os/bluefin/refs/heads/main/bluefin_flatpaks/flatpaks"
    ;;
    esac
    curl -Lo "${FLATPAK_REFS_DIR_ABS}"/flatpaks.txt "${FLATPAK_LIST_URL}"
    ADDITIONAL_FLATPAKS=(
        app/com.discordapp.Discord/x86_64/stable
        app/com.spotify.Client/x86_64/stable
        app/org.gimp.GIMP/x86_64/stable
        app/org.libreoffice.LibreOffice/x86_64/stable
        app/org.prismlauncher.PrismLauncher/x86_64/stable
    )
    if [[ "{{ image }}" =~ bazzite-gnome ]]; then
        ADDITIONAL_FLATPAKS+=(app/org.gnome.World.PikaBackup/x86_64/stable)
    elif [[ "{{ image }}" =~ bluefin ]]; then
        ADDITIONAL_FLATPAKS+=(app/it.mijorus.gearlever/x86_64/stable)
    fi
    FLATPAK_REFS=()
    while IFS= read -r line; do
    FLATPAK_REFS+=("$line")
    done < "${FLATPAK_REFS_DIR}/flatpaks.txt"
    FLATPAK_REFS+=("${ADDITIONAL_FLATPAKS[@]}")
    echo "Flatpak refs: ${FLATPAK_REFS[*]}"
    # Generate installation script
    tee "${TEMP_FLATPAK_INSTALL_DIR}/install-flatpaks.sh"<<EOF
    mkdir -p /flatpak/flatpak /flatpak/triggers
    mkdir /var/tmp
    chmod -R 1777 /var/tmp
    flatpak config --system --set languages "*"
    flatpak remote-add --system flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --system -y flathub ${FLATPAK_REFS[@]}
    ostree refs --repo=\${FLATPAK_SYSTEM_DIR}/repo | grep '^deploy/' | grep -v 'org\.freedesktop\.Platform\.openh264' | sed 's/^deploy\///g' > /output/flatpaks-with-deps
    EOF
    # Create Flatpak List
    {{ SUDOIF }} {{ PODMAN }} run --rm --privileged \
    --entrypoint /bin/bash \
    -e FLATPAK_SYSTEM_DIR=/flatpak/flatpak \
    -e FLATPAK_TRIGGERS_DIR=/flatpak/triggers \
    -v "${FLATPAK_REFS_DIR_ABS}":/output \
    -v "${TEMP_FLATPAK_INSTALL_DIR}":/temp_flatpak_install_dir \
    "${IMAGE_FULL}" /temp_flatpak_install_dir/install-flatpaks.sh

    VERSION="$({{ SUDOIF }} {{ PODMAN }} inspect ${IMAGE_FULL} | jq -r '.[]["Config"]["Labels"]["org.opencontainers.image.version"]' | grep -oP '\K[0-9]+'')"
    if [[ "{{ ghcr }}" == "1" && "{{ clean }}" == "1" ]]; then
        {{ SUDOIF }} {{ PODMAN }} rmi ${IMAGE_FULL}
    fi
    # list Flatpaks
    cat "${FLATPAK_REFS_DIR}"/flatpaks-with-deps
    #ISO Container Args
    iso_build_args=()
    if [[ "{{ ghcr }}" == "0" ]]; then
        iso_build_args+=(--volume "/var/lib/containers/storage:/var/lib/containers/storage")
    fi
    iso_build_args+=(--volume "${PWD}:/github/workspace/")
    iso_build_args+=(ghcr.io/jasonn3/build-container-installer:latest)
    iso_build_args+=(ADDITIONAL_TEMPLATES="${TEMPLATES[*]}")
    iso_build_args+=(ARCH="x86_64")
    iso_build_args+=(ENROLLMENT_PASSWORD="universalblue")
    iso_build_args+=(FLATPAK_REMOTE_REFS_DIR="/github/workspace/${FLATPAK_REFS_DIR}")
    iso_build_args+=(IMAGE_NAME="{{ repo_image_name }}")
    iso_build_args+=(IMAGE_REPO="${IMAGE_REPO}")
    iso_build_args+=(IMAGE_SIGNED="true")
    if [[ "{{ ghcr }}" == "0" ]]; then
        iso_build_args+=(IMAGE_SRC="containers-storage:${IMAGE_FULL}")
    fi
    iso_build_args+=(IMAGE_TAG="{{ image }}")
    iso_build_args+=(ISO_NAME="/github/workspace/{{ repo_image_name }}_build/output/{{ image }}.iso")
    iso_build_args+=(SECURE_BOOT_KEY_URL="https://github.com/ublue-os/akmods/raw/main/certs/public_key.der")
    iso_build_args+=(VARIANT="Kinoite")
    iso_build_args+=(VERSION="$VERSION")
    iso_build_args+=(WEB_UI="false")
    # Build ISO
    {{ SUDOIF }} {{ PODMAN }} run --rm --privileged --pull=newer --security-opt label=disable "${iso_build_args[@]}"
    if [[ "${UID}" -gt "0" ]]; then
        {{ SUDOIF }} chown -R "${UID}":"${GROUPS[0]}" "${PWD}"
        {{ SUDOIF }} {{ PODMAN }} rmi "${IMAGE_FULL}"
    elif [[ "${UID}" == "0" && -n "${SUDO_USER:-}" ]]; then
        {{ SUDOIF }} chown -R "${SUDO_UID}":"${SUDO_GID}" "${PWD}"
    fi

# Run ISO
[group('ISO')]
run-iso image="bluefin":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    if [[ ! -f "{{ repo_image_name }}_build/output/{{ image }}.iso" ]]; then
        just build-iso {{ image }}
    fi
    port=8006;
    while grep -q "${port}" <<< "$(ss -tunalp)"; do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"
    (sleep 30 && xdg-open http://localhost:"${port}")&
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "BOOT_MODE=windows_secure")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/{{ repo_image_name }}_build/output/{{ image }}.iso":"/boot.iso":z)
    run_args+=(docker.io/qemux/qemu-docker)
    {{ PODMAN }} run "${run_args[@]}"

# Test Changelogs
[group('Changelogs')]
changelogs branch="stable" urlmd="" handwritten="":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    python3 changelogs.py {{ branch }} ./output-{{ branch }}.env ./changelog-{{ branch }}.md --workdir . --handwritten "{{ handwritten }}" --urlmd "{{ urlmd }}"

# Verify Container with Cosign
[group('Utility')]
verify-container container="" registry="ghcr.io/ublue-os" key="":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    if ! command -v cosign >/dev/null; then
        echo "ERROR: cosign is required to verify container signatures." >&2
        echo "Install cosign and rerun this recipe." >&2
        exit 1
    fi

    # Public Key for Container Verification
    key={{ key }}
    if [[ -z "${key:-}" && "{{ registry }}" == "ghcr.io/ublue-os" ]]; then
        key="https://raw.githubusercontent.com/ublue-os/main/main/cosign.pub"
    fi

    # Verify Container using cosign public key
    if ! cosign verify --key "${key}" "{{ registry }}"/"{{ container }}" >/dev/null; then
        echo "NOTICE: Verification failed. Please ensure your public key is correct."
        exit 1
    fi

# Secureboot Check
[group('Utility')]
secureboot image="bluefin":
    #!/usr/bin/env bash
    set ${SET_X:+-x}
    # Get the vmlinuz to check
    full_kernel=$({{ PODMAN }} run --rm "{{ repo_image_name }}":"{{ image }}" rpm -q kernel | grep ^kernel)
    if [ -n "$full_kernel" ]; then
        kernel_release=$(echo "$full_kernel" | sed 's/kernel-//')
    else
        full_kernel=$({{ PODMAN }} run "{{ repo_image_name }}":"{{ image }}" rpm -q kernel-longterm | grep ^kernel)
        kernel_release=$(echo "$full_kernel" | sed 's/kernel-longterm-//')
    fi
    set -eou pipefail
    TMP=$({{ PODMAN }} create "{{ repo_image_name }}":"{{ image }}" bash)
    {{ PODMAN }} cp "$TMP":/usr/lib/modules/"${kernel_release}"/vmlinuz /tmp/vmlinuz
    {{ PODMAN }} rm "$TMP"

    # Get the Public Certificates
    curl --retry 3 -Lo /tmp/kernel-sign.der https://github.com/ublue-os/kernel-cache/raw/main/certs/public_key.der
    curl --retry 3 -Lo /tmp/akmods.der https://github.com/ublue-os/kernel-cache/raw/main/certs/public_key_2.der
    openssl x509 -in /tmp/kernel-sign.der -out /tmp/kernel-sign.crt
    openssl x509 -in /tmp/akmods.der -out /tmp/akmods.crt

    # Make sure we have sbverify
    temp_name="sbverify-${RANDOM}"
    {{ PODMAN }} run -dt \
        --entrypoint /bin/sh \
        --volume /tmp/vmlinuz:/tmp/vmlinuz:z \
        --volume /tmp/kernel-sign.crt:/tmp/kernel-sign.crt:z \
        --volume /tmp/akmods.crt:/tmp/akmods.crt:z \
        --name ${temp_name} \
        alpine:edge
    {{ PODMAN }} exec "${temp_name}" apk add sbsigntool
    CMD="{{ PODMAN }} exec ${temp_name} /usr/bin/sbverify"

    # Confirm that Signatures Are Good
    $CMD --list /tmp/vmlinuz
    returncode=0
    if ! $CMD --cert /tmp/kernel-sign.crt /tmp/vmlinuz || ! $CMD --cert /tmp/akmods.crt /tmp/vmlinuz; then
        echo "Secureboot Signature Failed...."
        returncode=1
    fi
    if [[ -n "${temp_name:-}" ]]; then
        {{ PODMAN }} kill "${temp_name}"
        {{ PODMAN }} rm -f "${temp_name}"
    fi
    exit "$returncode"

# Merge Changelogs
merge-changelog:
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail
    rm -f changelog.md
    cat changelog-stable.md changelog-bazzite.md > changelog.md
    last_tag=$(git tag --list {{ repo_image_name }}-\* | sort -V | tail -1)
    date_extract="$(echo ${last_tag:-} | grep -oP '{{ repo_image_name }}-\K[0-9]+')"
    date_version="$(echo ${last_tag:-} | grep -oP '\.\K[0-9]+$' || true)"
    if [[ "${date_extract:-}" == "$(date +%Y%m%d)" ]]; then
        tag="{{ repo_image_name }}-${date_extract:-}.$(( ${date_version:-} + 1 ))"
    else
        tag="{{ repo_image_name }}-$(date +%Y%m%d)"
    fi
    cat << EOF
    {
        "title": "$tag (#$(git rev-parse --short HEAD))",
        "tag": "$tag"
    }
    EOF

lint:
    # shell
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'
    # yaml
    yamllint -s {{ justfile_dir() }}
    # just
    just check
    # just recipes
    just lint-recipes

format:
    # shell
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'
    # yaml
    yamlfmt {{ justfile_dir() }}
    # just
    just fix

_lint-recipe linter recipe *args:
    just -n {{ recipe }} {{ args }} 2>&1 | tee /tmp/{{ recipe }} >/dev/null && \
    echo "Linting {{ recipe }} with {{ linter }}" && \
    {{ linter }} /tmp/{{ recipe }} && rm /tmp/{{ recipe }} || \
    rm /tmp/{{ recipe }}

lint-recipes:
    #!/usr/bin/bash
    for recipe in build chunk build-iso run-iso; do
        just _lint-recipe "shellcheck -e SC2050,SC2194" "${recipe}" bluefin
    done
