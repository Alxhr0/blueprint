#!/usr/bin/env bash
set -eo pipefail

CONTEXT_PATH="$(realpath "$(dirname "$0")/..")"
BUILD_SCRIPTS_PATH="$(realpath "$(dirname "$0")")"

run_buildscripts_for() {
	local what=$1
	if [ ! -d "${BUILD_SCRIPTS_PATH}/overrides/${what}" ]; then
		return 0
	fi
	find "${BUILD_SCRIPTS_PATH}/overrides/${what}" -maxdepth 1 -iname '*-*.sh' -type f -print0 \
		| sort --zero-terminated --sort=human-numeric \
		| while IFS= read -r -d $'\0' script; do
			printf '::group:: %s\n' "$(basename "${script}")"
			"$(realpath "${script}")"
			printf '::endgroup::\n'
		done
}

copy_systemfiles_for() {
	local what=$1
	printf '::group:: %s-file-copying\n' "${what}"
	case "${what}" in
		almafin)
			cp -avf "${CONTEXT_PATH}/system_files/almafin/." /
			;;
		*)
			cp -avf "${CONTEXT_PATH}/system_files/almafin/overrides/${what}/." / 2>/dev/null || true
			;;
	esac
	printf '::endgroup::\n'
}

install_brew_bundle_config() {
	local brewfile_ref="${BREWFILE_REF:-main}"
	if [[ "${brewfile_ref}" == "main" && -n "${SHA_HEAD_SHORT:-}" && "${SHA_HEAD_SHORT}" != "deadbeef" ]]; then
		brewfile_ref="${SHA_HEAD_SHORT}"
	fi
	mkdir -p /usr/share/ublue-os/homebrew /etc/ublue-os
	cp -avf "${CONTEXT_PATH}/brew/." /usr/share/ublue-os/homebrew/
	ln -sfn almafin/packages.Brewfile /usr/share/ublue-os/homebrew/Brewfile
	cat > /etc/ublue-os/brew-bundle.conf <<EOF
BREWFILE_URL=https://raw.githubusercontent.com/${IMAGE_VENDOR}/${IMAGE_NAME}/${brewfile_ref}/brew/almafin/packages.Brewfile
BREWFILE_DEST=/usr/share/ublue-os/homebrew/Brewfile
EOF
}

mkdir -p /var/roothome

# 1. Install the Alma desktop + supporting packages (no desktop in the base image)
"${BUILD_SCRIPTS_PATH}/30-desktop.sh"
"${BUILD_SCRIPTS_PATH}/31-packages.sh"

# 2. Layer the common desktop theming + shared system files (pulled from the
#    published common image) and the Homebrew service (from ublue-os/brew).
printf '::group:: common-shared\n'
cp -avf "${CONTEXT_PATH}/common_shared/." /
printf '::endgroup::\n'
printf '::group:: common-bluefin\n'
cp -avf "${CONTEXT_PATH}/bluefin_files/." /
printf '::endgroup::\n'
printf '::group:: brew-files\n'
cp -avf "${CONTEXT_PATH}/brew_files/." /
printf '::endgroup::\n'

# 3. Wire up the user's Homebrew bundle so it auto-installs on first boot
install_brew_bundle_config

# 4. AlmaFin-specific system files (vendored common shared + AlmaFin additions)
copy_systemfiles_for shared
copy_systemfiles_for almafin

# 5. Flavor override scripts
run_buildscripts_for layer
run_buildscripts_for almafin

# 5b. NVIDIA (akmods) — mirrors bluefin-lts exactly (driver + kmods + toolkit).
if [ "$ENABLE_NVIDIA" == "1" ]; then
	copy_systemfiles_for nvidia
	run_buildscripts_for nvidia
	copy_systemfiles_for "$(arch)-nvidia"
	run_buildscripts_for "$(arch)/nvidia"
fi

# 6. Service enablement, AlmaFin/LTS extras, image metadata
"${BUILD_SCRIPTS_PATH}/40-services.sh"
"${BUILD_SCRIPTS_PATH}/90-image-info.sh"

# 7. Cleanup
printf '::group:: Image Cleanup\n'
"${BUILD_SCRIPTS_PATH}/cleanup.sh"
printf '::endgroup::\n'
