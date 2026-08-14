#!/bin/bash
set -eoux pipefail

if rpm -q nvidia-gpu-firmware &>/dev/null; then
    dnf5 -y remove nvidia-gpu-firmware
fi

IMAGE_NAME="bluefin" AKMODNV_PATH="/tmp/rpms/nvidia" MULTILIB=0 \
    /tmp/rpms/nvidia/ublue-os/nvidia-install.sh

rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json

ln -sf libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so

mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/00-nvidia.toml <<'EOF'
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1", "initcall_blacklist=simpledrm_platform_driver_init"]
EOF

nvidia-ctk config --set nvidia-container-cli.no-cgroups --in-place

QUALIFIED_KERNEL="$(dnf5 repoquery --installed --queryformat='%{evr}.%{arch}' kernel)"
/usr/bin/dracut --no-hostonly --kver "$QUALIFIED_KERNEL" --reproducible \
    -v --add "ostree dmsquash-live dmsquash-live-autooverlay" \
    -f "/lib/modules/$QUALIFIED_KERNEL/initramfs.img"
chmod 0600 "/lib/modules/$QUALIFIED_KERNEL/initramfs.img"
