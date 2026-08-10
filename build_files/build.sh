#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files"/. /

mkdir -p /var/roothome

if [ -L /root ]; then
  target=$(readlink -f /root)
  mkdir -p "$target"
else
  mkdir -p /root
fi

curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install linux \
    --init none \
    --no-confirm \
    --no-modify-profile \
    --prefer-upstream-nix

mkdir -p /nix

dnf5 -y install fedora-workstation-repositories
dnf5 -y copr enable lionheartp/Hyprland 
dnf5 -y config-manager setopt google-chrome.enabled=1

PACKAGES=(
    hyprland
    waybar
    quickshell
    google-chrome-stable
    steam
    tmux
    ghostty
  )

dnf5 -y install "${PACKAGES[@]}"

dnf5 -y copr disable lionheartp/Hyprland 

mkdir -p /usr/etc/flatpak/system

cat <<EOF >> /usr/etc/flatpak/system/install
org.mozilla.firefox
org.kde.okular
org.gnome.Calculator
com.valvesoftware.Steam
EOF

cat <<EOF >> /usr/etc/flatpak/system/remove
org.gnome.Tour
EOF

systemctl enable podman.socket
systemctl enable tailscaled.service

if command -v chcon > /dev/null; then
    chcon -R -t unconfined_mgmt_t /nix || true
fi
