#!/usr/bin/env bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

# CLEAN_ROOT: filesystem prefix applied to all paths.
# Defaults to "/" so the variable is never empty (satisfies SC2115).
# Set to a temp directory during unit tests.
CLEAN_ROOT="${CLEAN_ROOT:-/}"

rm -rf "${CLEAN_ROOT}/.gitkeep"

# Build-time-only dracut workaround (microcode_ctl aborts on Fedora-NVR
# kernels); only needed if a kernel swap runs. Cleaned here to never ship.
rm -f "${CLEAN_ROOT}/etc/dracut.conf.d/02-omit-unsupported-microcode.conf"

# Revert the build-time dnf options the Containerfile wrote into
# /etc/dnf/dnf.conf so the shipped image config keeps upstream defaults.
# Plain sed — c10s ships dnf4, there is no dnf5 to do this for us.
if [[ -f "${CLEAN_ROOT}/etc/dnf/dnf.conf" ]]; then
	sed -i 's/^keepcache=.*/keepcache=0/; /^install_weak_deps=/d' \
		"${CLEAN_ROOT}/etc/dnf/dnf.conf"
fi

# Use -mindepth/-maxdepth instead of shell globs so these are no-ops when the
# directories are empty (e.g. /var/cache/{dnf,libdnf5,rpm-ostree} only exist as
# transient buildah cache mounts and are not present in this layer).
find "${CLEAN_ROOT}/var" -mindepth 1 -maxdepth 1 -type d \! -name cache -exec rm -fr {} \;
find "${CLEAN_ROOT}/var/cache" -mindepth 1 -maxdepth 1 -type d \! -name dnf \! -name libdnf5 \! -name rpm-ostree -exec rm -fr {} \;

# Clear tmpfs-backed runtime directories without deleting the directories
# themselves. Buildah may have bind mounts in these paths during RUN, so
# replacing the mountpoint can fail with EBUSY.
for runtime_dir in tmp boot; do
	mkdir -p "${CLEAN_ROOT:?}/${runtime_dir}"
	find "${CLEAN_ROOT:?}/${runtime_dir}" -mindepth 1 -maxdepth 1 -print0 |
		while IFS= read -r -d '' entry; do
			if mountpoint -q "${entry}" 2>/dev/null; then
				continue
			fi
			rm -rf "${entry}"
		done
done

# /run can contain nested bind mounts created by the build container. Walk it
# depth-first so we can remove image-owned files like /run/dnf while leaving
# mounted files and any directories that still contain them alone.
mkdir -p "${CLEAN_ROOT:?}/run"
find "${CLEAN_ROOT:?}/run" -mindepth 1 -depth -print0 |
	while IFS= read -r -d '' entry; do
		if mountpoint -q "${entry}" 2>/dev/null; then
			continue
		fi
		if [[ -d "${entry}" ]]; then
			rmdir "${entry}" 2>/dev/null || true
			continue
		fi
		rm -f "${entry}"
	done

echo "::endgroup::"
