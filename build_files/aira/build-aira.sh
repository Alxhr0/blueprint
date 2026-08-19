#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/aira"/. /

mkdir -p /var/roothome

if [ -L /root ]; then
  target=$(readlink -f /root)
  mkdir -p "$target"
else
  mkdir -p /root
fi

systemctl enable setup-nix.service

dnf5 -y install terra-release terra-release-extras || true

dnf -y copr enable lizardbyte/stable

PACKAGES=(
  git
  tmux
  neovim
  kitty
  alacritty
  Sunshine
)

dnf5 -y install --skip-unavailable \
  --setopt=install_weak_deps=False \
  "${PACKAGES[@]}"

dnf -y copr disable lizardbyte/stable

dnf5 -y copr enable infinality/kwin-effects-better-blur-dx || true
dnf5 -y install kwin-effects-better-blur-dx || echo "Better Blur DX COPR package not available, skipping"

dnf5 -y copr disable infinality/kwin-effects-better-blur-dx
/usr/bin/setup-better-blur-dx.sh / || true

systemctl enable sshd.service

systemctl enable install-aira-configs.service

systemctl enable setup-kwin-effects.service
