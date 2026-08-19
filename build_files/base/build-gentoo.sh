#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files"/. /
cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/gentoo"/. /

echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf
echo 'ACCEPT_KEYWORDS="~amd64"' >> /etc/portage/make.conf
echo 'FEATURES="-manifest getbinpkg binpkg-multi-instance binpkg-request-signature parallel-fetch parallel-install"' >> /etc/portage/make.conf
echo 'MAKEOPTS="-j$(nproc)"' >> /etc/portage/make.conf
echo 'EMERGE_DEFAULT_OPTS="--getbinpkg"' >> /etc/portage/make.conf

mkdir -p /etc/portage/package.license
echo "*/* *" > /etc/portage/package.license/00-all

mkdir -p /etc/portage/package.accept_keywords
echo "*/* ~amd64" > /etc/portage/package.accept_keywords/00-all

mkdir -p /etc/portage/package.use
echo "net-firewall/nftables json" > /etc/portage/package.use/nftables
echo "sys-kernel/installkernel dracut" > /etc/portage/package.use/installkernel

mkdir -p /etc/portage/binrepos.conf
printf '[gentoo]\npriority = 9959\nsync-uri = https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64/\nverify-signature = false\nlocation = /var/cache/binhost/gentoo\n' > /etc/portage/binrepos.conf/gentoo.conf

PACKAGES=(
    sys-kernel/gentoo-kernel-bin
    sys-kernel/linux-firmware
    sys-apps/systemd
    sys-kernel/dracut
    dev-util/ostree
    sys-fs/btrfs-progs
    sys-fs/dosfstools
    sys-fs/e2fsprogs
    sys-fs/xfsprogs
    sys-fs/cryptsetup
    sys-fs/lvm2
    net-misc/openssh
    net-misc/curl
    net-misc/wget
    net-wireless/iwd
    app-containers/skopeo
    app-containers/podman
    app-admin/sudo
    net-misc/chrony
    app-arch/cpio
    app-arch/xz-utils
    sys-apps/bubblewrap
    dev-libs/glib
    sys-apps/dbus
    sys-apps/shadow
)

emerge --verbose --deep --newuse "${PACKAGES[@]}"

echo "uninitialized" > /etc/machine-id
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
sed -i 's|^HOME=.*|HOME=/var/home|' /etc/default/useradd || true

systemctl enable systemd-networkd systemd-resolved chronyd sshd iwd
systemctl mask systemd-firstboot.service

printf 'L! /etc/resolv.conf - - - - /run/systemd/resolve/stub-resolv.conf\n' > /usr/lib/tmpfiles.d/resolv-conf.conf

KVER=$(basename "$(ls /usr/lib/modules | head -n 1)")
dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$KVER" "/usr/lib/modules/$KVER/initramfs.img"

printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' > /usr/lib/ostree/prepare-root.conf

printf 'd /var/home 0755 root root -\nd /var/srv 0755 root root -\nd /var/mnt 0755 root root -\nd /var/opt 0755 root root -\nd /var/usrlocal 0755 root root -\nd /var/roothome 0700 root root -\nd /run/media 0755 root root -\n' > /usr/lib/tmpfiles.d/bootc-base-dirs.conf

rm -rf /{boot,home,root,srv,mnt,var,usr/local,opt}

mkdir -p /sysroot /boot /usr/lib/ostree /var /var/tmp

ln -sT sysroot/ostree /ostree
ln -sT var/roothome /root
ln -sT var/srv /srv
ln -sT var/mnt /mnt
ln -sT var/opt /opt
ln -sT var/home /home
ln -sT ../var/usrlocal /usr/local
