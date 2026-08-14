#!/bin/bash
set -ouex pipefail

OGCI_IMAGE="ghcr.io/opengamingcollective/kernel-packages-arch:latest"
OGCI_DIR="/tmp/ogc-kernel"
REGISTRY="ghcr.io"
REPO="opengamingcollective/kernel-packages-arch"

mkdir -p "$OGCI_DIR"

curl -sSL -H "Accept: application/vnd.oci.image.manifest.v1+json" \
    "https://${REGISTRY}/v2/${REPO}/manifests/latest" \
    -o "${OGCI_DIR}/manifest.json"

for DIGEST in $(jq -r '.layers[].digest' "${OGCI_DIR}/manifest.json"); do
    FILENAME=$(jq -r --arg d "$DIGEST" '.layers[] | select(.digest == $d) | .annotations["org.opencontainers.image.title"]' "${OGCI_DIR}/manifest.json")
    curl -sSL "https://${REGISTRY}/v2/${REPO}/blobs/${DIGEST}" -o "${OGCI_DIR}/${FILENAME}"
done

pacman -U --noconfirm "${OGCI_DIR}"/*.pkg.tar.zst

rm -rf "$OGCI_DIR"
