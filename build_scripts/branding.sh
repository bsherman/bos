#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

if [[ "${IMAGE}" =~ ucore ]]; then
    tee /usr/share/ublue-os/image-info.json <<'EOF'
{
  "image-name": "",
  "image-flavor": "",
  "image-vendor": "bsherman",
  "image-ref": "ostree-image-signed:docker://ghcr.io/bsherman/bos",
  "image-tag": "",
  "base-image-name": "",
  "fedora-version": ""
}
EOF
fi

case "${IMAGE}" in
"bazzite"* | "bluefin"*)
    base_image="silverblue"
    ;;
"aurora"*)
    base_image="kinoite"
    ;;
"ucore"*)
    # shellcheck disable=SC2153
    base_image="${BASE_IMAGE}"
    ;;
esac

image_flavor="main"
if [[ "$IMAGE" =~ nvidia ]]; then
    image_flavor="nvidia"
fi

# Branding
cat <<<"$(jq ".\"image-name\" |= \"bos\" |
              .\"image-flavor\" |= \"${image_flavor}\" |
              .\"image-vendor\" |= \"bsherman\" |
              .\"image-ref\" |= \"ostree-image-signed:docker://ghcr.io/bsherman/bos\" |
              .\"image-tag\" |= \"${IMAGE}${BETA:-}\" |
              .\"base-image-name\" |= \"${base_image}\" |
              .\"fedora-version\" |= \"$(rpm -E %fedora)\"" \
    </usr/share/ublue-os/image-info.json)" \
>/tmp/image-info.json
cp /tmp/image-info.json /usr/share/ublue-os/image-info.json

if [[ "$IMAGE" =~ bazzite ]]; then
    sed -i 's/image-branch/image-tag/' /usr/libexec/bazzite-fetch-image
fi

sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"$(echo "${IMAGE^}" | cut -d - -f1) (Version: ${VERSION} / FROM ${BASE_IMAGE^} $(rpm -E %fedora))\"|" /usr/lib/os-release
sed -i "s|^VERSION=.*|VERSION=\"${VERSION} (${base_image^})\"|" /usr/lib/os-release
sed -i "s|^OSTREE_VERSION=.*|OSTREE_VERSION=\'${VERSION}\'|" /usr/lib/os-release
echo "IMAGE_ID=\"${IMAGE}\"" >>/usr/lib/os-release
echo "IMAGE_VERSION=\"${VERSION}\"" >>/usr/lib/os-release
