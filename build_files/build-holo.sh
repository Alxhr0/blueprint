#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files.holo"/. /

sed -i 's/^#Include = \/etc\/pacman.conf.d\/\*.conf/Include = \/etc\/pacman.conf.d\/\*.conf/' /etc/pacman.conf

mkdir -p /var/cache/pacman/pkg
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

awk -F'=' '/\/var/ {gsub(/ /,"",$2); print $2}' /etc/pacman.conf | \
while read -r varpath; do
    if [ -n "$varpath" ]; then
        newpath="/usr/lib/sysimage/${varpath#/var/}"
        mkdir -p "$(dirname "${newpath}")"
        mv -v "${varpath}" "${newpath}"
    fi
done

sed -i -e "/= \*\\/var/ s/^#//" -e "s@= \*/var@= /usr/lib/sysimage@g" -e "/DownloadUser/d" /etc/pacman.conf

systemctl enable systemd-boot-update.service

systemctl mask systemd-firstboot.service

systemctl enable NetworkManager.service

systemctl enable sddm.service

KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E '\.img$' | tail -n 1)")"

DRACUT_NO_XATTR=1 dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$KERNEL_VERSION" "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' > /usr/lib/ostree/prepare-root.conf

printf 'd /var/home 0755 root root -\nd /var/srv 0755 root root -\nd /var/mnt 0755 root root -\nd /var/opt 0755 root root -\nd /var/usrlocal 0755 root root -\nd /var/roothome 0700 root root -\nd /run/media 0755 root root -\n' > /usr/lib/tmpfiles.d/bootc-base-dirs.conf

rm -rf /tmp/* /run/*

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
