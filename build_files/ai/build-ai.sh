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

# Runtime dependencies for Homebrew packages
apt-get update
apt-get install -y --no-install-recommends \
    libstdc++6 \
    libgcc-s1 \
    libc6 \
    libglib2.0-0 \
    libx11-6 \
    libxext6 \
    libxrandr2 \
    libxss1 \
    libxcursor1 \
    libxi6 \
    libxtst6 \
    libgtk-3-0 \
    libnss3 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libgbm1 \
    libasound2t64 \
    libfontconfig1 \
    libfreetype6 \
    libdbus-1-3 \
    libxcb1 \
    libxkbcommon0 \
    libatspi2.0-0 \
    file \
    xz-utils \
    jq
apt-get clean
rm -rf /var/lib/apt/lists/*

# Homebrew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Make brew available for all login shells
cat > /etc/profile.d/linuxbrew.sh << 'BREWPROFILE'
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
BREWPROFILE

# Brew taps
brew tap ublue-os/tap
brew tap ublue-os/experimental-tap
brew tap Kilo-Org/tap

# Trust taps (required for cask installs)
brew trust ublue-os/tap
brew trust ublue-os/experimental-tap

# Brew packages
brew install bun ollama llama.cpp opencode
brew install Kilo-Org/tap/kilo

# Brew casks (Linux)
brew install --cask antigravity-cli-linux
brew install --cask ublue-os/experimental-tap/cursor-linux
brew install --cask ublue-os/experimental-tap/kiro-cli-linux

# Non-brew installs
curl -fsSL https://pi.dev/install.sh | sh
