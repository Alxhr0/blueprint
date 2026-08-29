#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Edward Build Script (arch-bootc base, pacman)
###############################################################################
# Base image: ghcr.io/huntedraven7/arch-bootc:testing — minimal Arch bootc.
# This script:
#   - installs the pinned OGC linux-ogc kernel + headers from the akmods cache
#     and the nvidia modules built against them
#   - installs a GNOME desktop (gnome + gdm)
#   - wires in the ublue @ublue-os/brew integration
#   - overlays flatpak preinstalls, custom ujust recipes, and system_files
###############################################################################

# Read build-time settings from /etc/environment if not already in the env
if [[ -z "${IMAGE_NAME:-}" ]] && [[ -f /etc/environment ]]; then
	# shellcheck disable=SC1091
	. /etc/environment
fi

echo "::group:: pacman Configuration"

# bootc bases ship an unconfigured/missing multilib + pacman.d includes.
sed -i 's/^#Include = \/etc\/pacman.conf.d\/\*.conf/Include = \/etc\/pacman.conf.d\/\*.conf/' /etc/pacman.conf
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
	sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
	if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
		printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >>/etc/pacman.conf
	fi
fi

echo "::endgroup::"

echo "::group:: System Update"

# arch-bootc ships the stock `linux` kernel but wipes /boot during its own
# build, so /boot/vmlinuz-linux does not exist and the stock kernel's
# mkinitcpio hook fails during pacman -Syu. Remove it first so the system
# update does not try to regenerate initramfs for a missing kernel.
if pacman -Q linux >/dev/null 2>&1; then
    pacman -Rdd --noconfirm linux
fi

rm -rf /var/log
pacman -Syu --noconfirm

# mkinitcpio must be installed before the OGC kernel below (its install hook
# regenerates the initramfs); the arch-bootc base uses dracut instead.
pacman -S --noconfirm --needed mkinitcpio

echo "::endgroup::"

echo "::group:: Install OGC Kernel + nvidia modules (akmods cache)"

AKMODS_CACHE="/ctx/oci/akmods"
KERNEL_INFO="${AKMODS_CACHE}/kernel-info"
KERNEL_VERSION=""
if [[ -f "${KERNEL_INFO}" ]]; then
    # shellcheck disable=SC1090
    . "${KERNEL_INFO}"
    echo "akmods kernel version: ${KERNEL_VERSION}"
else
    echo "WARNING: akmods cache kernel-info missing" >&2
fi

if [[ -d "${AKMODS_CACHE}/kernel" ]]; then
    pacman -U --noconfirm \
        "${AKMODS_CACHE}"/kernel/linux-ogc-[0-9]*.pkg.tar.zst \
        "${AKMODS_CACHE}"/kernel/linux-ogc-headers-*.pkg.tar.zst
else
    echo "WARNING: akmods cache kernel packages not found at ${AKMODS_CACHE}/kernel" >&2
fi

echo "::endgroup::"

echo "::group:: Install Packages"

# GNOME desktop + runtime tooling.
PACKAGES=(
	gnome
	gdm
	gnome-tweaks
	dconf-editor
	firefox

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
	xfsprogs
)

pacman -S --noconfirm --needed --ask=4 "${PACKAGES[@]}"

echo "::endgroup::"

echo "::group:: Install nvidia modules for kernel ${KERNEL_VERSION:-}"

if [[ -n "${KERNEL_VERSION:-}" ]] && [[ -d "${AKMODS_CACHE}/kmods/${KERNEL_VERSION}/nvidia" ]]; then
	MODDIR="/usr/lib/modules/${KERNEL_VERSION}"
	if [[ -d "${MODDIR}" ]]; then
		mkdir -p "${MODDIR}/extra/nvidia"
		cp -fav "${AKMODS_CACHE}/kmods/${KERNEL_VERSION}/nvidia"/. "${MODDIR}/extra/nvidia/"
		depmod -a "${KERNEL_VERSION}"
	else
		echo "WARNING: module dir ${MODDIR} not present; cannot install nvidia modules" >&2
	fi
else
	echo "Skipping nvidia module install (no module tree in cache for this kernel)" >&2
fi

echo "::endgroup::"

echo "::group:: XFS support (rebase) "

# The root filesystem this image rebases onto is XFS. Make sure the active
# kernel can mount it and the initramfs carries the xfs module + xfsprogs so a
# `bootc switch` onto this image against an existing XFS / survives.
if [[ -n "${KERNEL_VERSION:-}" ]]; then
	MODDIR="/usr/lib/modules/${KERNEL_VERSION}"
	XFS_OK=0
	if [[ -f "${MODDIR}/kernel/fs/xfs/xfs.ko" ]] || [[ -f "${MODDIR}/kernel/fs/xfs/xfs.ko.zst" ]]; then
		XFS_OK=1
	elif [[ -f "${MODDIR}/build/.config" ]] && grep -qE '^CONFIG_XFS_FS=[ym]' "${MODDIR}/build/.config"; then
		XFS_OK=1
	fi
	if [[ "${XFS_OK}" -ne 1 ]]; then
		echo "ERROR: no XFS support for kernel ${KERNEL_VERSION} (XFS root may not mount)" >&2
		echo "  expected ${MODDIR}/kernel/fs/xfs/xfs.ko[.zst] or CONFIG_XFS_FS in ${MODDIR}/build/.config" >&2
		exit 1
	fi
	# Pin the module into the initramfs regardless of build-time autodetection.
	# base /etc/mkinitcpio.conf ships MODULES=(); set it to carry xfs.
	sed -i 's/^MODULES=()/MODULES=(xfs)/' /etc/mkinitcpio.conf
fi

echo "::endgroup::"

echo "::group:: Rebuild Initramfs"

mkinitcpio -P

echo "::endgroup::"

echo "::group:: Overlay Brew Integration Files"

# Brew integration files from @ublue-os/brew OCI (systemd services, shell
# integration). ujust recipes import our 60-custom.just via ublue's entry.
rsync -rvK /ctx/oci/brew/ /

echo "::endgroup::"

echo "::group:: Copy Custom Files"

shopt -s nullglob

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
mkdir -p /usr/share/ublue-os/just/
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >>/usr/share/ublue-os/just/60-custom.just

# Copy Flatpak preinstall files
mkdir -p /usr/share/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /usr/share/flatpak/preinstall.d/

# Copy system files (quadlets, launchers, desktop entries)
cp -rf /ctx/system_files/. /

shopt -u nullglob

echo "::endgroup::"

echo "::group:: System Configuration"

systemctl enable gdm.service
systemctl set-default graphical.target
systemctl enable podman.socket
systemctl enable brew-setup.service
systemctl enable brew-update.timer
systemctl enable brew-upgrade.timer
systemctl enable NetworkManager.service

# First-boot flatpak + user setup, from system_files.
systemctl enable edward-firstboot.service
systemctl enable edward-flatpak-preinstall.service

echo "::endgroup::"

echo "edward build complete!"
