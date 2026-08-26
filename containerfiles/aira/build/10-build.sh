#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Aira Build Script (Bazzite base, dnf5)
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

# Copy Flatpak preinstall files
mkdir -p /usr/share/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /usr/share/flatpak/preinstall.d/

# Copy Aira-specific system files (configs, kwin effects, services)
cp -rf /ctx/system_files/. /

shopt -u nullglob

echo "::endgroup::"

echo "::group:: Install Packages"

# Install the default packages and verify the DNF cache is working.
# gum is required by the default ujust recipes for interactive prompts.
dnf5 install -y tmux gum

# Aira-specific packages
PACKAGES=(
    git
    neovim
    kitty
    alacritty
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

# Aira-specific services
systemctl enable setup-nix.service
systemctl enable install-aira-configs.service
systemctl enable setup-kwin-effects.service

echo "::endgroup::"

echo "Aira build complete!"
