#!/usr/bin/env bash

#set ${SET_X:+-x} -euo pipefail
set -euo pipefail

echo "Running common-groups modifications..."

group_exists_in_file() {
    local group_name=$1
    local file=$2
    [[ -f "${file}" ]] && awk -F: -v g="${group_name}" '$1 == g { found=1; exit } END { exit !found }' "${file}"
}

group_gid_in_file() {
    local group_name=$1
    local file=$2
    [[ -f "${file}" ]] || return 1
    awk -F: -v g="${group_name}" '$1 == g { print $3; exit }' "${file}"
}

group_name_by_gid() {
    local gid=$1
    local file=$2
    [[ -f "${file}" ]] || return 1
    awk -F: -v want_gid="${gid}" '$3 == want_gid { print $1; exit }' "${file}"
}

ensure_local_group_gid() {
    local group_name=${1:-}
    local target_gid=${2:--1}
    local force_create=${3:-0}

    local current_gid=""
    local desired_gid=""
    local existing_group_for_gid=""

    if [[ -z ${group_name} ]]; then
        echo "usage: ensure_local_group_gid <group> <gid|-1=inherit> [force_create=0|1]" >&2
        return 2
    fi

    if ! [[ ${target_gid} =~ ^-?[0-9]+$ ]]; then
        echo "invalid gid '${target_gid}' for group '${group_name}'" >&2
        return 2
    fi

    if [[ "${force_create}" != "0" && "${force_create}" != "1" ]]; then
        echo "invalid force_create value '${force_create}' for group '${group_name}'" >&2
        return 2
    fi

    # By default, only manage groups defined in /usr/lib/group.
    if [[ "${force_create}" != "1" ]]; then
        if ! group_exists_in_file "${group_name}" /usr/lib/group; then
            echo "Skipping '${group_name}': not present in /usr/lib/group"
            return 0
        fi
    fi

    # Determine desired gid
    if (( target_gid < 0 )); then
        if ! group_exists_in_file "${group_name}" /usr/lib/group; then
            echo "Cannot inherit gid for '${group_name}': not found in /usr/lib/group" >&2
            return 1
        fi

        desired_gid=$(group_gid_in_file "${group_name}" /usr/lib/group)
        if [[ -z "${desired_gid}" ]]; then
            echo "Cannot inherit gid for '${group_name}': failed to read gid from /usr/lib/group" >&2
            return 1
        fi
    else
        desired_gid=${target_gid}
    fi

    # Sync from /usr/lib/group → /etc/group if needed
    if group_exists_in_file "${group_name}" /usr/lib/group && ! group_exists_in_file "${group_name}" /etc/group; then
        awk -F: -v g="${group_name}" '$1 == g { print; exit }' /usr/lib/group >> /etc/group
        echo "Added '${group_name}' to /etc/group"
    fi

    # If still not local, optionally create
    if ! group_exists_in_file "${group_name}" /etc/group; then
        if [[ "${force_create}" == "1" ]]; then
            existing_group_for_gid=$(group_name_by_gid "${desired_gid}" /etc/group || true)

            if [[ -n "${existing_group_for_gid}" && "${existing_group_for_gid}" != "${group_name}" ]]; then
                echo "Refusing to create '${group_name}' with gid ${desired_gid}: already used by '${existing_group_for_gid}'" >&2
                return 1
            fi

            groupadd -g "${desired_gid}" "${group_name}"
            echo "Created local group '${group_name}' with gid ${desired_gid}"
        else
            echo "Skipping '${group_name}': not present locally after sync"
        fi
        return 0
    fi

    current_gid=$(group_gid_in_file "${group_name}" /etc/group)
    if [[ -z "${current_gid}" ]]; then
        echo "Failed to read current gid for '${group_name}' from /etc/group" >&2
        return 1
    fi

    if [[ "${current_gid}" != "${desired_gid}" ]]; then
        existing_group_for_gid=$(group_name_by_gid "${desired_gid}" /etc/group || true)

        if [[ -n "${existing_group_for_gid}" && "${existing_group_for_gid}" != "${group_name}" ]]; then
            echo "Refusing to change '${group_name}' to gid ${desired_gid}: already used by '${existing_group_for_gid}'" >&2
            return 1
        fi

        groupmod -g "${desired_gid}" "${group_name}"
        echo "Updated gid for '${group_name}' from ${current_gid} to ${desired_gid}"
    else
        echo "No change for '${group_name}': gid already ${desired_gid}"
    fi
}

# System/image groups (inherit GID)
ensure_local_group_gid adm
ensure_local_group_gid input
ensure_local_group_gid render
ensure_local_group_gid sudo
ensure_local_group_gid systemd-journal
ensure_local_group_gid wheel

# Custom/service groups (explicit GID, force create)
ensure_local_group_gid incus 250 1
ensure_local_group_gid incus-admin 251 1
ensure_local_group_gid docker 252 1
ensure_local_group_gid libvirtd 253 1
ensure_local_group_gid libvirtdbus 254 1
