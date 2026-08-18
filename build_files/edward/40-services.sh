#!/bin/bash
set -xeuo pipefail

systemctl set-default graphical.target
systemctl enable gdm.service
systemctl enable firewalld.service
systemctl enable fwupd.service
systemctl --global enable podman-auto-update.timer
systemctl enable brew-bundle.service
systemctl enable flatpak-preinstall.service
systemctl enable flatpak-appstream-refresh.service
systemctl enable ublue-system-setup.service
systemctl --global enable ublue-user-setup.service
systemctl enable docker.service
systemctl enable containerd.service
