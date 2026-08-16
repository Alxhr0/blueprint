#!/usr/bin/env bash
set -xeuo pipefail

# Edward-specific customizations

# Install Nix
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon

echo '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' \
  > /etc/profile.d/nix.sh

mkdir -p /etc/nix && \
echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Enable user services (only if they exist to avoid dangling symlinks)
mkdir -p /etc/systemd/user/graphical-session.target.wants
if [ -f /usr/lib/systemd/user/brew-preinstall.service ]; then
    ln -sfn /usr/lib/systemd/user/brew-preinstall.service \
        /etc/systemd/user/graphical-session.target.wants/brew-preinstall.service
fi

mkdir -p /etc/systemd/user/default.target.wants
if [ -f /usr/lib/systemd/user/homepage.service ]; then
    ln -sfn /usr/lib/systemd/user/homepage.service \
        /etc/systemd/user/default.target.wants/homepage.service
fi
if [ -f /usr/lib/systemd/user/ai.service ]; then
    ln -sfn /usr/lib/systemd/user/ai.service \
        /etc/systemd/user/default.target.wants/ai.service
fi
