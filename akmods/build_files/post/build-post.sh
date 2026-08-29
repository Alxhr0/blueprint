#!/usr/bin/bash
set -euo pipefail

# Assemble the final cache image contents: the pinned OGC kernel + headers
# packages and the modules built against them (nvidia, zfs). These are
# exported by the scratch stage so downstream bootc images can COPY them with
# certainty that nvidia/zfs match the pinned linux-ogc kernel.
#
# Env:
#   KERNEL_CACHE   directory with linux-ogc*.pkg.tar.zst (from fetch-kernel)
#   MODULE_OUT     directory with built modules (from nvidia/zfs stages)
#   CACHE_ROOT     where the scratch stage reads from

KERNEL_CACHE="${KERNEL_CACHE:-/tmp/kernel_cache}"
MODULE_OUT="${MODULE_OUT:-/var/cache/kmods}"
CACHE_ROOT="${CACHE_ROOT:-/var/cache/rpms}"

KERNEL_VERSION="$(cat "${KERNEL_CACHE}/kernel-version")"

# 1. Pinned kernel + headers packages.
mkdir -p "${CACHE_ROOT}/kernel"
cp -fav "${KERNEL_CACHE}"/rpms/linux-ogc*.pkg.tar.zst "${CACHE_ROOT}/kernel/"

# 2. Built modules (nvidia, zfs), keyed under the exact kernel version so the
#    consuming build can pick the right tree.
mkdir -p "${CACHE_ROOT}/kmods/${KERNEL_VERSION}"
if [ -d "${MODULE_OUT}/nvidia" ]; then
	cp -fav "${MODULE_OUT}/nvidia"/. "${CACHE_ROOT}/kmods/${KERNEL_VERSION}/nvidia/"
fi
if [ -d "${MODULE_OUT}/zfs" ]; then
	cp -fav "${MODULE_OUT}/zfs"/. "${CACHE_ROOT}/kmods/${KERNEL_VERSION}/zfs/"
fi

# 3. Metadata for consumers / labels.
cat >"${CACHE_ROOT}/kernel-info" <<EOF
KERNEL_VERSION=${KERNEL_VERSION}
KERNEL_PKG=$(basename "$(find "${KERNEL_CACHE}"/rpms -maxdepth 1 -name 'linux-ogc-*.pkg.tar.zst' | head -n1)")
EOF

echo "=== final cache tree ==="
find "${CACHE_ROOT}" -maxdepth 3 \( -type f -o -type d \) -printf '%y %P\n' | sort
