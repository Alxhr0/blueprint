#!/usr/bin/env bash
set -xeuo pipefail

dnf clean all

rm -f /var/log/dnf*.log /var/log/hawkey.log

# Disable any leftover compose repos that shouldn't be active
for repo in $(dnf repolist --enabled 2>/dev/null | awk 'NR>1 {print $1}' | grep -i compose); do
	sed -i "s/^enabled=1/enabled=0/" "/etc/yum.repos.d/${repo}.repo" 2>/dev/null || true
done

# Compile the gsettings schemas and dconf database we just layered in.
glib-compile-schemas /usr/share/glib-2.0/schemas 2>/dev/null || true
dconf update 2>/dev/null || true

bootc container lint
