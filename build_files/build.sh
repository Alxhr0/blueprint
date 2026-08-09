#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files"/. /

curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install linux \
    --init none \
    --no-modify-profile  

mkdir -p /nix

dnf5 install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release terra-gpg-keys

dnf5 -y copr enable lionheartp/Hyprland 
dnf5 -y config-manager setopt google-chrome.enabled=1
rpm --import https://packages.microsoft.com/keys/microsoft.asc
sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'

PACKAGES=(
    hyprland
    waybar
    quickshell
    google-chrome-stable
    code
    google-noto-fonts-common
    google-noto-fonts-cjk
    google-noto-fonts-emoji
    google-noto-fonts
    wl-kpbtr
    steam
    tmux
    ghostty
  )

dnf -y install "${PACKAGES[@]}"

dnf5 -y copr disable lionheartp/Hyprland 

dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf config-manager setopt tailscale-stable.enabled=0
dnf -y install --enablerepo='tailscale-stable' tailscale

systemctl enable podman.socket
systemctl enable tailscaled.service

if command -v chcon > /dev/null; then
    chcon -R -t unconfined_mgmt_t /nix || true
fi
