#!/usr/bin/bash
set -euo pipefail

# Enable quadlet auto-start for server users.
# Rootless user quadlets (in /etc/containers/systemd/users/) only run while the
# user's systemd manager is alive. Enabling "linger" starts the user manager at
# boot (no login required) and keeps it alive after logout. Enabling
# podman-restart makes "restart: always" quadlets survive reboots.
#
# Runs at boot for every real user (UID >= 1000) so it works for whichever
# account was created during provisioning, and for accounts added later.

for d in /var/home/* /home/*; do
    [ -d "$d" ] || continue
    user=$(basename "$d")
    id "$user" &>/dev/null || continue
    uid=$(id -u "$user")
    [ "$uid" -ge 1000 ] || continue

    # Start/keep the user manager alive at boot and after logout.
    loginctl enable-linger "$user" 2>/dev/null || true

    # Enable podman-restart for the user so restart:always quadlets come back
    # after a reboot. Symlink into default.target.wants so it does not require
    # an active user session to enable.
    unit_src=/usr/lib/systemd/system/podman-restart.service
    [ -f "$unit_src" ] || continue
    userdir="$d/.config/systemd/user"
    mkdir -p "$userdir/default.target.wants"
    cp -f "$unit_src" "$userdir/podman-restart.service"
    ln -sf "../podman-restart.service" "$userdir/default.target.wants/podman-restart.service"
    chown -R "$user:" "$userdir"
done
