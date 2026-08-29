#!/usr/bin/bash
set -euo pipefail

# Build OpenZFS kernel modules against the pinned OGC kernel from the upstream
# source release tarball (zfs is not in the official Arch repos). Mirrors
# ublue-os/akmods' build-kmod-zfs.sh, but uses archbuild/configure directly
# instead of rpm spec files.
#
# Env:
#   KERNEL_CACHE        directory containing kernel-version + rpms/
#   MODULE_OUT          where to stage built modules for the cache
#   ZFS_MINOR_VERSION   optional: pin to a release series (e.g. "2.4")
#   CI                  set to 1 for verbose output

KERNEL_CACHE="${KERNEL_CACHE:-/tmp/kernel_cache}"
KERNEL_VERSION="$(cat "${KERNEL_CACHE}/kernel-version")"
MODULE_OUT="${MODULE_OUT:-/var/cache/kmods}"
ZFS_MINOR_VERSION="${ZFS_MINOR_VERSION:-}"

cd /tmp

# Resolve the latest (or pinned-series) stable zfs release tag from GitHub.
curl -fsSL "https://api.github.com/repos/openzfs/zfs/releases" -o data.json
ZFS_VERSION="$(
	jq -r --arg zmv "zfs-${ZFS_MINOR_VERSION}" \
		'[ .[] | select(.prerelease==false and .draft==false)
              | select(.tag_name | startswith($zmv)) ][0].tag_name' data.json
)"
ZFS_VERSION="${ZFS_VERSION#zfs-}"
echo "ZFS_MINOR_VERSION==${ZFS_MINOR_VERSION}"
echo "ZFS_VERSION==${ZFS_VERSION}"
[ -n "${ZFS_VERSION}" ] || {
	echo "error: unable to resolve zfs release" >&2
	exit 1
}

echo "=== Downloading ZFS ${ZFS_VERSION} ==="
curl -fL -O "https://github.com/openzfs/zfs/releases/download/zfs-${ZFS_VERSION}/zfs-${ZFS_VERSION}.tar.gz"
curl -fL -O "https://github.com/openzfs/zfs/releases/download/zfs-${ZFS_VERSION}/zfs-${ZFS_VERSION}.sha256.asc"

# Import the OpenZFS signing key and verify the checksum signature.
gpg --yes --keyserver keyserver.ubuntu.com --recv-keys D4598027 2>/dev/null || true
gpg --yes --keyserver keyserver.ubuntu.com --recv-keys C77B9667 2>/dev/null || true
if [ -s "zfs-${ZFS_VERSION}.sha256.asc" ]; then
	if gpg --verify "zfs-${ZFS_VERSION}.sha256.asc" 2>/dev/null; then
		if ! gpg --decrypt "zfs-${ZFS_VERSION}.sha256.asc" 2>/dev/null | sha256sum -c -; then
			echo "warning: zfs checksum mismatch or could not be verified" >&2
		fi
	else
		echo "warning: zfs checksum signature could not be verified" >&2
	fi
fi

tar -xzf "zfs-${ZFS_VERSION}.tar.gz"
cd "zfs-${ZFS_VERSION}"

echo "=== Building ZFS modules against ${KERNEL_VERSION} ==="
# Point the OpenZFS configure at the pinned kernel headers.
export KERNEL_DIR="/usr/lib/modules/${KERNEL_VERSION}/build"

test -d "${KERNEL_DIR}" || {
	echo "error: headers missing at ${KERNEL_DIR}" >&2
	exit 1
}

# Configure explicitly with the target kernel; if context.mk exists it pins us
# to the exact build tree.
python3 -c "import cffi" || {
	echo "error: python-cffi missing" >&2
	exit 1
}

./autogen.sh
./configure \
	--with-linux="${KERNEL_DIR}" \
	--with-linux-obj="${KERNEL_DIR}" \
	--prefix=/usr

make -j"$(nproc)"

# Install the built zfs module into the OGC kernel module tree (userspace is
# not needed for the cache). Modules land under
# /usr/lib/modules/<kver>/updates/ by default.
make -j"$(nproc)" -C module install

# Locate the installed zfs module and stage it for the cache image.
zfs_ko="$(find "/usr/lib/modules/${KERNEL_VERSION}" -name 'zfs.ko*' -print -quit 2>/dev/null || true)"
[ -n "${zfs_ko}" ] || {
	echo "error: zfs module not installed for ${KERNEL_VERSION}" >&2
	exit 1
}
echo "zfs module present: ${zfs_ko}"

mkdir -p "${MODULE_OUT}/zfs"
cp -fav "$(dirname "${zfs_ko}")"/zfs.ko* "${MODULE_OUT}/zfs/"
echo "zfs modules staged:"
find "${MODULE_OUT}/zfs" -maxdepth 1 -type f -printf '  %f\n'
