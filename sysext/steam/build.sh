#!/bin/bash
set -ouex pipefail

mkdir -p /sysext/usr/lib/extension-release.d

# Steam is only shipped via RPM Fusion nonfree, not the base Fedora repos.
# --use-host-config loads the fedora:44 base image's repo config so the
# installroot transactions resolve. fedora-release provides system-release(44),
# which the rpmfusion release rpms require; fedora-repos seeds the installroot
# with the base Fedora repo files.
dnf5 -y install --installroot=/sysext --use-host-config --releasever=44 \
    fedora-release fedora-repos \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm

# dnf5 resolves file:// gpgkey paths against the host root even when using
# --installroot, so mirror the installroot's keys into the host keyring
# before the steam transaction, keeping signature verification enabled.
mkdir -p /etc/pki/rpm-gpg
cp -a /sysext/etc/pki/rpm-gpg/. /etc/pki/rpm-gpg/

# Use the installroot's own repo config now that it has fedora + rpmfusion
dnf5 -y install --installroot=/sysext --releasever=44 \
    --setopt=install_weak_deps=False \
    steam

dnf5 -y --installroot=/sysext clean all

# systemd-sysext refuses extensions that ship /usr/lib/os-release (it would
# override the host's version data when merged); fedora-release installs one.
rm -f /sysext/usr/lib/os-release
rm -rf /sysext/usr/lib/extensions

cp /steam-src/extension-release \
  /sysext/usr/lib/extension-release.d/extension-release.steam
