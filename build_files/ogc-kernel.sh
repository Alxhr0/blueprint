#!/bin/bash
set -ouex pipefail

OGCI_IMAGE="ghcr.io/opengamingcollective/kernel-packages-arch:latest"
OGCI_DIR="/tmp/ogc-kernel"
REGISTRY="ghcr.io"
REPO="opengamingcollective/kernel-packages-arch"

mkdir -p "$OGCI_DIR"

TOKEN=$(curl -sSL "https://${REGISTRY}/token?service=${REGISTRY}&scope=repository:${REPO}:pull" | jq -r '.token')

curl -sSL -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.oci.image.manifest.v1+json" \
    "https://${REGISTRY}/v2/${REPO}/manifests/latest" \
    -o "${OGCI_DIR}/manifest.json"

for DIGEST in $(jq -r '.layers[].digest' "${OGCI_DIR}/manifest.json"); do
    FILENAME=$(jq -r --arg d "$DIGEST" '.layers[] | select(.digest == $d) | .annotations["org.opencontainers.image.title"]' "${OGCI_DIR}/manifest.json")
    curl -sSL -H "Authorization: Bearer ${TOKEN}" \
        "https://${REGISTRY}/v2/${REPO}/blobs/${DIGEST}" \
        -o "${OGCI_DIR}/${FILENAME}"
done

if ! grep -q '^DisableSandboxNetwork' /etc/pacman.conf; then
    sed -i '/^\[options\]/a DisableSandboxNetwork' /etc/pacman.conf
fi

pacman -U --noconfirm "${OGCI_DIR}"/*.pkg.tar.zst

if pacman -Q linux >/dev/null 2>&1; then
    pacman -Rdd --noconfirm linux
fi

KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E '\.img$' | tail -n 1)")"
DRACUT_NO_XATTR=1 dracut --force --no-hostonly --reproducible --zstd --verbose \
    --kver "$KERNEL_VERSION" "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

rm -rf "$OGCI_DIR"
