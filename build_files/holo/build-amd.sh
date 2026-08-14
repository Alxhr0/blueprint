#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/holo"/. /

sed -i 's/^#Include = \/etc\/pacman.conf.d\/\*.conf/Include = \/etc\/pacman.conf.d\/\*.conf/' /etc/pacman.conf

pacman -Syu --noconfirm

/ctx/core/arch-cachy.sh

PACKAGES=(
    linux-firmware
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

/ctx/core/ogc-kernel.sh

pacman -Scc --noconfirm

echo "uninitialized" > /etc/machine-id
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

systemctl --global enable pipewire.socket pipewire.service pipewire-pulse.service wireplumber.service

systemctl enable plasmalogin
