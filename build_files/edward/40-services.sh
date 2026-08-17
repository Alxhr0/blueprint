#!/bin/bash
set -xeuo pipefail

systemctl set-default graphical.target
systemctl enable gdm.service
systemctl enable firewalld.service
systemctl enable fwupd.service
systemctl --global enable podman-auto-update.timer
systemctl disable rpm-ostree.service 2>/dev/null || true
systemctl enable dconf-update.service 2>/dev/null || true
systemctl enable tailscaled.service
systemctl enable brew-setup.service
systemctl enable brew-bundle.service
systemctl enable brew-update.timer
systemctl enable brew-upgrade.timer
systemctl enable flatpak-preinstall.service
systemctl enable flatpak-appstream-refresh.service
systemctl enable ublue-system-setup.service
systemctl --global enable ublue-user-setup.service
systemctl enable docker.service
systemctl enable containerd.service
systemctl mask bootc-fetch-apply-updates.timer bootc-fetch-apply-updates.service
systemctl mask rpm-ostree-countme.service rpm-ostree-countme.timer

# Disable sshd by default
systemctl disable sshd.service 2>/dev/null || true

# Enable polkit rules for fingerprint sensors via fprintd
authselect enable-feature with-fingerprint

# Enable systemd-resolved
sed -i -e "s@PrivateTmp=.*@PrivateTmp=no@g" /usr/lib/systemd/system/systemd-resolved.service
systemctl enable systemd-resolved.service
