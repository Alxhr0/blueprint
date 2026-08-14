#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/nixos"/. /

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

  system.stateVersion = "24.05";
}
EOF

nixos-rebuild switch --flake /etc/nixos#default 2>/dev/null || nixos-rebuild switch

mkdir -p /output/etc/bootc
cp /etc/nixos/configuration.nix /output/etc/bootc/configuration.nix
cp /etc/bootc.toml /output/etc/bootc/bootc.toml 2>/dev/null || true

mkdir -p /output/var/lib/bootc
cp -r /var/lib/bootc/* /output/var/lib/bootc/ 2>/dev/null || true
