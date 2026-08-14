#!/bin/bash
set -ouex pipefail

if [ -d /nix/var/nix/db ]; then
    chmod -R 1777 /nix/var/nix/db
else
    mkdir -p /nix/var/nix/db
    chmod 1777 /nix/var/nix/db
fi

curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install linux \
    --init none \
    --no-confirm \
    --no-modify-profile \
    --prefer-upstream-nix

mkdir -p /nix

cat <<EOF > /etc/profile.d/nix.sh
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
EOF
