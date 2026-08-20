#!/bin/bash
set -ouex pipefail

# NixOS toolchain bootstrap (moved from Containerfile.nixos into this
# self-contained builder script so the unified root Containerfile can drive
# every variant). Runs the actual nixos build, which populates /output.
nix-channel --update
nix-channel --add https://nixos.org/channels/nixos-26.05 nixos
nix-channel --add https://nixos.org/channels/nixos-26.05 nixpkgs
nix-channel --update

export NIX_PATH=nixpkgs=/root/.nix-defexpr/channels/nixpkgs:/nix/var/nix/profiles/per-user/root/channels

nix-env -iA nixpkgs.bootc nixpkgs.ostree nixpkgs.nixos-rebuild

/ctx/nixos/build.sh
