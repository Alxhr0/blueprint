#!/usr/bin/env bash
set -eo pipefail

CONTEXT_PATH="$(realpath "$(dirname "$0")/..")"
BUILD_SCRIPTS_PATH="$(realpath "$(dirname "$0")")"
CORE_PATH="$(realpath "$(dirname "$0")/../core")"
MAJOR_VERSION_NUMBER="$(sh -c '. /usr/lib/os-release ; echo ${VERSION_ID%.*}')"
export MAJOR_VERSION_NUMBER

mkdir -p /var/roothome

# 1. Layer Edward's personal overlays (containers, container-launch, dconf,
#    skel, hooks). GNOME, the kernel, akmods and NVIDIA all come from the
#    bluefin-lts-nvidia base image — we only add our own differences.
printf '::group:: edward-overlays\n'
cp -avf "${CONTEXT_PATH}/system_files/edward/." /
printf '::endgroup::\n'

# 2. Enable the Terra repository (extra EL packages) and install what we want from it.
"${BUILD_SCRIPTS_PATH}/21-terra.sh"
# ghostty terminal + subpackages (packaged by Terra for EL — https://terrapkg.com).
# --repovalidation=none: Terra's mirror sometimes serves repodata with mismatched
# checksums; skip validation so the build isn't blocked by their infrastructure.
if ! dnf install -y --repovalidation=none ghostty ghostty-terminfo ghostty-shell-integration; then
    echo "build: ghostty install failed even with repovalidation=none, skipping"
fi

# 3. Install Nix in daemon mode for bootc (bind-mounts /nix -> /var/nix).
printf '::group:: nix-bootc-setup\n'
source "${CORE_PATH}/nix-bootc-setup.sh"
printf '::endgroup::\n'

# 4. Wire up the Homebrew bundle so it auto-installs on first boot.
install_brew_bundle_config() {
  local brewfile_ref="${BREWFILE_REF:-main}"
  if [[ "${brewfile_ref}" == "main" && -n "${SHA_HEAD_SHORT:-}" && "${SHA_HEAD_SHORT}" != "deadbeef" ]]; then
    brewfile_ref="${SHA_HEAD_SHORT}"
  fi
  mkdir -p /usr/share/ublue-os/homebrew /etc/ublue-os
  cp -avf "${CONTEXT_PATH}/brew/." /usr/share/ublue-os/homebrew/
  ln -sfn edward/packages.Brewfile /usr/share/ublue-os/homebrew/Brewfile
  cat > /etc/ublue-os/brew-bundle.conf <<EOF
BREWFILE_URL=https://raw.githubusercontent.com/${IMAGE_VENDOR}/${IMAGE_NAME}/${brewfile_ref}/brew/edward/packages.Brewfile
BREWFILE_DEST=/usr/share/ublue-os/homebrew/Brewfile
EOF
}
install_brew_bundle_config

# 5. Edward-specific build scripts (user services, service enablement).
"${BUILD_SCRIPTS_PATH}/overrides/edward/10-edward.sh"
"${BUILD_SCRIPTS_PATH}/overrides/layer/40-services.sh"

# 6. Cleanup + bootc lint.
"${BUILD_SCRIPTS_PATH}/cleanup.sh"
