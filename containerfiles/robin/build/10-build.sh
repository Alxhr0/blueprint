#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Robin Build Script (arch-bootc base, pacman)
###############################################################################
# Base image: ghcr.io/huntedraven7/arch-bootc:testing — Arch Linux bootc base.
# This script:
#   - installs KDE Plasma + SDDM
#   - installs NVIDIA drivers (stock kernel)
#   - wires in flatpak preinstalls and custom ujust recipes
#   - overlays system_files
###############################################################################

if [[ -z "${IMAGE_NAME:-}" ]] && [[ -f /etc/environment ]]; then
	. /etc/environment
fi

echo "::group:: Copy System Files"

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/robin"/. /

echo "::endgroup::"

echo "::group:: Configure Pacman"

sed -i 's/^#Include = \/etc\/pacman.conf.d\/\*.conf/Include = \/etc\/pacman.conf.d\/\*.conf/' /etc/pacman.conf

if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
	sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
	if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
		echo -e '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf
	fi
fi

rm -f /etc/pacman.d/mirrorlist

echo "::endgroup::"

echo "::group:: Install Packages"

pacman -Syu --noconfirm

PACKAGES=(
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

	nvidia-open
	nvidia-utils
	lib32-nvidia-utils

	flatpak
	fish
	git
	rsync
	tmux
	gum
	unzip
	unrar
	p7zip
	xdg-user-dirs
)

pacman -S --noconfirm --needed "${PACKAGES[@]}"

echo "::endgroup::"

echo "::group:: Copy Custom Files"

shopt -s nullglob

mkdir -p /usr/share/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /usr/share/flatpak/preinstall.d/

mkdir -p /usr/share/just/
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >>/usr/share/just/60-custom.just

shopt -u nullglob

echo "::endgroup::"

echo "::group:: System Configuration"

systemctl enable sddm.service
systemctl set-default graphical.target
systemctl enable podman.socket
systemctl enable NetworkManager.service

systemctl enable robin-firstboot.service
systemctl enable robin-flatpak-preinstall.service

echo "::endgroup::"

echo "robin build complete!"
