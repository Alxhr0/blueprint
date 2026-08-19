# Edward overrides layered on top of common shared (rechunker fix, brew bundle, etc.)
chmod 0755 /usr/libexec/brew-bundle-download 2>/dev/null || true

# PR #527: rechunker ordering fix (drop-in lives in overrides/shared)
systemctl enable rechunker-group-fix.service

# Homebrew: download the user's Brewfile from upstream on first boot, then apply
systemctl enable brew-bundle-download.service
