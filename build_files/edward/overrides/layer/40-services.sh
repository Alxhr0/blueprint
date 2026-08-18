#!/bin/bash
set -xeuo pipefail

chmod 0755 /usr/libexec/brew-bundle-download 2>/dev/null || true

systemctl enable docker.service
systemctl enable containerd.service
systemctl enable add-user-to-docker.service

# PR #527: rechunker ordering fix for bluefin-lts testing
systemctl enable rechunker-group-fix.service

# Homebrew: download Brewfile from upstream on first boot, then apply bundle
systemctl enable brew-bundle-download.service
