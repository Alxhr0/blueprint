#!/bin/bash
set -euo pipefail

FLAG="/var/lib/kwin-effects-configured"

if [[ -f "${FLAG}" ]]; then
    exit 0
fi

SKEL_KWINRC="/etc/skel/.config/kwinrc"

if [[ ! -f "${SKEL_KWINRC}" ]]; then
    echo "Default kwinrc not found in skel, skipping"
    exit 0
fi

HOMES=()
if [[ -d /var/roothome ]]; then
    HOMES+=("/var/roothome")
fi
if [[ -d /var/home ]]; then
    while IFS= read -r home; do
        HOMES+=("${home}")
    done < <(find /var/home -maxdepth 1 -mindepth 1 -type d | sort)
fi

for HOME_DIR in "${HOMES[@]}"; do
    mkdir -p "${HOME_DIR}/.config"
    if [[ ! -f "${HOME_DIR}/.config/kwinrc" ]]; then
        cp -avf "${SKEL_KWINRC}" "${HOME_DIR}/.config/kwinrc"
    fi
done

touch "${FLAG}"
