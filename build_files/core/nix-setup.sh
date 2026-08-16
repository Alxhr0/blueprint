#!/usr/bin/env bash
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon

echo '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' \
  > /etc/profile.d/nix.sh
PATH="/nix/var/nix/profiles/default/bin:${PATH}"

mkdir -p /etc/nix && \
echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
