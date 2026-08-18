#!/usr/bin/env bash
set -xeuo pipefail

READ_PKGS="python3 /run/context/build_scripts/scripts/read-packages"
PKGS_TOML="/run/context/build_scripts/packages/base.toml"

# Install packages from manifest
readarray -t INSTALL_PKGS < <($READ_PKGS "$PKGS_TOML" install)

# Docker CE repo (must come before docker package install)
curl -fsSL https://download.docker.com/linux/centos/docker-ce.repo \
    -o /etc/yum.repos.d/docker-ce.repo

dnf -y install "${INSTALL_PKGS[@]}"
