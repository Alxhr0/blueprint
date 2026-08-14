#!/bin/bash
set -ouex pipefail

export DEBIAN_FRONTEND=noninteractive

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/fsdk"/. /

if [ -L /root ]; then
  target=$(readlink -f /root)
  mkdir -p "$target"
else
  mkdir -p /root
fi

mkdir -p /var/lib/dpkg /var/lib/apt/lists/partial /var/log/apt /var/log/journal /var/log
rm -rf /var/log/apt /var/log/journal

apt-get update -y
apt-get install -y --no-install-recommends software-properties-common

mkdir -p /var/cache/apt/archives/partial

add-apt-repository -y multiverse

apt-get update -y

PACKAGES=(
    skopeo
    buildah
    podman
    docker.io
    python3
    python3-pip
    python3-venv
    jq
    yq
    gh
    ostree
    libostree-dev
    bubblewrap
    uidmap
    slirp4netns
    fuse-overlayfs
    curl
    wget
    git
    ca-certificates
    sudo
)

DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${PACKAGES[@]}"

flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo

systemctl enable podman
systemctl enable docker
systemctl enable systemd-resolved

systemctl enable brew-setup.service
systemctl enable brew-update.timer
systemctl enable brew-upgrade.timer

mkdir -p /etc/systemd/user/graphical-session.target.wants
ln -sfn /usr/lib/systemd/user/brew-preinstall.service \
    /etc/systemd/user/graphical-session.target.wants/brew-preinstall.service

mkdir -p /etc/systemd/user/default.target.wants
ln -sfn /usr/lib/systemd/user/homepage.service \
    /etc/systemd/user/default.target.wants/homepage.service
ln -sfn /usr/lib/systemd/user/ai.service \
    /etc/systemd/user/default.target.wants/ai.service

mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/00-rootless.toml <<'EOF'
kargs = ["shared.enable-journal-worker=no", "cgroup_no_v1=all"]
EOF

apt-get clean -y
rm -rf /var/lib/apt/lists/* /tmp/*
find /run -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
