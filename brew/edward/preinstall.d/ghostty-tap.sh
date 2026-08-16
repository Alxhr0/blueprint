#!/bin/bash

set -euo pipefail

# Tap the local ghostty tap so brew can find the formula
if [ -d /usr/share/ublue-os/homebrew/ghostty-tap ]; then
    brew tap /usr/share/ublue-os/homebrew/ghostty-tap
fi
