#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files.arch"/. /

sed -i 's/^#Include = \/etc\/pacman.conf.d\/\*.conf/Include = \/etc\/pacman.conf.d\/\*.conf/' /etc/pacman.conf

mkdir -p /var/cache/pacman/pkg
mkdir -p /sysroot

pacman -Syu --noconfirm

PACKAGES=(
    base
    bubblewrap
    dracut
    linux
    linux-firmware
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

systemctl enable systemd-boot-update.service
