#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/edward"/. /
cp -avf "/ctx/system_files/arch"/. /

sed -i 's/^#Include = \/etc\/pacman.conf.d\/\*.conf/Include = \/etc\/pacman.conf.d\/\*.conf/' /etc/pacman.conf

if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        echo -e '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf
    fi
fi

rm -f /etc/pacman.d/mirrorlist

pacman -Syu --noconfirm

PACKAGES=(
    firefox
    pipewire
    wireplumber
    pulseaudio
    podman
    docker
    docker-compose
    flatpak
    tailscale
    curl
    wget
    git
    jq
    python3
    python3-pip
    nodejs
    npm
    gh
    hplip
    cups
    sudo
    chrony
    iwd
    bubblewrap
    cpio
    libcap-progs
    kernel-firmware
    btrfs-progs
    dosfstools
    e2fsprogs
    xfsprogs
    openssh
    skopeo
    systemd
    dracut
    ostree
    nvidia-open
    nvidia-utils
    lib32-nvidia-utils
    plasma-desktop
    plasma-workspace
    plasma-nm
    plasma-pa
    kdeplasma-addons
    breeze
    sddm
    konsole
    dolphin
    kdeconnect
    plasma-login-manager
    ffmpeg
    fwupd
    fzf
    unzip
    zstd
    distrobox
    gcc
    make
    rust
    cargo
)

pacman -S --noconfirm --needed "${PACKAGES[@]}"

# Uncomment to enable KDE Unstable repository for latest Plasma packages
# [kde-unstable]
# Include = /etc/pacman.d/mirrorlist

flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo

systemctl set-default graphical.target
systemctl enable sddm
systemctl enable chronyd sshd iwd
systemctl enable tailscaled
systemctl enable docker
systemctl enable podman

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

mkdir -p /usr/lib/modprobe.d
printf 'blacklist nouveau\noptions nouveau modeset=0\n' > /usr/lib/modprobe.d/00-nouveau-blacklist.conf

KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E '\.img$' | tail -n 1)")"
if [ -n "$KERNEL_VERSION" ]; then
    mkinitcpio -P
fi

for _nv_unit in nvidia-persistenced nvidia-suspend nvidia-resume nvidia-hibernate; do
    if [ -e "/usr/lib/systemd/system/${_nv_unit}.service" ]; then
        systemctl enable "${_nv_unit}.service"
    fi
done
unset _nv_unit

setcap cap_setuid+ep /usr/bin/newuidmap && chmod -s /usr/bin/newuidmap
setcap cap_setgid+ep /usr/bin/newgidmap && chmod -s /usr/bin/newgidmap

pacman -Scc --noconfirm

rm -rf /tmp/*
find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
