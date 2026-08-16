#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/holo"/. /

sed -i 's/^#Include = \/etc\/pacman.conf.d\/\*.conf/Include = \/etc\/pacman.conf.d\/\*.conf/' /etc/pacman.conf

if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        echo -e '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf
    fi
fi

rm -f /etc/pacman.d/mirrorlist

pacman -Syu --noconfirm

/ctx/core/arch-cachy.sh

PACKAGES=(
    linux-firmware
    linux-cachyos
    linux-cachyos-headers
    mkinitcpio
    jq

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

pacman -S --noconfirm --needed --ask=4 "${PACKAGES[@]}"

if pacman -Q linux >/dev/null 2>&1; then
    pacman -Rdd --noconfirm linux
fi

mkinitcpio -P

pacman -Scc --noconfirm

echo "uninitialized" > /etc/machine-id
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

systemctl --global enable pipewire.socket pipewire.service pipewire-pulse.service wireplumber.service

systemctl enable plasmalogin
