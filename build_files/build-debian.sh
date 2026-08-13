#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files"/. /
cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/debian"/. /

apt-get update -y

PACKAGES=(
    btrfs-progs
    bubblewrap
    dosfstools
    e2fsprogs
    fdisk
    firmware-linux-free
    linux-image-generic
    netplan.io
    libnss-resolve
    libnss-myhostname
    openssh-server
    skopeo
    systemd
    systemd-boot
    systemd-resolved
    xfsprogs
    libostree-dev
    sudo
    curl
    unzip
    git
    ca-certificates
    dracut
    podman
)

DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PACKAGES[@]}"

cp /boot/vmlinuz-* "$(find /usr/lib/modules -maxdepth 1 -type d | tail -n 1)/vmlinuz"

systemctl enable systemd-networkd systemd-resolved ssh

printf 'L! /etc/resolv.conf - - - - /run/systemd/resolve/stub-resolv.conf\n' \
    > /usr/lib/tmpfiles.d/resolv-conf.conf

mkdir -p /etc/netplan
printf 'network:\n  version: 2\n  ethernets:\n    all-en:\n      match:\n        name: en*\n      dhcp4: true\n      dhcp4-overrides:\n        use-domains: true\n      dhcp6: true\n      dhcp6-overrides:\n        use-domains: true\n    all-eth:\n      match:\n        name: eth*\n      dhcp4: true\n      dhcp4-overrides:\n        use-domains: true\n      dhcp6: true\n      dhcp6-overrides:\n        use-domains: true\n' > /etc/netplan/90-default.yaml

sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true

sed -i 's|^HOME=.*|HOME=/var/home|' /etc/default/useradd

apt-get clean -y

mkdir -p /usr/lib/sysimage
if [ -d /var/lib/dpkg ]; then cp -a /var/lib/dpkg /usr/lib/sysimage/dpkg; fi

rm -rf /var/lib/dpkg
mkdir -p /var/lib
ln -sfnT ../../usr/lib/sysimage/dpkg /var/lib/dpkg

rm -rf /{boot,home,root,srv,mnt,var,usr/local}

mkdir -p /sysroot /boot /usr/lib/ostree /var

ln -sfnT sysroot/ostree /ostree
ln -sfnT var/roothome /root
ln -sfnT var/srv /srv
ln -sfnT var/mnt /mnt
ln -sfnT var/opt /opt
ln -sfnT var/home /home
ln -sfnT var/usrlocal /usr/local

printf 'd /var/home 0755 root root -\nd /var/srv 0755 root root -\nd /var/mnt 0755 root root -\nd /var/opt 0755 root root -\nd /var/usrlocal 0755 root root -\nd /var/roothome 0700 root root -\nd /run/media 0755 root root -\n' > /usr/lib/tmpfiles.d/bootc-base-dirs.conf

KVER=$(basename "$(find /usr/lib/modules -maxdepth 1 -mindepth 1 -type d | tail -n 1)")
dracut --force --no-hostonly --reproducible --zstd --verbose --kver "${KVER}" "/usr/lib/modules/${KVER}/initramfs.img"

printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' > /usr/lib/ostree/prepare-root.conf

rm -rf /var/lib/apt/lists/* /tmp/* /run/*
