#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files"/. /

mkdir -p /var/roothome

curl -fsSL \
  https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
  -o /etc/yum.repos.d/nvidia-container-toolkit.repo

dnf5 config-manager setopt skip_if_unavailable=0

dnf5 -y install \
    egl-wayland.x86_64 \
    egl-wayland.i686 \
    egl-wayland2.x86_64 \
    egl-wayland2.i686

if [ -x /tmp/akmods-nvidia/ublue-os/nvidia-install.sh ]; then
    IMAGE_NAME="${IMAGE_NAME:-edward}" \
    AKMODNV_PATH="/tmp/akmods-nvidia" \
    MULTILIB=1 \
    /tmp/akmods-nvidia/ublue-os/nvidia-install.sh
else
    echo "ERROR: NVIDIA installer was not found in /tmp/akmods-nvidia"
    find /tmp/akmods-nvidia -maxdepth 4 -type f -name '*nvidia*' -o -name 'nvidia-install.sh'
    exit 1
fi

rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json

if [ -e /usr/lib64/libnvidia-ml.so.1 ]; then
    ln -sf libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so
fi

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

cat <<EOF > /etc/profile.d/nix.sh
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
EOF

dnf5 -y config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo

dnf5 -y install fedora-workstation-repositories
dnf5 -y copr enable scottames/ghostty
dnf5 -y config-manager setopt google-chrome.enabled=1

PACKAGES=(
    google-chrome-stable
    steam
    ghostty
    kitty
    docker-ce 
    docker-ce-cli 
    containerd.io 
    docker-buildx-plugin 
    docker-compose-plugin
  )

dnf5 -y install "${PACKAGES[@]}"

dnf5 -y copr disable scottames/ghostty

mkdir -p /usr/etc/flatpak/system

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

flatpak install -y io.github.tanaybhomia.Whisp \
com.discordapp.Discord \
com.heroicgameslauncher.hgl \
it.mijorus.gearlever \
org.kde.krita \
com.ticktick.TickTick \
com.jeffser.Alpaca \
io.github.alainm23.planify \
io.gitlab.news_flash.NewsFlash \
moe.launcher.the-honkers-railway-launcher \
moe.launcher.sleepy-launcher \
moe.launcher.an-anime-game-launcher \
io.github.dvlv.boxbuddyrs \
net.runelite.RuneLite \
io.github.faridjaff.StickyNotesCanvas \
org.localsend.localsend_app \
net.lutris.Lutris

flatpak uninstall -y org.mozilla.firefox com.ranfdev.DistroShelf

systemctl disable podman.socket
systemctl enable docker
systemctl enable tailscaled.service

if command -v chcon > /dev/null; then
    chcon -R -t unconfined_mgmt_t /nix || true
fi
