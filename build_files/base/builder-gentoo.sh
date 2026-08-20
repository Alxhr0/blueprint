#!/bin/bash
set -ouex pipefail

# Portage bootstrap (moved from Containerfile.gentoo into this self-contained
# builder script; the unified root Containerfile has no separate portage stage).
if [ ! -d /var/db/repos/gentoo/profiles ]; then
    emerge-webrsync || emerge --sync
fi

rm -f /etc/portage/make.profile
ln -s /var/db/repos/gentoo/profiles/default/linux/amd64/23.0/systemd /etc/portage/make.profile

mkdir -p /etc/portage/binrepos.conf
printf '[gentoo]\npriority = 9959\nsync-uri = https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64/\nverify-signature = false\nlocation = /var/cache/binhost/gentoo\n' > /etc/portage/binrepos.conf/gentoo.conf

getuto

emerge --getbinpkg --verbose \
    dev-util/ostree \
    net-misc/openssh \
    sys-devel/gcc \
    dev-util/pkgconf \
    dev-vcs/git \
    app-arch/cpio \
    app-arch/xz-utils \
    app-arch/bzip2 \
    dev-go/go-md2man

git clone "https://github.com/bootc-dev/bootc.git" /tmp/bootc
make -C /tmp/bootc bin install-all DESTDIR=/output
rm -rf /tmp/bootc
