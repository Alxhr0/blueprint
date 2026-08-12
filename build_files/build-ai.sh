#!/bin/bash
set -ouex pipefail

PACKAGES=(
    build-essential
    git
    curl
    wget
    vim
    nano
    python3
    python3-pip
    ca-certificates
    sudo
    locales
    tzdata
)

apt-get update
apt-get install -y --no-install-recommends "${PACKAGES[@]}"
apt-get clean
rm -rf /var/lib/apt/lists/*
