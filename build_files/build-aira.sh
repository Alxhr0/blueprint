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

dnf5 -y install --skip-unavailable \
  --setopt=install_weak_deps=False \
  git \
  tmux \
  neovim \
  kitty \
  alacritty

git clone https://github.com/tmux-plugins/tpm /root/.tmux/plugins/tpm
/root/.tmux/plugins/tpm/bin/install_plugins

curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install linux \
    --init none \
    --no-confirm \
    --no-modify-profile \
    --prefer-upstream-nix

mkdir -p /nix

cat <<EOF > /etc/profile.d/nix.sh
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
EOF

dnf5 -y install --nogpgcheck --repofrompath \
  'terra,https://repos.fyralabs.com/terra$releasever' \
  terra-release
dnf5 -y install terra-release-extras

dnf -y copr enable lizardbyte/stable

systemctl enable sshd.service

dnf -y copr disable lizardbyte/stable
