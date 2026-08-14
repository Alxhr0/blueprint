#!/bin/bash
set -ouex pipefail

OGCI_DIR="/tmp/ogc-kernel"
REGISTRY="ghcr.io"
REPO="opengamingcollective/kernel-packages-arch"
OGC_TAG="7.1.8-ogc1.1"

mkdir -p "$OGCI_DIR"

TOKEN=$(curl -sSL "https://${REGISTRY}/token?service=${REGISTRY}&scope=repository:${REPO}:pull" | jq -r '.token')

curl -fSL -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.oci.image.manifest.v1+json" \
    "https://${REGISTRY}/v2/${REPO}/manifests/${OGC_TAG}" \
    -o "${OGCI_DIR}/manifest.json"

for DIGEST in $(jq -r '.layers[].digest' "${OGCI_DIR}/manifest.json"); do
    FILENAME=$(jq -r --arg d "$DIGEST" '.layers[] | select(.digest == $d) | .annotations["org.opencontainers.image.title"]' "${OGCI_DIR}/manifest.json")
    if [ -z "$FILENAME" ] || [ "$FILENAME" = "null" ]; then
        echo "ERROR: Missing title annotation for layer ${DIGEST}" >&2
        exit 1
    fi
    curl -fSL -H "Authorization: Bearer ${TOKEN}" \
        "https://${REGISTRY}/v2/${REPO}/blobs/${DIGEST}" \
        -o "${OGCI_DIR}/${FILENAME}"
done

if ! grep -q '^DisableSandboxNetwork' /etc/pacman.conf; then
    sed -i '/^\[options\]/a DisableSandboxNetwork' /etc/pacman.conf
fi

if ! pacman -U --noconfirm "${OGCI_DIR}"/*.pkg.tar.zst; then
    echo "ERROR: Failed to install OGC kernel packages" >&2
    exit 1
fi

if pacman -Q linux >/dev/null 2>&1; then
    pacman -Rdd --noconfirm linux
    rm -rf /usr/lib/modules/*arch1*
fi

mkdir -p /var/tmp

KERNEL_VERSION="$(find /usr/lib/modules -maxdepth 1 -type d -name '*-ogc*' | head -n 1 | xargs basename)"
if [ -z "$KERNEL_VERSION" ]; then
    echo "ERROR: Could not detect OGC kernel version" >&2
    exit 1
fi

DRACUT_NO_XATTR=1 dracut --force --no-hostonly --reproducible --zstd --verbose \
    --kver "$KERNEL_VERSION" "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

rm -rf "$OGCI_DIR"
