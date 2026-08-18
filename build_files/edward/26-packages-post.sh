#!/usr/bin/env bash
set -xeuo pipefail

# Enable Flatpak by default
mkdir -p /etc/flatpak/remotes.d
curl --retry 3 -o /etc/flatpak/remotes.d/flathub.flatpakrepo "https://dl.flathub.org/repo/flathub.flatpakrepo" || true

# Generate initramfs after all packages installed
depmod -a "$(ls -1 /lib/modules/ | tail -1)"
KERNEL_SUFFIX=""
QUALIFIED_KERNEL="$(rpm -qa | grep -P 'kernel-(|'"${KERNEL_SUFFIX}"'-)(\d+\.\d+\.\d+)' | sed -E 's/kernel-(|'"${KERNEL_SUFFIX}"'-)//' | tail -n 1)"
/usr/bin/dracut --no-hostonly --kver "$QUALIFIED_KERNEL" --reproducible --tmpdir /boot --zstd -v --add ostree -f "/lib/modules/$QUALIFIED_KERNEL/initramfs.img"

# Add linuxbrew to sudo secure_path
sed -Ei "s/secure_path = (.*)/secure_path = \1:\/home\/linuxbrew\/.linuxbrew\/bin/" /etc/sudoers
