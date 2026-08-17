#!/usr/bin/env bash
set -xeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTEXT_DIR="$(dirname "$SCRIPT_DIR")"

KERNEL_VERSION="${KERNEL_VERSION:-$(rpm -qa --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel | tail -1)}"
echo "Building akmods for kernel: ${KERNEL_VERSION}"

# Build the akmods image
podman build \
    --build-arg "KERNEL_VERSION=${KERNEL_VERSION}" \
    --tag "blueprint:akmods-edward" \
    --file "${CONTEXT_DIR}/containerfiles/Containerfile.akmods-edward" \
    "${CONTEXT_DIR}"

# Create output directory
mkdir -p "${CONTEXT_DIR}/akmods-rpms"

# Extract RPMs from the builder stage
podman run --rm \
    --volume "${CONTEXT_DIR}/akmods-rpms:/output:Z" \
    "blueprint:akmods-edward" \
    bash -c "cp /rpms/*.rpm /output/ 2>/dev/null; cp /kernel-rpms/*.rpm /output/ 2>/dev/null; ls -la /output/"

echo "Akmods RPMs saved to: ${CONTEXT_DIR}/akmods-rpms/"
