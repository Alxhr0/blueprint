#!/bin/bash
set -ouex pipefail

SYSEXT_DIR=/sysext
mkdir -p "${SYSEXT_DIR}/usr/lib/extension-release.d"

# Install base release packages to seed repo configuration
dnf5 -y install --installroot="${SYSEXT_DIR}" --releasever=44 \
    fedora-release fedora-repos \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm

# Install Steam and its dependencies
dnf5 -y install --installroot="${SYSEXT_DIR}" --releasever=44 \
    --setopt=install_weak_deps=False \
    steam

dnf5 -y --installroot="${SYSEXT_DIR}" clean all

# systemd-sysext refuses extensions that ship /usr/lib/os-release
rm -f "${SYSEXT_DIR}/usr/lib/os-release"
rm -rf "${SYSEXT_DIR}/usr/lib/extensions"

# Write extension-release matching the target host
cat > "${SYSEXT_DIR}/usr/lib/extension-release.d/extension-release.steam" <<EOF
ID=bluefin
VERSION_ID=44
SYSEXT_LEVEL=44
SYSEXT_SCOPE=system
EOF
