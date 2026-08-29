#!/usr/bin/bash
set -euo pipefail

# Install the pinned OGC kernel (linux-ogc + headers) from the fetch-kernel
# cache and prepare the build environment (dkms, compiler, zfs build deps).
#
# Env:
#   KERNEL_CACHE   directory containing linux-ogc*.pkg.tar.zst (from fetch-kernel)
#   CI             set to 1 for verbose output

KERNEL_CACHE="${KERNEL_CACHE:-/tmp/kernel_cache}"
RPM_OUT="${KERNEL_CACHE}/rpms"

echo "=== Installing pinned OGC kernel packages ==="
pacman-key --init
pacman-key --populate archlinux

# Refresh the keyring / databases before touching anything.
pacman -Sy --noconfirm --needed archlinux-keyring

# Strip any signature fields already present on the pulled package files so
# pacman can verify/install cleanly from cache.
PKGS=("${RPM_OUT}"/linux-ogc*.pkg.tar.zst)
echo "kernel packages:" "${PKGS[@]}"
pacman -U --noconfirm "${PKGS[@]}"

echo "=== Preparing build environment ==="
pacman -Syu --noconfirm

BASE_PKGS=(base-devel dkms git jq linux-firmware sudo)
ZFS_MK_PKGS=(autoconf automake libtool pkgconf libtirpc util-linux systemd openssl libaio attr libelf python python-cffi ncompress)
pacman -S --noconfirm --needed "${BASE_PKGS[@]}" "${ZFS_MK_PKGS[@]}"

# Determine the exact installed OGC kernel version (dir under /usr/lib/modules).
KERNEL_VERSION="$(cat "${KERNEL_CACHE}/kernel-version" 2>/dev/null || true)"
if [ -z "${KERNEL_VERSION}" ]; then
	KERNEL_VERSION="$(find /usr/lib/modules -maxdepth 1 -type d -name '*ogc*' -printf '%f\n' | head -n1)"
	printf '%s' "${KERNEL_VERSION}" >"${KERNEL_CACHE}/kernel-version"
fi
echo "building against kernel: ${KERNEL_VERSION}"

test -d "/usr/lib/modules/${KERNEL_VERSION}/build" || {
	echo "error: kernel headers not installed for ${KERNEL_VERSION}" >&2
	exit 1
}

# A non-root user is required by makepkg/dkms for some nvidia steps.
if ! id build >/dev/null 2>&1; then
	useradd -m build
	echo 'build ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/build
fi

chmod 1777 /tmp /var/tmp
