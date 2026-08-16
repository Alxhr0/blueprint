#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/edward"/. /

zypper refresh

zypper addrepo --refresh --no-gpg-checks https://download.nvidia.com/opensuse/tumbleweed NVIDIA
zypper --gpg-auto-import-keys refresh NVIDIA

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
    btrfsprogs
    dosfstools
    e2fsprogs
    xfsprogs
    openssh
    skopeo
    systemd
    dracut
    ostree
    nvidia-driver
    nvidia-compute
    nvidia-uvm
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

zypper install -y "${PACKAGES[@]}"

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

if command -v nvidia-ctk >/dev/null 2>&1; then
    nvidia-ctk config --set nvidia-container-cli.no-cgroups --in-place
fi

KVER=$(basename "$(find /usr/lib/modules -maxdepth 1 -mindepth 1 -type d ! -name '*.img' | sort -V | tail -n 1)")

mkdir -p /usr/lib/modprobe.d
printf 'blacklist nouveau\noptions nouveau modeset=0\n' > /usr/lib/modprobe.d/00-nouveau-blacklist.conf

mkdir -p /usr/lib/dracut/dracut.conf.d
printf 'force_drivers+=" i915 amdgpu nvidia nvidia_modeset nvidia_uvm nvidia_drm "\n' > /usr/lib/dracut/dracut.conf.d/99-nvidia.conf

if command -v dracut >/dev/null 2>&1; then
    dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$KVER" "/usr/lib/modules/$KVER/initramfs.img"
fi

for _nv_unit in nvidia-persistenced nvidia-suspend nvidia-resume nvidia-hibernate; do
    if [ -e "/usr/lib/systemd/system/${_nv_unit}.service" ]; then
        systemctl enable "${_nv_unit}.service"
    fi
done
unset _nv_unit

zypper clean -a

rm -rf /tmp/*
find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
