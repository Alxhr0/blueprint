#!/usr/bin/env bash
set -euo pipefail

for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    if ! groups "$user" | grep -qw docker; then
        usermod -aG docker "$user"
    fi
done
