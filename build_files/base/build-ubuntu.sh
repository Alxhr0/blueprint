#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files"/. /
cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/ubuntu"/. /

apt-get update -y

PACKAGES=(
    btrfs-progs
    bubblewrap
    dosfstools
    e2fsprogs
    fdisk
    linux-firmware
    linux-image-generic
    netplan.io
    network-manager
    openssh-server
    skopeo
    systemd
    systemd-resolved
    systemd-boot
    xfsprogs
    libostree-dev
    sudo
    curl
    wget
    git
    ca-certificates
    dracut
    podman
    libcap2-bin
    chrony
    iwd
    golang-go
    go-md2man
)

DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PACKAGES[@]}"

setcap cap_setuid+ep /usr/bin/newuidmap && chmod -s /usr/bin/newuidmap
setcap cap_setgid+ep /usr/bin/newgidmap && chmod -s /usr/bin/newgidmap

cp /boot/vmlinuz-* "$(find /usr/lib/modules -maxdepth 1 -type d | tail -n 1)/vmlinuz"

systemctl enable systemd-networkd systemd-resolved ssh NetworkManager
systemctl mask systemd-firstboot.service

printf 'L! /etc/resolv.conf - - - - /run/systemd/resolve/stub-resolv.conf\n' \
    > /usr/lib/tmpfiles.d/resolv-conf.conf

mkdir -p /etc/netplan
printf 'network:\n  version: 2\n  ethernets:\n    all-en:\n      match:\n        name: en*\n      dhcp4: true\n      dhcp4-overrides:\n        use-domains: true\n      dhcp6: true\n      dhcp6-overrides:\n        use-domains: true\n    all-eth:\n      match:\n        name: eth*\n      dhcp4: true\n      dhcp4-overrides:\n        use-domains: true\n      dhcp6: true\n      dhcp6-overrides:\n        use-domains: true\n' > /etc/netplan/90-default.yaml

sed -i 's|^HOME=.*|HOME=/var/home|' /etc/default/useradd

apt-get clean -y
mkdir -p /var/cache/apt/archives/partial

mkdir -p /usr/lib/sysimage
if [ -d /var/lib/dpkg ]; then cp -a /var/lib/dpkg /usr/lib/sysimage/dpkg; fi

rm -rf /var/lib/dpkg
mkdir -p /var/lib
ln -sfnT ../../usr/lib/sysimage/dpkg /var/lib/dpkg

rm -rf /{boot,home,root,srv,mnt,var,usr/local,opt}

mkdir -p /sysroot /boot /usr/lib/ostree /var

ln -sT sysroot/ostree /ostree
ln -sT var/roothome /root
ln -sT var/srv /srv
ln -sT var/mnt /mnt
ln -sT var/opt /opt
ln -sT var/home /home
ln -sT var/usrlocal /usr/local

printf 'd /var/home 0755 root root -\nd /var/srv 0755 root root -\nd /var/mnt 0755 root root -\nd /var/opt 0755 root root -\nd /var/usrlocal 0755 root root -\nd /var/roothome 0700 root root -\nd /run/media 0755 root root -\n' > /usr/lib/tmpfiles.d/bootc-base-dirs.conf

mkdir -p /var/tmp

KVER=$(basename "$(find /usr/lib/modules -maxdepth 1 -mindepth 1 -type d | tail -n 1)")
dracut --force --no-hostonly --reproducible --zstd --verbose --kver "${KVER}" "/usr/lib/modules/${KVER}/initramfs.img"

printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' > /usr/lib/ostree/prepare-root.conf

rm -rf /var/lib/apt/lists/* /tmp/*
find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
