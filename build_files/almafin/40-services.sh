#!/bin/bash
set -xeuo pipefail

# Suspend then hibernate by default on laptops.
sed -i 's/#HandleLidSwitch=.*/HandleLidSwitch=suspend-then-hibernate/g' /usr/lib/systemd/logind.conf
sed -i 's/#HandleLidSwitchDocked=.*/HandleLidSwitchDocked=suspend-then-hibernate/g' /usr/lib/systemd/logind.conf
sed -i 's/#HandleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=suspend-then-hibernate/g' /usr/lib/systemd/logind.conf
sed -i 's/#SleepOperation=.*/SleepOperation=suspend-then-hibernate/g' /usr/lib/systemd/logind.conf

# Homebrew: install on first boot, then download + apply the user's bundle.
systemctl enable brew-setup.service
systemctl enable brew-bundle-download.service

# GNOME / desktop
systemctl enable gdm.service
systemctl enable dconf-update.service

# Networking + security
systemctl enable firewalld.service
systemctl enable fwupd.service
systemctl enable systemd-resolved.service

# bootc / updates
systemctl --global enable podman-auto-update.timer
systemctl enable uupd.timer
systemctl enable ublue-system-setup.service
systemctl --global enable ublue-user-setup.service

# Rechunker fix (PR #527 ordering drop-in lives alongside the base unit).
systemctl enable rechunker-group-fix.service

# AlmaFin/LTS extras
systemctl enable bluefin-lts-countme.timer
systemctl enable bootc-unified-storage.service

# Tailscale (installed best-effort in 31-packages.sh).
systemctl enable tailscaled.service || true

# We are a bootc image; rpm-ostree's own timer/units are not the update path.
systemctl disable rpm-ostree.service 2>/dev/null || true
systemctl mask rpm-ostree-countme.service rpm-ostree-countme.timer 2>/dev/null || true
systemctl mask bootc-fetch-apply-updates.timer bootc-fetch-apply-updates.service 2>/dev/null || true

# Quieter GDM logins.
authselect enable-feature with-silent-lastlog 2>/dev/null || true

# Keep resolved DNS working (matches bluefin-lts workaround).
sed -i -e "s@PrivateTmp=.*@PrivateTmp=no@g" /usr/lib/systemd/system/systemd-resolved.service
