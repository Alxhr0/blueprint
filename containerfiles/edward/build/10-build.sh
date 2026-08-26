#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Edward Build Script (bluefin-lts-nvidia base, plain dnf)
###############################################################################
# Base image: ghcr.io/projectbluefin/bluefin-lts-nvidia:testing — CentOS Stream
# 10 bootc with GNOME/GDM, NVIDIA driver (matched kernel + kmod pair) and
# ublue batteries (brew/uupd/ujust groundwork). The base ships its own kernel
# with paired nvidia modules, so no separate akmods stage or kernel swap is
# needed. c10s ships dnf4 (no dnf5), so all package operations use plain
# `dnf`, same as upstream bluefin-lts scripts.
#
# This script wires in EPEL + terra (EL flavor), installs the runtime tooling
# that brew/quadlet integration relies on, adds quickshell + niri from COPR,
# and overlays brew/custom files. Desktop payload comes from the base itself.
###############################################################################

# Read build-time settings from /etc/environment if not already in the env
if [[ -z "${IMAGE_NAME:-}" ]] && [[ -f /etc/environment ]]; then
    # shellcheck disable=SC1091
    . /etc/environment
fi

###############################################################################
# RPM Database Integrity
###############################################################################
# The pinned bluefin-lts base ships a BROKEN rpmdb: sqlite's integrity_check
# reports corrupt B-trees in the Basenames and Providename index tables (both
# the :testing and :stable tags are affected, so this is not a bad-digest
# fluke). Plain name lookups still answer, so the damage only surfaces in the
# middle of a transaction:
#
#   error: SELECT hnum, idx FROM 'Basenames' WHERE key=?: 11: database disk image is malformed
#   error: DELETE FROM 'Packages' WHERE hnum=?;: 11: database disk image is malformed
#   Error: transaction check vs depsolve:
#   kernel-uname-r = ... is needed by (installed) kernel-modules-core-...
#   perl-interpreter is needed by kernel-devel-...
#
# Erasures are reported as done but never commit, and the next transaction then
# trips over packages rpm still believes are installed plus requires it can no
# longer resolve (perl-interpreter *is* installed in the base).
#
# `rpm --rebuilddb` cannot run in place here: it rebuilds into a sibling
# directory of %_dbpath and renames that over the original, and renaming a
# directory that comes from a lower overlayfs layer fails inside buildah
# ("failed to replace old database with new database"). Rebuilding inside a
# writable copy and moving only the finished file back avoids the rename.

RPMDB_PATH="$(rpm --eval '%_dbpath')"

# Gate for use after every transaction that matters: a corrupt rpmdb has to
# fail the build here, not silently produce an image whose package database
# disagrees with its own contents.
rpmdb_verify() {
    local stage="$1"
    local log=/tmp/rpmdb-verify.log
    if rpmdb --verifydb >"${log}" 2>&1; then
        echo "rpmdb integrity OK (${stage})"
        return 0
    fi
    echo "ERROR: rpmdb integrity check failed (${stage})" >&2
    head -n 15 "${log}" >&2
    return 1
}

echo "::group:: RPM Database Repair"

if rpmdb --verifydb >/dev/null 2>&1; then
    echo "rpmdb integrity OK, no repair needed"
else
    echo "rpmdb inherited from the base image is corrupt, rebuilding it"
    RPMDB_REPAIR_DIR=/tmp/rpmdb-repair # tmpfs mount: never lands in a layer
    rm -rf "${RPMDB_REPAIR_DIR}"
    mkdir -p "${RPMDB_REPAIR_DIR}"
    cp "${RPMDB_PATH}/rpmdb.sqlite" "${RPMDB_REPAIR_DIR}/"
    rpm --dbpath "${RPMDB_REPAIR_DIR}" --rebuilddb
    rpmdb --dbpath "${RPMDB_REPAIR_DIR}" --verifydb

    # The base also ships -shm/-wal sidecars describing the old file; they are
    # meaningless next to the rebuilt database.
    rm -f "${RPMDB_PATH}/rpmdb.sqlite-shm" "${RPMDB_PATH}/rpmdb.sqlite-wal"
    # --remove-destination unlinks the target first. The shipped db is
    # hardlinked to /usr/lib/sysimage/rpm-ostree-base-db and to an ostree
    # object under /sysroot, which must not be rewritten through the link.
    cp --remove-destination "${RPMDB_REPAIR_DIR}/rpmdb.sqlite" \
        "${RPMDB_PATH}/rpmdb.sqlite"
    chmod 0644 "${RPMDB_PATH}/rpmdb.sqlite"
    rm -rf "${RPMDB_REPAIR_DIR}"

    rpmdb_verify "after rebuild"
fi

echo "::endgroup::"

echo "::group:: Third-party Repos"

# Terra (fyralabs), EL flavor: newer desktop builds not in EPEL/CentOS repos.
# terra-release is a repo-provider metapackage — its repos intentionally stay
# enabled (EL variant of the same pattern as ublue-os/bazzite).
# shellcheck disable=SC2016  # $releasever must reach dnf unexpanded
dnf -y install --nogpgcheck \
    --repofrompath='terra,https://repos.fyralabs.com/terrael$releasever' \
    terra-release

echo "::endgroup::"

echo "::group:: Install Packages"

mkdir -p /var/tmp

# Base tooling. Most entries already ship with bluefin-lts; installing them
# again is idempotent and keeps the brew/quadlet integration explicit.
BASE_PACKAGES=(
    rsync      # required for the brew overlay step
    podman     # required by the container quadlets in system_files
    flatpak    # required for /usr/share/flatpak/preinstall.d at first boot
    tmux       # required by the default ujust recipes
    gum        # required by the default ujust recipes for interactive prompts
    git
    python3-dnf-plugins-core  # provides the `dnf copr` plugin
)

# Skip packages the base image already ships: keeps the transaction small,
# avoids pointless repo churn, and makes real gaps stand out in the log.
MISSING_PACKAGES=()
for pkg in "${BASE_PACKAGES[@]}"; do
    if rpm -q "${pkg}" >/dev/null 2>&1; then
        echo "Already installed, skipping: ${pkg}"
    else
        MISSING_PACKAGES+=("${pkg}")
    fi
done

if [[ ${#MISSING_PACKAGES[@]} -gt 0 ]]; then
    dnf -y install "${MISSING_PACKAGES[@]}"
else
    echo "All base packages already present."
fi

echo "::endgroup::"

echo "::group:: Remove GNOME COPR packages from base image"

# The bluefin-lts base ships GNOME 50 packages from the jreilly1821:c10s-gnome-50
# COPR repo. These conflict with the enterprise-cosmic COPR: the COPR's
# gdk-pixbuf2 obsoletes gdk-pixbuf2-modules which gtk3 requires. Remove the
# COPR repo so dnf cannot pull conflicting updates from it.
GNOME50_REPO=$(find /etc/yum.repos.d/ -name "*jreilly1821*gnome-50*" -print -quit 2>/dev/null || true)
if [[ -n "${GNOME50_REPO}" ]]; then
    rm -f "${GNOME50_REPO}"
    echo "Removed GNOME 50 COPR repo: ${GNOME50_REPO}"
fi

echo "::endgroup::"

echo "::group:: COPR Repositories"

# enterprise-cosmic from ligenix (COSMIC desktop for Enterprise Linux).
# Enable the repo, install, then disable so it does not persist in the
# final image.
dnf -y copr enable ligenix/enterprise-cosmic rhel+epel-10-x86_64
dnf -y install cosmic-desktop
dnf -y install cosmic-ext-name
dnf -y copr disable ligenix/enterprise-cosmic rhel+epel-10-x86_64

echo "::endgroup::"

systemctl disable gdm
systemctl enable greetd

echo "::group:: Overlay Brew Integration Files"

# Brew integration files from @ublue-os/brew OCI (tarball, systemd services,
# shell integration). ujust recipes need no overlay: the bluefin-lts base
# ships the full ublue justfile set, whose 00-entry.just optionally imports
# our 60-custom.just.
rsync -rvK /ctx/oci/brew/ /

echo "::endgroup::"

echo "::group:: Copy Custom Files"

shopt -s nullglob

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
mkdir -p /usr/share/ublue-os/just/
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >>/usr/share/ublue-os/just/60-custom.just

# Copy Flatpak preinstall files
mkdir -p /usr/share/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /usr/share/flatpak/preinstall.d/

# Copy system files (quadlets, launchers, desktop entries)
cp -rf /ctx/system_files/. /

shopt -u nullglob

echo "::endgroup::"

echo "::group:: System Configuration"

systemctl enable podman.socket                # quadlet/container support
systemctl enable brew-setup.service           # extract Homebrew tarball once
systemctl enable brew-update.timer            # brew metadata refresh
systemctl enable brew-upgrade.timer           # brew package upgrades
systemctl enable NetworkManager.service       # networking; idempotent when the base already presets it

# Display manager and desktop session come straight from the bluefin-lts base
# (GDM + GNOME); audio comes up via the base's PipeWire units. Nothing to add.

echo "::endgroup::"

echo "edward build complete!"
