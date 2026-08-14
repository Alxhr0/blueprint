#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/edward"/. /

if [ -L /root ]; then
  target=$(readlink -f /root)
  mkdir -p "$target"
else
  mkdir -p /root
fi

apt-get update -y

PACKAGES=(
    ubuntu-desktop
    gdm3
    firefox
    gnome-terminal
    nautilus
    gnome-control-center
    gnome-shell
    pipewire
    wireplumber
    pulseaudio-utils
    docker.io
    docker-compose
    podman
    flatpak
    steam
    nvidia-driver-550
    nvidia-utils-550
    lib32-nvidia-utils-550
    tailscale
    curl
    git
    build-essential
    jq
    python3
    python3-pip
    nodejs
    npm
    gh
    code
)

DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PACKAGES[@]}"

/ctx/core/nix-setup.sh

flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo

mkdir -p /var/roothome

dconf update

systemctl enable gdm3
systemctl enable docker
systemctl enable podman
systemctl enable tailscaled
systemctl enable systemd-resolved

systemctl enable brew-setup.service
systemctl enable brew-update.timer
systemctl enable brew-upgrade.timer

mkdir -p /etc/systemd/user/graphical-session.target.wants
ln -sfn /usr/lib/systemd/user/brew-preinstall.service \
    /etc/systemd/user/graphical-session.target.wants/brew-preinstall.service

mkdir -p /etc/systemd/user/default.target.wants
ln -sfn /usr/lib/systemd/user/homepage.service \
    /etc/systemd/user/default.target.wants/homepage.service
ln -sfn /usr/lib/systemd/user/ai.service \
    /etc/systemd/user/default.target.wants/ai.service

mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/00-nvidia.toml <<'EOF'
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1", "initcall_blacklist=simpledrm_platform_driver_init"]
EOF

nvidia-ctk config --set nvidia-container-cli.no-cgroups --in-place

apt-get clean -y
rm -rf /var/lib/apt/lists/* /tmp/*
find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
