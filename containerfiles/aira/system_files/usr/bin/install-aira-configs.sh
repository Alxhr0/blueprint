#!/bin/bash
set -euo pipefail

SRC="/usr/share/aira-configs"

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

    if [[ ! -f "${HOME_DIR}/.config/tmux/tmux.conf" ]]; then
        mkdir -p "${HOME_DIR}/.config/tmux"
        cp -avf "${SRC}/.config/tmux/tmux.conf" "${HOME_DIR}/.config/tmux/"
    fi

    if [[ ! -f "${HOME_DIR}/.config/nvim/init.lua" ]]; then
        mkdir -p "${HOME_DIR}/.config/nvim"
        cp -avf "${SRC}/.config/nvim/init.lua" "${HOME_DIR}/.config/nvim/"
        cp -avf "${SRC}/.config/nvim/lua" "${HOME_DIR}/.config/nvim/"
    fi
done
