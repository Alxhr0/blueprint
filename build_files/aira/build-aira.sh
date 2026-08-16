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

mkdir -p /usr/local/bin

curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install linux \
    --init none \
    --no-confirm \
    --extra-conf "sandbox = false"

echo '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' \
  > /etc/profile.d/nix.sh
PATH="/nix/var/nix/profiles/default/bin:${PATH}"

systemctl enable nix-daemon.socket nix-daemon.service

mkdir -p /etc/nix && \
echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

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

if command -v chcon > /dev/null; then
    chcon -R -u system_u -r object_r -t unconfined_mgmt_t /nix 2>/dev/null || true
fi
