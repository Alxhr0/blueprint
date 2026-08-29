#!/usr/bin/bash
set -euo pipefail

# Pull the pinned OGC Arch kernel packages (linux-ogc, linux-ogc-headers) from
# the OGC OCI artifact into $KERNEL_CACHE, so the prep stage can install them
# with pacman. Mirrors ublue-os/akmods' fetch-kernel.sh ogc branch, adapted
# from RPMs to Arch *.pkg.tar.zst.
#
# Env:
#   OGC_IMAGE      ghcr.io/.../kernel-packages-arch:<tag>  (pinned tag)
#   KERNEL_CACHE   directory to write the .pkg.tar.zst files into

: "${OGC_IMAGE:?OGC_IMAGE must be set (e.g. ghcr.io/.../kernel-packages-arch:latest)}"
KERNEL_CACHE="${KERNEL_CACHE:-/tmp/kernel_cache}"
OUT="${KERNEL_CACHE}/rpms"
mkdir -p "${OUT}"

command -v skopeo >/dev/null || pacman -Sy --noconfirm --needed skopeo >/dev/null
command -v jq >/dev/null || pacman -Sy --noconfirm --needed jq >/dev/null
if ! command -v oras >/dev/null; then
	# oras is not in the official Arch repos; use the upstream static binary.
	echo "downloading oras CLI"
	ORAS_VER="1.2.2"
	curl -fsSL -o /tmp/oras.tar.gz \
		"https://github.com/oras-project/oras/releases/download/v${ORAS_VER}/oras_${ORAS_VER}_linux_amd64.tar.gz"
	tar -xzf /tmp/oras.tar.gz -C /usr/local/bin oras
	chmod +x /usr/local/bin/oras
	rm -f /tmp/oras.tar.gz
fi
command -v oras >/dev/null || {
	echo "error: could not provision oras" >&2
	exit 1
}

echo "Inspecting pinned OGC kernel artifact ${OGC_IMAGE}"
manifest="$(skopeo inspect --raw "docker://${OGC_IMAGE}")"

# Only the kernel and headers packages are needed for module builds.
needed_prefixes="^linux-ogc-|^linux-ogc-headers-|^linux-lts-ogc-|^linux-lts-ogc-headers-"

tmpdir="$(mktemp -d)"
found=0
while read -r layer; do
	title="$(echo "$layer" | jq -r '.annotations["org.opencontainers.image.title"] // empty')"
	digest="$(echo "$layer" | jq -r '.digest')"
	[ -n "$title" ] || continue
	if echo "$title" | grep -qE "$needed_prefixes"; then
		echo "  fetching ${title}"
		oras blob fetch "${OGC_IMAGE}@${digest}" --output "${tmpdir}/${title}"
		# The blob may be the raw .pkg.tar.zst or a tar wrapping it.
		if file "${tmpdir}/${title}" | grep -q "POSIX tar archive"; then
			tar xf "${tmpdir}/${title}" -C "${tmpdir}"
			rm -f "${tmpdir}/${title}"
		fi
		found=1
	fi
done < <(echo "$manifest" | jq -c '.layers[]')

if [ "$found" -eq 0 ]; then
	echo "error: no linux-ogc packages found in ${OGC_IMAGE}" >&2
	rm -rf "$tmpdir"
	exit 1
fi

cp -f "${tmpdir}"/linux-ogc*.pkg.tar.zst "${OUT}/"
rm -rf "$tmpdir"

KERNEL_PKG="$(find "${OUT}" -maxdepth 1 -name 'linux-ogc-*.pkg.tar.zst' -printf '%f\n' | head -n1)"
# e.g. linux-ogc-7.2.1.ogc2-1-x86_64.pkg.tar.zst -> 7.2.1.ogc2-1-x86_64
KERNEL_VERSION="${KERNEL_PKG#linux-ogc-}"
KERNEL_VERSION="${KERNEL_VERSION%.pkg.tar.zst}"
echo "kernel package: ${KERNEL_PKG}"
echo "kernel version: ${KERNEL_VERSION}"
printf '%s' "${KERNEL_VERSION}" >"${KERNEL_CACHE}/kernel-version"
find "${OUT}" -maxdepth 1 -name 'linux-ogc*.pkg.tar.zst' -printf 'cached: %f\n'
