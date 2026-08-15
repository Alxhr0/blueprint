#!/bin/bash

set -ouex pipefail

export DEBIAN_FRONTEND=noninteractive

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/edward"/. /

if [ -L /root ]; then
  target=$(readlink -f /root)
  mkdir -p "$target"
else
  mkdir -p /root
fi

mkdir -p /var/lib/apt/lists/partial /var/cache/apt/archives/partial
mkdir -p /var/log/apt /var/lib/sgml-base /var/lib/xml-core

if [ ! -e /var/lib/dpkg ] || [ -L /var/lib/dpkg ] && [ ! -e /var/lib/dpkg ]; then
  mkdir -p /var/lib
  ln -sfnT ../../usr/lib/sysimage/dpkg /var/lib/dpkg
fi

apt-get update -y

DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends software-properties-common

add-apt-repository -y multiverse
add-apt-repository -y restricted
add-apt-repository -y ppa:graphics-drivers/ppa

curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/resolute.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/resolute.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list -o /etc/apt/sources.list.d/nvidia-container-toolkit.list
sed -i 's#^deb #deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] #' /etc/apt/sources.list.d/nvidia-container-toolkit.list

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
    docker-compose-v2
    podman
    flatpak
    steam-installer
    nvidia-driver-595
    nvidia-utils-595
    nvidia-container-toolkit
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
)

apt-get install -y --no-install-recommends "${PACKAGES[@]}"

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
