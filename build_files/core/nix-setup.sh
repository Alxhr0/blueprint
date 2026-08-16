#!/usr/bin/env bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install linux \
    --init none \
    --no-confirm \
    --extra-conf "sandbox = false"

echo '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' \
  > /etc/profile.d/nix.sh
PATH="/nix/var/nix/profiles/default/bin:${PATH}"

systemctl enable nix-daemon.socket nix-daemon.service

mkdir -p /etc/nix && \
echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
