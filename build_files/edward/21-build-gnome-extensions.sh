#!/usr/bin/bash

set -eoux pipefail

echo "::group:: $(basename "$0")"

# GNOME Shell extensions are managed upstream or via Brewfiles/flatpak.
# No per-image extension builds needed.

echo "::endgroup::"
