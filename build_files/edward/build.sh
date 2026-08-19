#!/usr/bin/env bash
set -eo pipefail

CONTEXT_PATH="$(realpath "$(dirname "$0")/..")"
BUILD_SCRIPTS_PATH="$(realpath "$(dirname "$0")")"
MAJOR_VERSION_NUMBER="$(sh -c '. /usr/lib/os-release ; echo ${VERSION_ID%.*}')"
export MAJOR_VERSION_NUMBER

mkdir -p /var/roothome

# 1. Layer Edward's personal overlays (containers, container-launch, dconf,
#    skel, hooks). GNOME, the kernel, akmods and NVIDIA all come from the
#    bluefin-lts-nvidia base image — we only add our own differences.
printf '::group:: edward-overlays\n'
cp -avf "${CONTEXT_PATH}/system_files/edward/." /
printf '::endgroup::\n'

# 2. Enable the first-boot Nix setup service (installs Nix at boot via
#    /usr/share/edward/scripts/setup-nix.sh, then disables itself).
printf '::group:: nix-setup-service\n'
systemctl enable setup-nix.service
printf '::endgroup::\n'

# 3. Wire up the Homebrew bundle so it auto-installs on first boot.
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

# 4. Edward-specific build scripts (user services, service enablement).
"${BUILD_SCRIPTS_PATH}/overrides/edward/10-edward.sh"
"${BUILD_SCRIPTS_PATH}/overrides/layer/40-services.sh"

# 5. Cleanup + bootc lint.
"${BUILD_SCRIPTS_PATH}/cleanup.sh"
