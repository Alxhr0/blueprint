#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files"/. /
cp -avf "/ctx/system_files.edward"/. /
mkdir -p /var/roothome

# Recompile the dconf database so custom keybindings in distro.d take effect
dconf update

# Quadlet auto-applies the [Install] WantedBy=default.target in the .container
# files under /etc/containers/systemd/users/, so the always-on containers start
# automatically in each user session. Only the podman API socket needs an
# explicit enable symlink here, as it takes effect at next login.
mkdir -p /etc/xdg/systemd/user/sockets.target.wants
ln -sfn /usr/lib/systemd/user/podman.socket \
    /etc/xdg/systemd/user/sockets.target.wants/podman.socket

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

dnf5 -y config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo

dnf5 -y install fedora-workstation-repositories
dnf5 -y copr enable scottames/ghostty

dnf5 -y install --nogpgcheck --repofrompath \
  'terra,https://repos.fyralabs.com/terra$releasever' \
  terra-release
dnf5 -y install terra-release-extras

PACKAGES=(
    ghostty
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)

dnf5 -y install --skip-unavailable \
  --setopt=install_weak_deps=False \
  "${PACKAGES[@]}"

dnf5 -y copr disable scottames/ghostty
mkdir -p "$(readlink -f /usr/local)"

curl -fsSL https://ollama.com/install.sh | sh

mkdir -p /var/lib/extensions
cp -a /tmp/steam-sysext /var/lib/extensions/steam
systemctl enable systemd-sysext.service

systemctl disable podman.socket
systemctl enable docker
systemctl enable tailscaled.service
systemctl enable brew-setup.service
systemctl enable brew-update.timer
systemctl enable brew-upgrade.timer
systemctl enable brew-bundle-packages.service

if command -v chcon > /dev/null; then
    chcon -R -t unconfined_mgmt_t /nix || true
fi
