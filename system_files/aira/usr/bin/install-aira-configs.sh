#!/bin/bash
set -euo pipefail

SRC="/usr/share/aira-configs"
DST="/var/roothome"

mkdir -p "${DST}/.config"

if [[ ! -f "${DST}/.config/tmux/tmux.conf" ]]; then
    mkdir -p "${DST}/.config/tmux"
    cp -avf "${SRC}/.config/tmux/tmux.conf" "${DST}/.config/tmux/"
fi

if [[ ! -f "${DST}/.config/nvim/init.lua" ]]; then
    mkdir -p "${DST}/.config/nvim"
    cp -avf "${SRC}/.config/nvim/init.lua" "${DST}/.config/nvim/"
    cp -avf "${SRC}/.config/nvim/lua" "${DST}/.config/nvim/"
fi
