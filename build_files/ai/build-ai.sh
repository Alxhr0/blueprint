#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /

PACKAGES=(
    build-essential
    git
    curl
    wget
    unzip
    vim
    tmux
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

# Node.js 22.x (Pi requires >= 22.19.0)
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y --no-install-recommends nodejs
apt-get clean
rm -rf /var/lib/apt/lists/*

curl -fsSL https://bun.sh/install | bash
curl -fsSL https://pi.dev/install.sh | sh
bun add -g opencode-ai
bun add -g @kilocode/cli
curl -LsSf https://llama.app/install.sh | sh
curl -fsSL https://ollama.com/install.sh | sh
curl -fsSL https://cli.kiro.dev/install | bash
curl -fsSL https://antigravity.google/cli/install.sh | bash
curl https://cursor.com/install -fsS | bash
