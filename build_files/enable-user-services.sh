#!/bin/bash
# enable-user-services.sh — enable user-level systemd services universally.

enable_user_service() {
    local service="$1"
    if command -v systemctl >/dev/null 2>&1; then
        mkdir -p /etc/systemd/user/graphical-session.target.wants
        ln -sfn "/usr/lib/systemd/user/${service}" \
            "/etc/systemd/user/graphical-session.target.wants/${service}"
    fi
}
