#!/bin/bash
#
# Fetch a file from GitHub: a release asset, or a repo snapshot tarball.
#
# ORG_PROJ is the organization/projectName pair from a GitHub URL.
# example: https://github.com/wez/wezterm/releases
#   ORG_PROJ would be "wez/wezterm"
#
# Release asset:
#   ARCH_FILTER selects the asset by filename regex. Typically the arch
#   such as 'x86_64', or a tighter filter when multiple assets match.
#   example: wezterm builds per-distro RPMs, so "fedora37.x86_64".
#   TAG is an optional release tag (default: latest).
#   With --output, the asset is downloaded; otherwise its URL is printed.
#
# Snapshot:
#   --snapshot REF downloads github.com/ORG_PROJ/archive/REF.tar.gz
#   REF may be a commit SHA, tag, or branch. --output is required.

ORG_PROJ="${1:-}"

usage() {
    echo "$0 ORG_PROJ ARCH_FILTER [TAG] [-o DEST] [--sha256 HASH]"
    echo "$0 ORG_PROJ --snapshot REF -o DEST [--sha256 HASH]"
    echo "    ORG_PROJ     - organization/projectname"
    echo "    ARCH_FILTER  - extra filter to limit release asset selection"
    echo "    TAG          - optional release tag (default: latest)"
    echo "    --snapshot   - git ref (commit SHA, tag, or branch)"
    echo "    -o, --output - download destination path"
    echo "    --sha256     - optional hash to verify a download"
}

if [[ -z ${ORG_PROJ} || ${ORG_PROJ} == -* ]]; then
    usage
    exit 1
fi
shift

snapshot_ref=""
dest=""
sha256=""
positionals=()

while [[ $# -gt 0 ]]; do
    case "$1" in
    --snapshot)
        snapshot_ref="${2:-}"
        if [[ -z ${snapshot_ref} ]]; then
            echo "ERROR: --snapshot requires a git ref" >&2
            exit 1
        fi
        shift 2
        ;;
    --sha256)
        sha256="${2:-}"
        if [[ -z ${sha256} ]]; then
            echo "ERROR: --sha256 requires a hash" >&2
            exit 1
        fi
        shift 2
        ;;
    -o | --output)
        dest="${2:-}"
        if [[ -z ${dest} ]]; then
            echo "ERROR: --output requires a path" >&2
            exit 1
        fi
        shift 2
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    -*)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    *)
        positionals+=("$1")
        shift
        ;;
    esac
done

set ${SET_X:+-x} -eou pipefail

github_curl() {
    local -a auth=()
    if [[ -r /run/secrets/GITHUB_TOKEN ]]; then
        local token
        token=$(</run/secrets/GITHUB_TOKEN)
        auth=(-H "Authorization: Bearer ${token}")
    fi
    curl --fail --retry 5 --retry-delay 5 --retry-all-errors -sL \
        "${auth[@]}" "$@"
}

download() {
    local url="$1"
    mkdir -p "$(dirname "${dest}")"
    github_curl -o "${dest}" "${url}"
    if [[ -n ${sha256} ]]; then
        echo "${sha256}  ${dest}" | sha256sum -c -
    fi
}

if [[ -n ${snapshot_ref} ]]; then
    if ((${#positionals[@]} > 0)); then
        echo "ERROR: --snapshot does not take ARCH_FILTER/TAG" >&2
        usage
        exit 1
    fi
    if [[ -z ${dest} ]]; then
        echo "ERROR: --snapshot requires --output DEST" >&2
        usage
        exit 1
    fi
    download \
        "https://github.com/${ORG_PROJ}/archive/${snapshot_ref}.tar.gz"
    exit 0
fi

arch_filter="${positionals[0]:-}"
tag="${positionals[1]:-}"

if [[ -z ${arch_filter} ]]; then
    usage
    exit 2
fi

if [[ -z ${tag} ]]; then
    reltag="latest"
else
    reltag="tags/${tag}"
fi

api_json=$(mktemp /tmp/api-XXXXXXXX.json)
trap 'rm -f "${api_json}"' EXIT
api="https://api.github.com/repos/${ORG_PROJ}/releases/${reltag}"

github_curl -o "${api_json}" "${api}"
mapfile -t asset_urls < <(jq \
    -r \
    --arg arch_filter "${arch_filter}" \
    '.assets | sort_by(.created_at) | reverse | .[] | select(.name|test($arch_filter)) | select (.name) | .browser_download_url' \
    "${api_json}")

if ((${#asset_urls[@]} == 0)); then
    echo "No asset matched '${arch_filter}' in ${ORG_PROJ} ${reltag}" >&2
    exit 3
fi

url="${asset_urls[0]}"
if [[ -n ${dest} ]]; then
    download "${url}"
else
    # WARNING: if multiple assets match, only the first URL is printed
    echo "${url}"
fi
