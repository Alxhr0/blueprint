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
		edward)
			cp -avf "${CONTEXT_PATH}/system_files/edward/." /
			;;
		common-nvidia)
			cp -avf "${CONTEXT_PATH}/system_files/nvidia/." / 2>/dev/null || true
			;;
		*)
			cp -avf "${CONTEXT_PATH}/system_files/edward/overrides/${what}/." / 2>/dev/null || true
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
	ln -sfn edward/packages.Brewfile /usr/share/ublue-os/homebrew/Brewfile
	cat > /etc/ublue-os/brew-bundle.conf <<EOF
BREWFILE_URL=https://raw.githubusercontent.com/${IMAGE_VENDOR}/${IMAGE_NAME}/${brewfile_ref}/brew/edward/packages.Brewfile
BREWFILE_DEST=/usr/share/ublue-os/homebrew/Brewfile
EOF
}

mkdir -p /var/roothome

copy_systemfiles_for shared
install_brew_bundle_config
copy_systemfiles_for edward

run_buildscripts_for layer
run_buildscripts_for edward

if [ "${ENABLE_NVIDIA:-0}" == "1" ]; then
	copy_systemfiles_for common-nvidia
	copy_systemfiles_for nvidia
	run_buildscripts_for nvidia
fi

printf '::group:: Image Cleanup\n'
"${BUILD_SCRIPTS_PATH}/cleanup.sh"
printf '::endgroup::\n'
