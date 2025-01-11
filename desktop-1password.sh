#!/usr/bin/env sh

# Thanks to bri for the inspiration! My script is mostly based on this example:
# https://github.com/briorg/bluefin/blob/c62c30a04d42fd959ea770722c6b51216b4ec45b/scripts/1password.sh

set ${SET_X:+-x} -eou pipefail

echo "Installing 1Password"

# On libostree systems, /opt is a symlink to /var/opt,
# which actually only exists on the live system. /var is
# a separate mutable, stateful FS that's overlaid onto
# the ostree rootfs. Therefore we need to install it into
# /usr/lib/1Password instead, and dynamically create a
# symbolic link /opt/1Password => /usr/lib/1Password upon
# boot.

# Prepare staging directory
mkdir -p /var/opt # -p just in case it exists
# for some reason...

# Setup repo
cat <<EOF >/etc/yum.repos.d/1password.repo
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF

# Import signing key
rpm --import https://downloads.1password.com/linux/keys/1password.asc

# Prepare 1Password groups
# Normally, when after dnf installs the 1password RPM, an
# 'after-install.sh' script runs to cofigure several things, including
# the creation of a group. Under rpm-ostree, this didn't work quite as
# expected, thus several steps were done to hack around and fix things.
# Now with dnf5, there is a problem where 'after-install.sh' creates
# groups which conflict with default user's GID. This now pre-creates
# the groups, rather than fixing after RPM installation.

# I hardcode GIDs and cross fingers that nothing else steps on them.
# These numbers _should_ be okay under normal use, but
# if there's a more specific range that I should use here
# please submit a PR!

# Specifically, GID must be > 1000, and absolutely must not
# conflict with any real groups on the deployed system.
# Normal user group GIDs on Fedora are sequential starting
# at 1000, so let's skip ahead and set to something higher.
GID_ONEPASSWORD="1790"
GID_ONEPASSWORDCLI="1791"
groupadd -g ${GID_ONEPASSWORD} onepassword
groupadd -g ${GID_ONEPASSWORDCLI} onepassword-cli

# Now let's install the packages.
dnf5 install -y 1password 1password-cli

# This places the 1Password contents in an image safe location
mv /var/opt/1Password /usr/lib/1Password # move this over here

# Register path symlink
# We do this via tmpfiles.d so that it is created by the live system.
cat >/usr/lib/tmpfiles.d/onepassword.conf <<EOF
L  /opt/1Password  -  -  -  -  /usr/lib/1Password
EOF

# No further hack SHOULD be needed since dnf5 does run the script
# after-install.sh as expected and uses our pre-set groups.

# Disable the yum repo (updates are baked into new images)
sed -i "s@enabled=1@enabled=0@" /etc/yum.repos.d/1password.repo
