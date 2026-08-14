#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/dakota"/. /

mkdir -p /var/roothome

if [ -L /root ]; then
  target=$(readlink -f /root)
  mkdir -p "$target"
else
  mkdir -p /root
fi

# dakota is a distroless BuildStream image: no dnf/rpm/ostree.
# Packages are installed on first boot by the brew-preinstall.service
# from Brewfiles in /usr/share/ublue-os/homebrew/preinstall.d/ (brew
# and flatpak come pre-installed in the dakota base image).

mkdir -p /etc/systemd/user/graphical-session.target.wants
ln -sfn /usr/lib/systemd/user/brew-preinstall.service \
    /etc/systemd/user/graphical-session.target.wants/brew-preinstall.service

rm -rf /tmp/*
