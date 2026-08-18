#!/usr/bin/env bash
set -xeuo pipefail

dnf clean all

rm -f /var/log/dnf*.log /var/log/hawkey.log

# Disable any leftover CentOS/compose repos that shouldn't be active
for repo in $(dnf repolist --enabled 2>/dev/null | awk 'NR>1 {print $1}' | grep -i compose); do
	dnf config-manager --set-disabled "$repo" 2>/dev/null || true
done

bootc container lint
