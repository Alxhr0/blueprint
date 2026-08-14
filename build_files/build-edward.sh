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

if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
fi

pacman -Syu --noconfirm

pacman -S --noconfirm --needed curl git gcc make jq

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

PACKAGES=(
    gnome
    gnome-terminal
    gnome-tweaks
    dconf
    pipewire
    pipewire-pulse
    wireplumber
    podman
    docker
    docker-buildx
    docker-compose
    ghostty
    tailscale
    flatpak
    steam
    nvidia-open
    nvidia-utils
    lib32-nvidia-utils
    nvidia-settings
    nvidia-container-toolkit
)

pacman -S --noconfirm --needed "${PACKAGES[@]}"

flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo

mkdir -p /var/roothome

dconf update

mkdir -p /etc/xdg/systemd/user/sockets.target.wants
ln -sfn /usr/lib/systemd/user/podman.socket \
    /etc/xdg/systemd/user/sockets.target.wants/podman.socket

# user services
systemctl --global enable pipewire.socket pipewire.service pipewire-pulse.service wireplumber.service

systemctl enable gdm
systemctl enable docker
systemctl enable podman
systemctl enable tailscaled

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

KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E '\.img$' | tail -n 1)")"
DRACUT_NO_XATTR=1 dracut --force --no-hostonly --reproducible --zstd --verbose \
    --kver "$KERNEL_VERSION" "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

pacman -Scc --noconfirm
find /etc/ -name "*.pacnew" -type f -delete
rm -rf /tmp/*
find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
