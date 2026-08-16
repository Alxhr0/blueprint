#!/usr/bin/env bash
set -xeuo pipefail

# Image cleanup
dnf clean all

rm -rf /.gitkeep
find /var -mindepth 1 -delete
find /boot -mindepth 1 -delete
mkdir -p /var /boot

# Make /usr/local writeable
ln -sf /var/usrlocal /usr/local

chmod 644 /usr/share/ublue-os/image-info.json

bootc container lint --fatal-warnings || true
