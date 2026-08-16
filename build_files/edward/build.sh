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

DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    -o Dpkg::Options::="--no-triggers" \
    software-properties-common

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
    firefox
    pipewire
    wireplumber
    pulseaudio-utils
    docker.io
    docker-compose-v2
    podman
    flatpak
    linux-headers-generic
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
    login 
    cups 
    hplip 
    gir1.2-gda-5.0 
    ubuntu-desktop-minimal 
)

DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-missing --no-install-recommends \
    -o Dpkg::Options::="--no-triggers" \
    "${PACKAGES[@]}"

# Triggers suppressed above so kernel/NVIDIA postinst scripts don't run dracut
# with the ostree/bootc dracut modules before the ostree environment is ready.
dpkg --configure -a
update-ca-certificates 2>/dev/null || true
ldconfig

/ctx/core/nix-setup.sh

flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo

mkdir -p /var/roothome

dconf update

systemctl enable gdm3
systemctl set-default graphical.target
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

# The base stage builds the initramfs before the NVIDIA driver exists, so it
# cannot contain the nvidia modules or the nouveau blacklist. Rebuild it here.
# (Mirrors tunaOS's nvidia-debian overlay.)
KVER=$(basename "$(find /usr/lib/modules -maxdepth 1 -mindepth 1 -type d ! -name '*.img' | sort -V | tail -n 1)")

# If apt upgraded the kernel during this build, stage its vmlinuz where bootc
# expects it before rebuilding the initramfs for it.
if [ -e "/boot/vmlinuz-${KVER}" ]; then
    cp "/boot/vmlinuz-${KVER}" "/usr/lib/modules/${KVER}/vmlinuz"
fi

mkdir -p /usr/lib/modprobe.d
printf 'blacklist nouveau\noptions nouveau modeset=0\n' > /usr/lib/modprobe.d/00-nouveau-blacklist.conf

mkdir -p /usr/lib/dracut/dracut.conf.d
printf 'force_drivers+=" i915 amdgpu nvidia nvidia_modeset nvidia_uvm nvidia_drm "\n' > /usr/lib/dracut/dracut.conf.d/99-nvidia.conf

if command -v dkms > /dev/null 2>&1; then
    dkms autoinstall -k "${KVER}"
fi

if [ -n "${KVER}" ] && [ -e "/usr/lib/modules/${KVER}/vmlinuz" ] && command -v dracut > /dev/null 2>&1; then
    mkdir -p /boot
    dracut --force --no-hostonly --reproducible --tmpdir /boot "/usr/lib/modules/${KVER}/initramfs.img" "${KVER}"
fi

for _nv_unit in nvidia-persistenced nvidia-suspend nvidia-resume nvidia-hibernate; do
    if [ -e "/usr/lib/systemd/system/${_nv_unit}.service" ]; then
        systemctl enable "${_nv_unit}.service"
    fi
done
unset _nv_unit

apt-get clean -y
rm -rf /var/lib/apt/lists/* /tmp/*
find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
