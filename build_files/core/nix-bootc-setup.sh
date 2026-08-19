#!/usr/bin/env bash
set -euo pipefail

# nix-bootc-setup.sh — Install Nix on an immutable bootc/ostree image.
#
# On bootc images the root filesystem is read-only, so Nix cannot write to
# /nix directly.  This script:
#   1. Creates /var/nix (writable) and symlinks /nix -> /var/nix via tmpfiles.d
#   2. Sets up a systemd bind-mount unit so /nix is available early in boot
#   3. Installs Nix in daemon mode (--no-start, since systemd is not running
#      during container builds)
#   4. Configures the nix-daemon service and per-user profile directories
#   5. Makes Nix available in all shell contexts (login, SSH, systemd)
#
# Usage: source this script from a build script running inside a container,
#        or call it directly.  It is idempotent.

# ---------------------------------------------------------------------------
# 1. Prepare /var/nix and the /nix -> /var/nix symlink via tmpfiles.d
# ---------------------------------------------------------------------------
install -d -m 0755 /var/nix

cat > /usr/lib/tmpfiles.d/nix.conf <<'EOF'
d /var/nix 0755 root root -
L+ /nix - - - - /var/nix
EOF

# Apply immediately (best-effort — tmpfiles may already have run at boot)
systemd-tmpfiles --create /usr/lib/tmpfiles.d/nix.conf 2>/dev/null || true

# Ensure /nix exists for the rest of this script (container build phase)
if [ ! -d /nix ]; then
    rm -f /nix
    ln -sfn /var/nix /nix
fi

# ---------------------------------------------------------------------------
# 2. Systemd bind-mount unit for /nix
# ---------------------------------------------------------------------------
install -d -m 0755 /etc/systemd/system

cat > /etc/systemd/system/nix.mount <<'EOF'
[Unit]
Description=Bind mount /var/nix to /nix
After=local-fs.target

[Mount]
What=/var/nix
Where=/nix
Type=none
Options=bind

[Install]
WantedBy=local-fs.target
EOF

# ---------------------------------------------------------------------------
# 3. Install Nix (daemon mode, no-start for container builds)
# ---------------------------------------------------------------------------
if ! command -v nix > /dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | \
        sh -s -- --daemon --no-start
fi

# ---------------------------------------------------------------------------
# 4. Enable experimental features (idempotent)
# ---------------------------------------------------------------------------
install -d -m 0755 /etc/nix
if ! grep -q "^experimental-features = nix-command flakes" /etc/nix/nix.conf 2>/dev/null; then
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
fi

# ---------------------------------------------------------------------------
# 5. Fix ownership and permissions on /nix for daemon operation
# ---------------------------------------------------------------------------
chown root:nixbld /nix
chmod 0775 /nix

install -d -m 0755 /nix/var/nix
chown root:nixbld /nix/var/nix

# ---------------------------------------------------------------------------
# 6. Per-user Nix profile directories for existing non-root users
# ---------------------------------------------------------------------------
while IFS=: read -r username _ uid _ _ _ shell; do
    if [[ "$uid" -ge 1000 ]] && [[ "$shell" != */nologin ]] && [[ "$shell" != */false ]]; then
        install -d -m 0755 "/nix/var/nix/profiles/per-user/${username}"
        chown "${username}:nixbld" "/nix/var/nix/profiles/per-user/${username}"
    fi
done < /etc/passwd

# ---------------------------------------------------------------------------
# 7. Add existing non-root users to the nixbld group
# ---------------------------------------------------------------------------
while IFS=: read -r username _ uid _ _ _ shell; do
    if [[ "$uid" -ge 1000 ]] && [[ "$shell" != */nologin ]] && [[ "$shell" != */false ]]; then
        usermod -aG nixbld "${username}" || true
    fi
done < /etc/passwd

# ---------------------------------------------------------------------------
# 8. Make Nix available in all contexts (login shells, systemd, SSH)
# ---------------------------------------------------------------------------
install -d -m 0755 /etc/environment.d
cat > /etc/environment.d/50-nix.conf <<'EOF'
PATH="/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:${PATH}"
EOF

cat > /etc/profile.d/nix-daemon.sh <<'SH'
# shellcheck shell=bash disable=SC1091
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
SH
chmod 0644 /etc/profile.d/nix-daemon.sh

# ---------------------------------------------------------------------------
# 9. Enable the nix-daemon service so it starts at boot
# ---------------------------------------------------------------------------
systemctl enable nix-daemon.socket nix-daemon.service 2>/dev/null || true

# ---------------------------------------------------------------------------
# 10. SELinux: allow Nix to manage /nix on Fedora/RHEL-based systems
# ---------------------------------------------------------------------------
if command -v chcon > /dev/null 2>&1; then
    chcon -R -u system_u -r object_r -t unconfined_mgmt_t /nix 2>/dev/null || true
fi

echo "nix-bootc-setup: Nix installed and configured for bootc."
