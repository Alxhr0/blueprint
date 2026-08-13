#!/bin/bash
set -ouex pipefail

SYSEXT_DIR=/sysext
mkdir -p "${SYSEXT_DIR}/usr/lib/extension-release.d"

dnf5 -y install --installroot="${SYSEXT_DIR}" --use-host-config --releasever=44 \
    fedora-release fedora-repos \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm

mkdir -p /etc/pki/rpm-gpg
cp -a /sysext/etc/pki/rpm-gpg/. /etc/pki/rpm-gpg/

dnf5 -y install --installroot="${SYSEXT_DIR}" --releasever=44 \
    --setopt=install_weak_deps=False \
    steam

dnf5 -y --installroot="${SYSEXT_DIR}" clean all

rm -f "${SYSEXT_DIR}/usr/lib/os-release"
rm -rf "${SYSEXT_DIR}/usr/lib/extensions"

cat > "${SYSEXT_DIR}/usr/lib/extension-release.d/extension-release.steam" <<EOF
ID=bluefin
VERSION_ID=44
SYSEXT_LEVEL=44
SYSEXT_SCOPE=system
EOF
