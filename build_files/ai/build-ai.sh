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

# Homebrew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Brew taps
brew tap ublue-os/tap
brew tap ublue-os/experimental-tap
brew tap Kilo-Org/tap

# Brew packages
brew install bun ollama llama.cpp opencode
brew install Kilo-Org/tap/kilo

# Brew casks (Linux)
brew install --cask antigravity-cli-linux
brew install --cask ublue-os/experimental-tap/cursor-linux
brew install --cask ublue-os/experimental-tap/kiro-cli-linux

# Non-brew installs
curl -fsSL https://pi.dev/install.sh | sh
