#!/usr/bin/env bash
set -xeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTEXT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Building akmods image using AlmaLinux bootc base..."

podman build \
    --tag "blueprint:akmods-edward" \
    --file "containerfiles/Containerfile.akmods-edward" \
    "${CONTEXT_DIR}"

echo "Akmods image built: blueprint:akmods-edward"
