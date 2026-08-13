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


mkdir -p /sysroot /boot /usr/lib/ostree /var

ln -sfnT sysroot/ostree /ostree
ln -sfnT var/roothome /root
ln -sfnT var/srv /srv
ln -sfnT var/mnt /mnt
ln -sfnT var/opt /opt
ln -sfnT var/home /home
ln -sfnT var/usrlocal /usr/local

printf 'd /var/home 0755 root root -\nd /var/srv 0755 root root -\nd /var/mnt 0755 root root -\nd /var/opt 0755 root root -\nd /var/usrlocal 0755 root root -\nd /var/roothome 0700 root root -\nd /run/media 0755 root root -\n' > /usr/lib/tmpfiles.d/bootc-base-dirs.conf

rm -rf /var/cache/* /var/log/*
find /var -mindepth 1 -maxdepth 1 ! -name cache ! -name log -exec rm -rf {} +
rm -rf /{boot,home,root,srv,mnt,usr/local}

rm -rf /tmp/* /run/*

