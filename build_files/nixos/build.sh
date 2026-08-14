#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/nixos"/. /

nix-channel --add https://nixos.org/channels/nixos-26.05 nixos
nix-channel --update

mkdir -p /etc/nixos
cat > /etc/nixos/configuration.nix <<'EOF'
{ config, pkgs, ... }:

{
  imports = [ ];

  bootc.enable = true;

  environment.systemPackages = with pkgs; [
    bootc
    git
    curl
    wget
    jq
  ];

  services.bootc = {
    enable = true;
    autoUpdate = false;
  };

  system.stateVersion = "26.05";
}
EOF

nixos-rebuild build --flake /etc/nixos#default 2>/dev/null || nixos-rebuild build

SYSTEM_PATH=$(readlink -f /run/current-system)

mkdir -p /sysroot/ostree/repo
ostree init --mode=bare-user --no-fsync --path=/sysroot/ostree/repo

ostree commit --repo=/sysroot/ostree/repo \
  --branch=blueprint/nixos \
  --subject="Blueprint NixOS bootc image" \
  --add-metadata-string="version=$(date +%Y%m%d)" \
  --no-xattrs \
  "${SYSTEM_PATH}"

ostree summary --repo=/sysroot/ostree/repo --update --ref=blueprint/nixos

mkdir -p /sysroot/ostree/deploy/blueprint/nixos/0

ln -sT sysroot/ostree /ostree
ln -sT var/roothome /root
ln -sT var/srv /srv
ln -sT var/mnt /mnt
ln -sT var/opt /opt
ln -sT var/home /home
ln -sT var/usrlocal /usr/local

printf 'd /var/home 0755 root root -\nd /var/srv 0755 root root -\nd /var/mnt 0755 root root -\nd /var/opt 0755 root root -\nd /var/usrlocal 0755 root root -\nd /var/roothome 0700 root root -\nd /run/media 0755 root root -\n' > /usr/lib/tmpfiles.d/bootc-base-dirs.conf

printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' > /usr/lib/ostree/prepare-root.conf

mkdir -p /output/etc/bootc
cp /etc/nixos/configuration.nix /output/etc/bootc/configuration.nix
cp /etc/bootc.toml /output/etc/bootc/bootc.toml 2>/dev/null || true

mkdir -p /output/etc/nixos
cp /etc/nixos/configuration.nix /output/etc/nixos/configuration.nix
cp /etc/nixos/flake.nix /output/etc/nixos/flake.nix 2>/dev/null || true
cp /etc/nixos/lock.json /output/etc/nixos/lock.json 2>/dev/null || true

mkdir -p /output/var/lib/bootc
cp -r /var/lib/bootc/* /output/var/lib/bootc/ 2>/dev/null || true
