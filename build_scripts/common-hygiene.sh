#!/usr/bin/env bash

set ${SET_X:+-x} -eou pipefail

echo "Performing common hygiene steps (moby cleanup)..."

# Ensure no moby-engine packages are present. We prefer to manage containers
# via sysexts or other mechanisms rather than baking them into the base image.
$DNF remove -y containerd docker-buildx docker-cli docker-compose moby-engine runc

# Remove the docker group that may have been created by moby-engine.
# This can conflict with user/group management on the final system.
sed -i '/^docker:/d' /etc/group
sed -i '/^docker:/d' /etc/gshadow
sed -i '/^docker:/d' /usr/lib/group
