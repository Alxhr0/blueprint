#!/usr/bin/env bash
set -xeuo pipefail

READ_PKGS="python3 /run/context/build_scripts/scripts/read-packages"
PKGS_TOML="/run/context/build_scripts/packages/base.toml"

# Remove packages that conflict with image content
readarray -t REMOVE_PKGS < <($READ_PKGS "$PKGS_TOML" remove)
dnf -y remove "${REMOVE_PKGS[@]}"

# Main package install from base/EPEL repos
readarray -t INSTALL_PKGS    < <($READ_PKGS "$PKGS_TOML" install)
readarray -t EXCLUDED_PKGS   < <($READ_PKGS "$PKGS_TOML" install_excluded)

EXCLUDE_ARGS=()
for pkg in "${EXCLUDED_PKGS[@]}"; do
    EXCLUDE_ARGS+=(-x "$pkg")
done

dnf -y install \
    "${EXCLUDE_ARGS[@]}" \
    "${INSTALL_PKGS[@]}"

# Versionlock GNOME components to prevent downgrades to EL10 base versions
readarray -t VERSIONLOCK_PKGS < <($READ_PKGS "$PKGS_TOML" versionlock_gnome)
dnf versionlock add "${VERSIONLOCK_PKGS[@]}"

# Everything that depends on external repositories should be after this.
# Make sure to set them as disabled and enable them only when you are going to use their packages.

dnf config-manager --add-repo "https://pkgs.tailscale.com/stable/centos/10/tailscale.repo"
dnf config-manager --set-disabled "tailscale-stable"
dnf -y --enablerepo "tailscale-stable" install \
    tailscale

# This is required so homebrew works indefinitely.
dnf -y --setopt=install_weak_deps=False install gcc
