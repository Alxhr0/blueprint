#!/usr/bin/env bash
set -xeuo pipefail

READ_PKGS="python3 /run/context/build_scripts/scripts/read-packages"
PKGS_TOML="/run/context/build_scripts/packages/base.toml"

# Install packages from manifest
readarray -t INSTALL_PKGS < <($READ_PKGS "$PKGS_TOML" install)

dnf -y install "${INSTALL_PKGS[@]}"
