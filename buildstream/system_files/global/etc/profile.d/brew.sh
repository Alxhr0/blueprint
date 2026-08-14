#!/usr/bin/env bash

# Add Homebrew to PATH for all login shells (interactive AND non-interactive).
#
# Overrides the upstream uBlue brew.sh which gates on `$- == *i*` (interactive
# only). That check means non-interactive login shells — e.g. `bash -l -c`,
# Ansible, or some CI contexts — never get brew on PATH, so `fastfetch` and
# other `brew install`ed tools are "command not found" until a fresh
# interactive login.
#
# Homebrew bin/sbin are appended (low priority) so system binaries stay
# first in PATH — prevents brew from shadowing things like dbus.
# See: https://github.com/ublue-os/brew/blob/main/system_files/usr/lib/systemd/system/brew-upgrade.service#L17-L22
if [[ -z "${HOMEBREW_PREFIX:-}" && -d /home/linuxbrew/.linuxbrew && ! "$PATH" == *"/home/linuxbrew/.linuxbrew/bin"* ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv | grep -Ev '\bPATH=')"
  HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
  export PATH="${PATH}:${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin"
fi
