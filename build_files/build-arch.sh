#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files"/. /
cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/arch"/. /

sed -i 's/^#Include = \/etc\/pacman.conf.d\/\*.conf/Include = \/etc\/pacman.conf.d\/\*.conf/' /etc/pacman.conf

# Build against the stock pacman layout first: archlinux:latest ships its
# installed packages tracked in /var/lib/pacman, so /var paths must stay in
# place until after every pacman operation.
mkdir -p /sysroot

pacman -Syu --noconfirm

PACKAGES=(
    base
    bubblewrap
    cpio
    dracut
    efibootmgr
    iwd
    linux
    linux-firmware
    networkmanager
    ostree
    btrfs-progs
    e2fsprogs
    xfsprogs
    dosfstools
    skopeo
    dbus
    dbus-glib
    glib2
    shadow
    openssh
    sudo
    systemd
    udev
)

pacman -S --noconfirm --needed "${PACKAGES[@]}"

pacman -Scc --noconfirm

echo "uninitialized" > /etc/machine-id
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

ln -sT /usr/lib/systemd/system/getty@.service /usr/lib/systemd/system/autovt@.service

sed -i 's|^HOME=.*|HOME=/var/home|' /etc/default/useradd

rm -rf /usr/opt
mv /opt /usr

sed -i '/DisableSandboxNetwork/d' /etc/pacman.conf

find /etc/ -name "*.pacnew" -type f -delete

systemctl enable systemd-boot-update.service

systemctl mask systemd-firstboot.service

systemctl enable NetworkManager.service

KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E '\.img$' | tail -n 1)")"

DRACUT_NO_XATTR=1 dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$KERNEL_VERSION" "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' > /usr/lib/ostree/prepare-root.conf

printf 'd /var/home 0755 root root -\nd /var/srv 0755 root root -\nd /var/mnt 0755 root root -\nd /var/opt 0755 root root -\nd /var/usrlocal 0755 root root -\nd /var/roothome 0700 root root -\nd /run/media 0755 root root -\n' > /usr/lib/tmpfiles.d/bootc-base-dirs.conf

rm -rf /tmp/* /run/*

# Relocate pacman state into the image: /var is wiped below (and recreated
# empty at runtime) while /usr persists. Shipping the real local DB here lets
# derived images do proper `pacman -Syu` upgrades instead of blind installs
# over untracked files.
mkdir -p /usr/lib/sysimage/var/lib /usr/lib/sysimage/cache/pacman/pkg
cp -a /var/lib/pacman /usr/lib/sysimage/var/lib/pacman
sed -i -e 's|^#DBPath[[:space:]]*=[[:space:]]*/var/lib/pacman/|DBPath = /usr/lib/sysimage/var/lib/pacman/|' \
       -e 's|^#CacheDir[[:space:]]*=[[:space:]]*/var/cache/pacman/pkg/|CacheDir = /usr/lib/sysimage/cache/pacman/pkg/|' \
       /etc/pacman.conf

rm -rf /{boot,home,root,srv,mnt,var,usr/local}

rm -rf /usr/lib/sysimage/{log,cache/pacman/pkg}

rm -rf /{build,packages}

mkdir -p /sysroot /boot /usr/lib/ostree /var

ln -sT sysroot/ostree /ostree

ln -sT var/roothome /root

ln -sT var/srv /srv

ln -sT var/mnt /mnt

ln -sT var/opt /opt

ln -sT var/home /home

ln -sT var/usrlocal /usr/local
