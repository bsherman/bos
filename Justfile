my_image := "bos"
my_image_styled := "bOS"
repo_name := "bos"
repo_organization := "bsherman"
rechunker_image := "ghcr.io/hhd-dev/rechunk:v1.0.1"
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
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
      echo "Checking syntax: $file"
      just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
      echo "Checking syntax: $file"
      just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    rm -f previous.manifest.json
    find *_build* -exec rm -rf {} \;

# Sudo Clean
[group('Utility')]
sudo-clean:
    #!/usr/bin/bash
    set -eoux pipefail
    just sudoif "rm -f previous.manifest.json"
    just sudoif "find *_build* -exec rm -rf {} \;"

# Check if valid combo
[group('Utility')]
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
[group('Utility')]
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
[group('Utility')]
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
[group('Image')]
build image="bluefin" tag="stable" flavor="main" rechunk="0":
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
    LABELS+=("--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/{{ repo_organization }}/{{ repo_name }}/refs/heads/main/README.md")
    LABELS+=("--label" "org.opencontainers.image.title={{ my_image_styled }}")
    LABELS+=("--label" "org.opencontainers.image.description=This {{ my_image_styled }} is {{ repo_organization }}'s customized image of ghcr.io/ublue-os/${src_img}:${src_tag}")

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
[group('Image')]
build-rechunk image="bluefin" tag="stable" flavor="main":
    @just build {{ image }} {{ tag }} {{ flavor }} 1

# Rechunk Image
[group('Image')]
[private]
rechunk image="bluefin" tag="stable" flavor="main":
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

    # debugging
    just sudoif podman images

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

    # Fedora Version
    fedora_version=$(just sudoif podman inspect $CREF | jq -r '.[].Config.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')

    # Cleanup space needed for Github Action runner lack of space
    ID=$(just sudoif podman images --filter reference=ghcr.io/ublue-os/"${src_img}":${src_tag} --format "'{{ '{{.ID}}' }}'")
    if [[ -n "$ID" ]]; then
        just sudoif podman rmi "$ID"
    fi

    # Run Rechunker's Prune
    just sudoif podman run --rm \
        --pull=newer \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --env TREE=/var/tree \
        --user 0:0 \
        "{{ rechunker_image }}" \
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
        "{{ rechunker_image }}" \
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
        --env LABELS="org.opencontainers.image.title={{ my_image_styled }}$'\n'org.opencontainers.image.version=${fedora_version}-$(date +%Y%m%d-%H:%M:%S)$'\n''io.artifacthub.package.readme-url=https://raw.githubusercontent.com/{{ repo_organization }}/{{ repo_name }}/refs/heads/main/README.md'$'\n'" \
        --env "DESCRIPTION='This {{ my_image_styled }} is a {{ repo_organization }} customized version of ghcr.io/ublue-os/${src_img}:${src_tag}'" \
        --env VERSION_FN=/workspace/version.txt \
        --env OUT_REF="oci:$OUT_NAME" \
        --env GIT_DIR="/var/git" \
        --user 0:0 \
        "{{ rechunker_image }}" \
        /sources/rechunk/3_chunk.sh

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
[group('Image')]
run image="bluefin" tag="stable" flavor="main":
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

# Get Fedora Version of an image
[group('Utility')]
fedora_version image="bluefin" tag="stable" flavor="main":
    #!/usr/bin/bash
    set -eou pipefail
    just validate {{ image }} {{ tag }} {{ flavor }}
    if [[ ! -f /tmp/manifest.json ]]; then
        if [[ "{{ tag }}" =~ stable ]]; then
            # CoreOS does not uses cosign
            skopeo inspect --retry-times 3 docker://quay.io/fedora/fedora-coreos:stable > /tmp/manifest.json
        else
            skopeo inspect --retry-times 3 docker://ghcr.io/ublue-os/base-main:"{{ tag }}" > /tmp/manifest.json
        fi
    fi
    fedora_version=$(jq -r '.Labels["ostree.linux"]' < /tmp/manifest.json | grep -oP 'fc\K[0-9]+')
    echo "${fedora_version}"
