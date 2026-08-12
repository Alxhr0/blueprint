#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files.arch"/. /

sed -i 's/^#Include = \/etc\/pacman.conf.d\/\*.conf/Include = \/etc\/pacman.conf.d\/\*.conf/' /etc/pacman.conf

pacman -Syu --noconfirm

PACKAGES=(
    base
    bootc
    linux
    linux-firmware
    ostree
    sudo
    systemd
    udev
)

pacman -S --noconfirm --needed "${PACKAGES[@]}"

systemctl enable systemd-boot-update.service
