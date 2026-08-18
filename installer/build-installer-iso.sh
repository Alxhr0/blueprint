#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Blueprint Server Installer — ISO Build Script
# Creates a bootable live ISO with the ncurses installer.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(realpath "${SCRIPT_DIR}/..")"
KICKSTART="${SCRIPT_DIR}/blueprint-installer.ks"
OUTPUT_DIR="${REPO_DIR}/output/installer-iso"
IMAGE_REF="${BLUEPRINT_IMAGE_REF:-ghcr.io/huntedraven7/blueprint:server}"

TITLE="Blueprint Installer ISO Builder"

log()  { echo "[blueprint] $*"; }
die()  { echo "[blueprint] ERROR: $*" >&2; exit 1; }

# ── Prerequisites ───────────────────────────────────────────────────────────
check_prereqs() {
    local missing=()

    if [[ "${EUID}" -ne 0 ]]; then
        die "This script must be run as root (livemedia-creator needs root)."
    fi

    for cmd in lorax livemedia-creator xorriso; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log "Installing missing prerequisites: ${missing[*]}"
        if command -v dnf5 &>/dev/null; then
            dnf5 install -y lorax lorax-lmc-novirt xorriso
        elif command -v dnf &>/dev/null; then
            dnf install -y lorax lorax-lmc-novirt xorriso
        elif command -v apt-get &>/dev/null; then
            apt-get update && apt-get install -y lorax xorriso
        else
            die "Cannot auto-install prerequisites. Install manually: ${missing[*]}"
        fi
    fi
}

# ── Build ────────────────────────────────────────────────────────────────────
build_iso() {
    log "Building Blueprint Server Installer ISO..."
    log "Kickstart: ${KICKSTART}"
    log "Output:    ${OUTPUT_DIR}"
    log "Image ref: ${IMAGE_REF}"

    mkdir -p "${OUTPUT_DIR}"

    # livemedia-creator builds a live ISO from a kickstart file.
    # --no-virt:    run in the current environment (not a VM)
    # --make-iso:   produce an ISO image
    # --ks:         the kickstart file defining the live image
    # --resultdir:  where to write the output
    # --project:    label for the ISO
    # --releasever: Fedora version to base the image on
    livemedia-creator \
        --no-virt \
        --make-iso \
        --ks "${KICKSTART}" \
        --resultdir "${OUTPUT_DIR}" \
        --project "Blueprint Server Installer" \
        --releasever 10 \
        --macboot \
        2>&1 | tee "${OUTPUT_DIR}/build.log" || {
            die "livemedia-creator failed. Check ${OUTPUT_DIR}/build.log for details."
        }

    # Find and rename the ISO
    local iso
    iso=$(find "${OUTPUT_DIR}" -name "*.iso" -type f | head -1)

    if [[ -z "$iso" ]]; then
        die "No ISO file found in ${OUTPUT_DIR}. Build may have failed."
    fi

    local final_name="blueprint-server-installer-$(date +%Y%m%d).iso"
    mv "$iso" "${OUTPUT_DIR}/${final_name}"

    log ""
    log "ISO built successfully!"
    log "Output: ${OUTPUT_DIR}/${final_name}"
    log ""
    log "To test in a VM:"
    log "  just run-installer-iso"
    log ""
    log "To write to a USB drive:"
    log "  sudo dd if=${OUTPUT_DIR}/${final_name} of=/dev/sdX bs=4M status=progress"
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    if [[ ! -f "$KICKSTART" ]]; then
        die "Kickstart file not found: ${KICKSTART}"
    fi

    check_prereqs
    build_iso
}

main "$@"
