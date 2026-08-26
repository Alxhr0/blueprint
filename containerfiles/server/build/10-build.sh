#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Server Build Script (uCore base, dnf5)
###############################################################################

# Read IMAGE_NAME from /etc/environment if not set
if [[ -z "${IMAGE_NAME:-}" ]] && [[ -f /etc/environment ]]; then
    # shellcheck disable=SC1091
    . /etc/environment
fi

echo "::group:: Overlay Brew Integration Files"

# Brew integration files from @ublue-os/brew OCI (tarball, systemd services,
# shell integration)
rsync -rvK /ctx/oci/brew/ /

echo "::endgroup::"

echo "::group:: Copy Custom Files"

shopt -s nullglob

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
mkdir -p /usr/share/ublue-os/just/
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >>/usr/share/ublue-os/just/60-custom.just

# Server is headless: no flatpaks (no custom/server/flatpaks on purpose)

# Copy Server-specific system files (quadlets, lid-switch drop-in, autostart)
cp -rf /ctx/system_files/. /

shopt -u nullglob

echo "::endgroup::"

echo "::group:: Install Packages"

# Install the default packages and verify the DNF cache is working.
# gum is required by the default ujust recipes for interactive prompts.
dnf5 install -y tmux gum

# Server-specific packages
PACKAGES=(
    openssh-server
    git
    htop
    podman
)
dnf5 install -y --skip-unavailable \
    --setopt=install_weak_deps=False \
    "${PACKAGES[@]}"

echo "::endgroup::"

echo "::group:: System Configuration"

systemctl enable podman.socket
systemctl enable brew-setup.service
systemctl enable brew-update.timer
systemctl enable brew-upgrade.timer

# Server-specific services
systemctl enable cockpit.service
systemctl enable sshd.service
# Enable quadlet auto-start (linger + podman-restart) for server users
chmod +x /usr/share/ublue-os/server/enable-quadlet-autostart.sh
systemctl enable cargoyard-quadlet-autostart.service

echo "::endgroup::"

echo "Server build complete!"
