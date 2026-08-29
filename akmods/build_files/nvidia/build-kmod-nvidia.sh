#!/usr/bin/bash
set -euo pipefail

# Build the nvidia-open kernel module (nvidia_open) against the pinned OGC
# kernel via the official `nvidia-open-dkms` package (Arch Extra repo; the
# prebuilt `nvidia-open` only matches the stock `linux` kernel, not a custom
# kernel like linux-ogc). The package's DKMS hook compiles the module against
# the installed headers; we then stage the resulting .ko files for the cache.
#
# Env:
#   KERNEL_CACHE   directory containing kernel-version + rpms/
#   MODULE_OUT     where to stage built modules for the post/cache stage

KERNEL_CACHE="${KERNEL_CACHE:-/tmp/kernel_cache}"
KERNEL_VERSION="$(cat "${KERNEL_CACHE}/kernel-version")"
MODULE_OUT="${MODULE_OUT:-/var/cache/kmods}"

echo "=== Installing and building nvidia-open-dkms against ${KERNEL_VERSION} ==="
# nvidia-open-dkms ships its own install hook that runs dkms autoinstall.
pacman -S --noconfirm --needed nvidia-open-dkms

# Force a DKMS build/install for the pinned kernel in case the hook skipped it
# (e.g. no other kernels installed at package time).
dkms autoinstall -k "${KERNEL_VERSION}" || {
	echo "dkms autoinstall failed for ${KERNEL_VERSION}" >&2
	dkms status || true
	exit 1
}

# Verify the nvidia module landed in the installed tree.
nvidia_mods=$(find "/usr/lib/modules/${KERNEL_VERSION}" -maxdepth 4 \( -name 'nvidia*.ko.zst' -o -name 'nvidia*.ko' \) 2>/dev/null)
[ -n "${nvidia_mods}" ] || {
	echo "error: nvidia module not installed for ${KERNEL_VERSION}" >&2
	dkms status || true
	exit 1
}

echo "nvidia module present:"
echo "${nvidia_mods}"
mkdir -p "${MODULE_OUT}/nvidia"
# Stage the nvidia*.ko module files for the cache image.
while read -r m; do
	[ -n "${m}" ] && cp -fav "${m}" "${MODULE_OUT}/nvidia/"
done < <(find "/usr/lib/modules/${KERNEL_VERSION}" -maxdepth 4 \( -name 'nvidia*.ko.zst' -o -name 'nvidia*.ko' \) 2>/dev/null)
find "${MODULE_OUT}/nvidia" -maxdepth 1 -type f -printf 'staged: %f\n'
