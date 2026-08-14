#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/holo"/. /

sed -i 's/^#Include = \/etc\/pacman.conf.d\/\*.conf/Include = \/etc\/pacman.conf.d\/\*.conf/' /etc/pacman.conf

pacman -Syu --noconfirm

pacman-key --init
pacman-key --recv-key F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47

pacman -U --noconfirm \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-27-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-27-1-any.pkg.tar.zst' \
    'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-27-1-any.pkg.tar.zst'

sed -i '/^\[core\]/i \
[cachyos-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\
[cachyos-core-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\
[cachyos-extra-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\
[cachyos]\nInclude = /etc/pacman.d/cachyos-mirrorlist\n' /etc/pacman.conf

pacman -Syu --noconfirm

PACKAGES=(
    linux-cachyos
    linux-firmware

    plasma-desktop
    plasma-workspace
    plasma-nm
    plasma-pa
    kdeplasma-addons
    breeze
    sddm
    konsole
    dolphin
    firefox
    kdeconnect
    plasma-login-manager

    steam
    proton
    gamemode
    lib32-gamemode
    mangohud
    lib32-mangohud
    wine-staging
    giflib
    lib32-giflib
    libpng
    lib32-libpng
    libldap
    lib32-libldap
    libvulkan
    lib32-libvulkan
    libxcomposite
    lib32-libxcomposite
    libxinerama
    lib32-libxinerama
    libxrandr
    lib32-libxrandr
    opencl-driver
    lib32-opencl-driver
    lib32-gnutls
    lib32-libpulse
    libgudev
    lib32-libgudev
    alsa-lib
    lib32-alsa-lib
    alsa-utils

    pipewire
    pipewire-alsa
    pipewire-audio
    pipewire-ffado
    pipewire-jack
    pipewire-pulse
    pipewire-zeroconf
    wireplumber
    sof-firmware
    alsa-firmware
    linux-firmware-intel
)

pacman -S --noconfirm --needed "${PACKAGES[@]}"

pacman -Scc --noconfirm

echo "uninitialized" > /etc/machine-id
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

systemctl --global enable pipewire.socket pipewire.service pipewire-pulse.service wireplumber.service

systemctl enable plasmalogin
