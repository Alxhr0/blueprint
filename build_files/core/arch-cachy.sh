#!/bin/bash
set -ouex pipefail

CACHYOS_KEY="F3B607488DB35A47"

if ! pacman-key -l | grep -q "${CACHYOS_KEY}"; then
    pacman-key --init
    pacman-key --recv-key "${CACHYOS_KEY}" --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key "${CACHYOS_KEY}"
fi

if ! grep -q '^\[cachyos\]' /etc/pacman.conf; then
    pacman -U --noconfirm \
        'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
        'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-27-1-any.pkg.tar.zst' \
        'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-27-1-any.pkg.tar.zst' \
        'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-27-1-any.pkg.tar.zst'

    sed -i '/^\[core\]/i \
[cachyos]\nInclude = /etc/pacman.d/cachyos-mirrorlist\n' /etc/pacman.conf
fi

# Thank you for finding this Alx!
sed -i 's/^Architecture = auto/Architecture = x86_64 x86_64_v3 x86_64-v4/' /etc/pacman.conf

if ! grep -q '^DisableSandboxNetwork' /etc/pacman.conf; then
    sed -i '/^\[options\]/a DisableSandboxNetwork' /etc/pacman.conf
fi

pacman -Syu --noconfirm
