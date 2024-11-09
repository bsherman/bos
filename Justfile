my_image := "bos"
my_image_styled := "bOS"
repo_name := "bos"
repo_organization := "bsherman"
images := '(
    [bazzite]="bazzite-gnome"
    [bazzite-deck]="bazzite-deck-gnome"
    [bluefin]="bluefin"
    [bluefin-dx]="bluefin-dx"
    [ucore-minimal]="ucore-minimal"
    [ucore]="ucore"
    [ucore-hci]="ucore-hci"
)'
flavors := '(
    [main]=main
    [nvidia]=nvidia
)'
tags := '(
    [stable]=stable
    [beta]=beta
    [testing]=testing
)'

[private]
default:
    @just --list --unsorted

# Check Just Syntax
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
      echo "Checking syntax: $file"
      just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
      echo "Checking syntax: $file"
      just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json

# Sudo Clean
sudo-clean:
    #!/usr/bin/bash
    set -eoux pipefail
    just sudoif "find *_build* -exec rm -rf {} \;"
    just sudoif "rm -f previous.manifest.json"

# Check if valid combo
[private]
validate image="" tag="" flavor="":
    #!/usr/bin/bash
    set -eoux pipefail
    declare -A images={{ images }}
    declare -A tags={{ tags }}
    declare -A flavors={{ flavors }}
    image={{ image }}
    tag={{ tag }}
    flavor={{ flavor }}
    checkimage="${images[${image}]-}"
    checktag="${tags[${tag}]-}"
    checkflavor="${flavors[${flavor}]-}"

    # Validity Checks
    if [[ -z "$checkimage" ]]; then
        echo "Invalid Image..."
        exit 1
    fi
    if [[ -z "$checkflavor" ]]; then
        echo "Invalid flavor..."
        exit 1
    fi
    if [[ -z "$checktag" ]]; then
        echo "Invalid tag..."
        exit 1
    fi
    if [[ "$checkimage" =~ bazzite ]]; then
        if [[ "$checktag" != stable ]]; then
            echo "Bazzite only builds stable tag..."
            exit 1
        fi
        if [[ "$checkflavor" != main ]]; then
            echo "Bazzite only builds main flavor..."
            exit 1
        fi
    fi
    if [[ "$checkimage" =~ bluefin ]]; then
        if [[ "$checktag" =~ testing ]]; then
            echo "Bluefin does not build testing tag..."
            exit 1
        fi
    fi
    if [[ "$checkimage" =~ ucore ]]; then
        if [[ "$checktag" =~ beta ]]; then
            echo "uCore does not build beta tag..."
            exit 1
        fi
    fi

# Generate container args, etc
[private]
gen-build-src-dst image="" tag="" flavor="":
    #!/usr/bin/bash
    set -eou pipefail
    declare -A images={{ images }}
    declare -A tags={{ tags }}
    declare -A flavors={{ flavors }}
    image={{ image }}
    tag={{ tag }}
    flavor={{ flavor }}
    srcimage="${images[${image}]-}"
    srctag="${tags[${tag}]-}"
    srcflavor="${flavors[${flavor}]-}"

    # Validate
    just validate "${image}" "${tag}" "${flavor}"

    # Image Name (the SOURCE image)
    if [[ "${flavor}" =~ main || "${image}" =~ ucore ]]; then
        # image name is what was required if it's a main flavor
        # OR if it's ucore, since ucore has a different tagging for nivida rather than image
        source_image="${srcimage}"
    else
        source_image="${srcimage}-${srcflavor}"
    fi

    # Tag Version (the SOURCE tag)
    if [[ "${image}" =~ ucore ]]; then
        if [[ "${image}" == ucore-minimal ]]; then
            if [[ "${flavor}" =~ main ]]; then
                source_tag="${srctag}"
            else
                source_tag="${srctag}-${srcflavor}"
            fi
        else
            if [[ "${flavor}" =~ main ]]; then
                source_tag="${srctag}-zfs"
            else
                source_tag="${srctag}-${srcflavor}-zfs"
            fi
        fi
    elif [[ "${image}" =~ bluefin && "${tag}" == stable ]]; then
        source_tag="${srctag}-daily"
    else
        source_tag="${srctag}"
    fi

    # My Tag (the tag I publish for my image)
    my_tag_flavor="" # a way to inject flavor for ucore using different tag style
    if [[ "${flavor}" != main ]]; then
        my_tag_flavor="-${flavor}"
    fi
    if [[ "${tag}" =~ stable ]]; then
        my_tag="${image}${my_tag_flavor}"
    else
        my_tag="${image}${my_tag_flavor}-${tag}"
    fi
    echo "${source_image} ${source_tag} {{ my_image }} ${my_tag}"

# sudoif bash function
[private]
sudoif command *args:
    #!/usr/bin/bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# Build Image
build image="bluefin" tag="beta" flavor="main" rechunk="0":
    #!/usr/bin/bash
    set -eoux pipefail
    image={{ image }}
    tag={{ tag }}
    flavor={{ flavor }}

    # Validate is handled by gen-build-src-dst
    build_src_dst=($(just gen-build-src-dst "${image}" "${tag}" "${flavor}"))
    src_img=${build_src_dst[0]}
    src_tag=${build_src_dst[1]}
    dst_img=${build_src_dst[2]}
    dst_tag=${build_src_dst[3]}

    # Build Arguments
    BUILD_ARGS=()
    BUILD_ARGS+=("--build-arg" "BASE_IMAGE=${src_img}")
    BUILD_ARGS+=("--build-arg" "IMAGE=${src_img}")
    BUILD_ARGS+=("--build-arg" "TAG_VERSION=${src_tag}")

    # Labels
    LABELS=()
    LABELS+=("--label" "org.opencontainers.image.description=This {{ my_image_styled }} is my customized image of ghcr.io/ublue-os/${src_img}:${src_tag}")
    LABELS+=("--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/{{ repo_organization }}/{{ repo_name }}//README.md")
    LABELS+=("--label" "org.opencontainers.image.title={{ my_image_styled }}")

    # Build Image
    podman build \
        "${BUILD_ARGS[@]}" \
        "${LABELS[@]}" \
        --tag "${dst_img}:${dst_tag}" \
        .

    # Rechunk
    if [[ "{{ rechunk }}" == "1" ]]; then
        just rechunk "${image}" "${tag}" "${flavor}"
    fi

# Build Image and Rechunk
build-rechunk image="bluefin" tag="latest" flavor="main":
    @just build {{ image }} {{ tag }} {{ flavor }} 1

# Rechunk Image
[private]
rechunk image="bluefin" tag="latest" flavor="main":
    #!/usr/bin/bash
    set -eoux pipefail

    image={{ image }}
    tag={{ tag }}
    flavor={{ flavor }}

    # Validate is handled by gen-build-src-dst
    build_src_dst=($(just gen-build-src-dst "${image}" "${tag}" "${flavor}"))
    src_img=${build_src_dst[0]}
    src_tag=${build_src_dst[1]}
    dst_img=${build_src_dst[2]}
    dst_tag=${build_src_dst[3]}

    # Check if image is already built
    ID=$(podman images --filter reference=localhost/"${dst_img}":"${dst_tag}" --format "'{{ '{{.ID}}' }}'")
    if [[ -z "$ID" ]]; then
        just build "${image}" "${tag}" "${flavor}"
    fi

    # Load into Rootful Podman
    ID=$(just sudoif podman images --filter reference=localhost/"${dst_img}":"${dst_tag}" --format "'{{ '{{.ID}}' }}'")
    if [[ -z "$ID" ]]; then
        just sudoif podman image scp ${UID}@localhost::localhost/"${dst_img}":"${dst_tag}" root@localhost::localhost/"${dst_img}":"${dst_tag}"
    fi

    # Prep Container
    CREF=$(just sudoif podman create localhost/"${dst_img}":"${dst_tag}" bash)
    MOUNT=$(just sudoif podman mount "${CREF}")
    OUT_NAME="${dst_img}_build"

    # Run Rechunker's Prune
    just sudoif podman run --rm \
        --pull=newer \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --env TREE=/var/tree \
        --user 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/1_prune.sh

    # Run Rechunker's Create
    just sudoif podman run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --volume "cache_ostree:/var/ostree" \
        --env TREE=/var/tree \
        --env REPO=/var/ostree/repo \
        --env RESET_TIMESTAMP=1 \
        --user 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/2_create.sh

    # Cleanup Temp Container Reference
    just sudoif podman unmount "$CREF"
    just sudoif podman rm "$CREF"

    # Run Rechunker
    just sudoif podman run --rm \
        --pull=newer \
        --security-opt label=disable \
        --volume "$PWD:/workspace" \
        --volume "$PWD:/var/git" \
        --volume cache_ostree:/var/ostree \
        --env REPO=/var/ostree/repo \
        --env PREV_REF=ghcr.io/{{ repo_organization }}/"${dst_img}":"${dst_tag}" \
        --env OUT_NAME="$OUT_NAME" \
        --env VERSION_FN=/workspace/version.txt \
        --env OUT_REF="oci:$OUT_NAME" \
        --env GIT_DIR="/var/git" \
        --user 0:0 \
        ghcr.io/hhd-dev/rechunk:latest \
        /sources/rechunk/3_chunk.sh
        #LABELS+=("--label" "org.opencontainers.image.description=This {{ my_image_styled }} is my customized image of ghcr.io/ublue-os/${src_img}:${src_tag}")
        #LABELS+=("--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/{{ repo_organization }}/{{ repo_name }}//README.md")
        #LABELS+=("--label" "org.opencontainers.image.title={{ my_image_styled }}")
        #--env LABELS="org.opencontainers.image.title=${dst_img}$'\n'org.opencontainers.image.version=localbuild-$(date +%Y%m%d-%H:%M:%S)$'\n''io.artifacthub.package.readme-url=https://raw.githubusercontent.com/{{ repo_organization }}/bluefin/refs/heads/main/README.md'$'\n''io.artifacthub.package.logo-url=https://avatars.githubusercontent.com/u/120078124?s=200&v=4'$'\n'" \
        #--env "DESCRIPTION='An interpretation of the Ubuntu spirit built on Fedora technology'" \

    # Cleanup
    just sudoif "find ${OUT_NAME} -type d -exec chmod 0755 {} \;" || true
    just sudoif "find ${OUT_NAME}* -type f -exec chmod 0644 {} \;" || true
    if [[ "${UID}" -gt 0 ]]; then
        just sudoif chown ${UID}:${GROUPS} -R "${PWD}"
    fi
    just sudoif podman volume rm cache_ostree
    just sudoif podman rmi localhost/"${dst_img}":"${dst_tag}"

    # Load Image into Podman Store
    IMAGE=$(podman pull oci:"${PWD}"/"${OUT_NAME}")
    podman tag ${IMAGE} localhost/"${dst_img}":"${dst_tag}"

# Run Container
run image="bluefin" tag="latest" flavor="main":
    #!/usr/bin/bash
    set -eoux pipefail
    image={{ image }}
    tag={{ tag }}
    flavor={{ flavor }}

    # Validate is handled by gen-build-src-dst
    build_src_dst=($(just gen-build-src-dst "${image}" "${tag}" "${flavor}"))
    src_img=${build_src_dst[0]}
    src_tag=${build_src_dst[1]}
    dst_img=${build_src_dst[2]}
    dst_tag=${build_src_dst[3]}

    # Check if image exists
    ID=$(podman images --filter reference=localhost/"${dst_img}":"${dst_tag}" --format "'{{ '{{.ID}}' }}'")
    if [[ -z "$ID" ]]; then
        just build "$image" "$tag" "$flavor"
    fi

    # Run Container
    podman run -it --rm localhost/"${dst_img}":"${dst_tag}" bash

# Build ISO
build-iso image="bluefin" tag="latest" flavor="main" ghcr="0":
    #!/usr/bin/bash
    set -eoux pipefail
    image={{ image }}
    tag={{ tag }}
    flavor={{ flavor }}

    # Validate is handled by gen-build-src-dst
    build_src_dst=($(just gen-build-src-dst "${image}" "${tag}" "${flavor}"))
    src_img=${build_src_dst[0]}
    src_tag=${build_src_dst[1]}
    dst_img=${build_src_dst[2]}
    dst_tag=${build_src_dst[3]}

    build_dir="${dst_img}_build"
    mkdir -p "$build_dir"

    if [[ -f "${build_dir}/${dst_img}.iso" || -f "${build_dir}/${dst_img}.iso-CHECKSUM" ]]; then
        echo "ERROR - ISO or Checksum already exist. Please mv or rm to build new ISO"
        exit 1
    fi

    # Local or Github Build
    if [[ "{{ ghcr }}" == "1" ]]; then
        IMAGE_FULL=ghcr.io/{{ repo_organization }}/"${dst_img}":"${dst_tag}"
        IMAGE_REPO=ghcr.io/{{ repo_organization }}
        podman pull "${IMAGE_FULL}"
    else
        IMAGE_FULL=localhost/"${dst_img}":"${dst_tag}"
        IMAGE_REPO=localhost
        ID=$(podman images --filter reference=localhost/"${dst_img}":"${dst_tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ -z "$ID" ]]; then
            just build "$image" "$tag" "$flavor"
        fi
    fi

    # Load Image into rootful podman
    if [[ "${UID}" -gt 0 ]]; then
        just sudoif podman image scp "${UID}"@localhost::"${IMAGE_FULL}" root@localhost::"${IMAGE_FULL}"
    fi

    # Flatpak list for bluefin/aurora
    if [[ "${image}" =~ bluefin ]]; then
        FLATPAK_DIR_SHORTNAME="bluefin_flatpaks"
    elif [[ "${image}" =~ aurora ]]; then
        FLATPAK_DIR_SHORTNAME="aurora_flatpaks"
    fi

    # Generate Flatpak List
    TEMP_FLATPAK_INSTALL_DIR="$(mktemp -d -p /tmp flatpak-XXXXX)"
    flatpak_refs=()
    while IFS= read -r line; do
        flatpak_refs+=("$line")
    done < "${FLATPAK_DIR_SHORTNAME}/flatpaks"

    # Add DX Flatpaks if needed
    if [[ "${image}" =~ dx ]]; then
        while IFS= read -r line; do
            flatpak_refs+=("$line")
        done < "dx_flatpaks/flatpaks"
    fi

    echo "Flatpak refs: ${flatpak_refs[@]}"

    # Generate Install Script for Flatpaks
    tee "${TEMP_FLATPAK_INSTALL_DIR}/install-flatpaks.sh"<<EOF
    mkdir -p /flatpak/flatpak /flatpak/triggers
    mkdir -p /var/tmp
    chmod -R 1777 /var/tmp
    flatpak config --system --set languages "*"
    flatpak remote-add --system flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --system -y flathub ${flatpak_refs[@]}
    ostree refs --repo=\${FLATPAK_SYSTEM_DIR}/repo | grep '^deploy/' | grep -v 'org\.freedesktop\.Platform\.openh264' | sed 's/^deploy\///g' > /output/flatpaks-with-deps
    EOF

    # Create Flatpak List with dependencies
    flatpak_list_args=()
    flatpak_list_args+=("--rm" "--privileged")
    flatpak_list_args+=("--entrypoint" "/usr/bin/bash")
    flatpak_list_args+=("--env" "FLATPAK_SYSTEM_DIR=/flatpak/flatpak")
    flatpak_list_args+=("--env" "FLATPAK_TRIGGERSDIR=/flatpak/triggers")
    flatpak_list_args+=("--volume" "$(realpath ./${build_dir}):/output")
    flatpak_list_args+=("--volume" "${TEMP_FLATPAK_INSTALL_DIR}:/temp_flatpak_install_dir")
    flatpak_list_args+=("${IMAGE_FULL}" /temp_flatpak_install_dir/install-flatpaks.sh)

    if [[ ! -f "${build_dir}/flatpaks-with-deps" ]]; then
        podman run "${flatpak_list_args[@]}"
    else
        echo "WARNING - Reusing previous determined flatpaks-with-deps"
    fi

    # List Flatpaks with Dependencies
    cat "${build_dir}/flatpaks-with-deps"

    # Build ISO
    iso_build_args=()
    iso_build_args+=("--rm" "--privileged" "--pull=newer")
    iso_build_args+=(--volume "/var/lib/containers/storage:/var/lib/containers/storage")
    iso_build_args+=(--volume "${PWD}:/github/workspace/")
    iso_build_args+=(ghcr.io/jasonn3/build-container-installer:latest)
    iso_build_args+=(ARCH="x86_64")
    iso_build_args+=(ENROLLMENT_PASSWORD="universalblue")
    iso_build_args+=(FLATPAK_REMOTE_REFS_DIR="/github/workspace/${build_dir}")
    iso_build_args+=(IMAGE_NAME="${dst_img}")
    iso_build_args+=(IMAGE_REPO="${IMAGE_REPO}")
    iso_build_args+=(IMAGE_SIGNED="true")
    iso_build_args+=(IMAGE_SRC="containers-storage:${IMAGE_FULL}")
    iso_build_args+=(IMAGE_TAG="${dst_tag}")
    iso_build_args+=(ISO_NAME="/github/workspace/${build_dir}/${dst_img}.iso")
    iso_build_args+=(SECURE_BOOT_KEY_URL="https://github.com/{{ repo_organization }}/akmods/raw/main/certs/public_key.der")
    if [[ "${image}" =~ bluefin ]]; then
        iso_build_args+=(VARIANT="Silverblue")
    else
        iso_build_args+=(VARIANT="Kinoite")
    fi
    iso_build_args+=(VERSION="$(skopeo inspect containers-storage:${IMAGE_FULL} | jq -r '.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')")
    iso_build_args+=(WEB_UI="false")

    just sudoif podman run "${iso_build_args[@]}"
    just sudoif chown "${UID}:${GROUPS}" -R "${PWD}"

# Build ISO using GHCR Image
build-iso-ghcr image="bluefin" tag="latest" flavor="main":
    @just build-iso {{ image }} {{ tag }} {{ flavor }} ghcr

# Run ISO
run-iso image="bluefin" tag="latest" flavor="main":
    #!/usr/bin/bash
    set -eoux pipefail
    image={{ image }}
    tag={{ tag }}
    flavor={{ flavor }}

    # Validate is handled by gen-build-src-dst
    build_src_dst=($(just gen-build-src-dst "${image}" "${tag}" "${flavor}"))
    src_img=${build_src_dst[0]}
    src_tag=${build_src_dst[1]}
    dst_img=${build_src_dst[2]}
    dst_tag=${build_src_dst[3]}


    # Check if ISO Exists
    if [[ ! -f "${dst_img}_build/${dst_img}.iso" ]]; then
        just build-iso "$image" "$tag" "$flavor"
    fi

    # Determine which port to use
    port=8006;
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"
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
    run_args+=(--volume "${PWD}/${dst_img}_build/${dst_img}.iso":"/boot.iso")
    run_args+=(docker.io/qemux/qemu-docker)
    podman run "${run_args[@]}" &
    xdg-open http://localhost:${port}
    fg "%podman"

# Test Changelogs
changelogs branch="stable":
    #!/usr/bin/bash
    set -eoux pipefail
    python3 ./.github/changelogs.py {{ branch }} ./output.env ./changelog.md --workdir .
