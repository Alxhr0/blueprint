#!/usr/bin/env bash
set -xeuo pipefail

# Install prebuilt NVIDIA kernel modules + userspace driver from ublue akmods
dnf install -y /tmp/akmods-nvidia-open-rpms/*.rpm

# Blacklist nouveau
cat > /usr/lib/modprobe.d/00-nouveau-blacklist.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

# bootc kernel arguments — persist across upgrades
bootc kargs append -- \
	rd.driver.blacklist=nouveau \
	modprobe.blacklist=nouveau \
	nvidia-drm.modeset=1

# Rebuild initramfs to include nvidia modules
KVER="$(ls -1 /usr/lib/modules/ | grep -v fallback | head -1)"
if [[ -n "$KVER" ]]; then
	dracut --no-hostonly --kver "$KVER" --reproducible --tmpdir /boot --zstd \
		-v --add-drivers "nvidia nvidia_modeset nvidia_drm nvidia_uvm" \
		-f "/lib/modules/$KVER/initramfs.img"
fi

# nvidia-container-toolkit for rootless Podman CDI
dnf install -y nvidia-container-toolkit || true

# NVIDIA flatpak runtime sync (from common)
if [ -x /usr/libexec/ublue-nvidia-flatpak-runtime-sync ]; then
	/usr/libexec/ublue-nvidia-flatpak-runtime-sync || true
fi
