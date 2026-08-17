#!/bin/bash
set ${CI:+-x} -euo pipefail

# Get qualified kernel version
KERNEL_SUFFIX=""
QUALIFIED_KERNEL="$(rpm -qa | grep -P 'kernel-(|'"$KERNEL_SUFFIX"'-)(\d+\.\d+\.\d+)' | sed -E 's/kernel-(|'"$KERNEL_SUFFIX"'-)//' | tail -n 1)"

# Install custom-built NVIDIA akmods RPMs
NVIDIA_KMOD_RPMS=()
if ls /tmp/akmods-nvidia-open-rpms/kmods/kmod-nvidia-*"${QUALIFIED_KERNEL}"*.rpm 1>/dev/null 2>&1; then
    NVIDIA_KMOD_RPMS=(/tmp/akmods-nvidia-open-rpms/kmods/kmod-nvidia-*"${QUALIFIED_KERNEL}"*.rpm)
elif ls /tmp/akmods-nvidia-open-rpms/kmods/kmod-nvidia-*.rpm 1>/dev/null 2>&1; then
    mapfile -t NVIDIA_KMOD_RPMS < <(find /tmp/akmods-nvidia-open-rpms/kmods -name 'kmod-nvidia-*.rpm' -print)
fi

if ((${#NVIDIA_KMOD_RPMS[@]} == 0)); then
    echo "ERROR: no custom akmods RPMs found for kernel ${QUALIFIED_KERNEL}"
    echo "Ensure the akmods-edward image was built for this kernel and pushed to GHCR"
    exit 1
fi

echo "Installing custom NVIDIA akmods RPMs"
mapfile -t NVIDIA_UBLUE_RPMS < <(find /tmp/akmods-nvidia-open-rpms/ublue-os -maxdepth 1 -type f -name '*.rpm' -print 2>/dev/null)
dnf -y install "${NVIDIA_KMOD_RPMS[@]}" "${NVIDIA_UBLUE_RPMS[@]}"

# If the module was built, install it
MODPATH="/usr/lib/modules/${QUALIFIED_KERNEL}/extra/nvidia/nvidia.ko.xz"
if [ -f "${MODPATH}" ]; then
    depmod -a "${QUALIFIED_KERNEL}"
fi

tee /usr/lib/modprobe.d/00-nouveau-blacklist.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/00-nvidia.toml <<'EOF'
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1"]
EOF

# Rebuild initramfs with NVIDIA support
/usr/bin/dracut --no-hostonly --kver "$QUALIFIED_KERNEL" --reproducible --tmpdir /boot --zstd -v --add ostree -f "/lib/modules/${QUALIFIED_KERNEL}/initramfs.img"

# Enable NVIDIA services
systemctl enable nvidia-persistenced.service 2>/dev/null || true
systemctl enable nvidia-suspend.service 2>/dev/null || true
systemctl enable nvidia-resume.service 2>/dev/null || true
systemctl enable nvidia-hibernate.service 2>/dev/null || true
systemctl enable ublue-nvidia-flatpak-runtime-sync.service 2>/dev/null || true

# CDI configuration
nvidia-ctk config --set nvidia-container-cli.no-cgroups --in-place
