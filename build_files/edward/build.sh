#!/usr/bin/env bash
set -eo pipefail

CONTEXT_PATH="$(realpath "$(dirname "$0")/..")"
BUILD_SCRIPTS_PATH="$(realpath "$(dirname "$0")")"
MAJOR_VERSION_NUMBER="$(sh -c '. /usr/lib/os-release ; echo ${VERSION_ID%.*}')"
SCRIPTS_PATH="$(realpath "$(dirname "$0")/scripts")"
export SCRIPTS_PATH
export PATH="${SCRIPTS_PATH}:${PATH}"
export MAJOR_VERSION_NUMBER

run_buildscripts_for() {
	WHAT=$1
	shift
	if [ ! -d "${BUILD_SCRIPTS_PATH}/overrides/${WHAT}" ]; then
		return 0
	fi
	find "${BUILD_SCRIPTS_PATH}/overrides/$WHAT" -maxdepth 1 -iname "*-*.sh" -type f -print0 | sort --zero-terminated --sort=human-numeric | while IFS= read -r -d $'\0' script ; do
		if [ "${CUSTOM_NAME}" != "" ] ; then
			WHAT=$CUSTOM_NAME
		fi
		printf "::group:: ===$WHAT-%s===\n" "$(basename "$script")"
		"$(realpath "$script")"
		printf "::endgroup::\n"
	done
}

copy_systemfiles_for() {
	WHAT=$1
	shift
	DISPLAY_NAME=$WHAT
	if [ "${CUSTOM_NAME}" != "" ] ; then
		DISPLAY_NAME=$CUSTOM_NAME
	fi
	printf "::group:: ===%s-file-copying===\n" "${DISPLAY_NAME}"
	case "$WHAT" in
		../files)
			cp -avf "${CONTEXT_PATH}/system_files/edward/." /
			;;
		*)
			cp -avf "${CONTEXT_PATH}/system_files/edward/overrides/${WHAT}/." / 2>/dev/null || true
			;;
	esac
	printf "::endgroup::\n"
}

mkdir -p /var/roothome

run_buildscripts_for base

copy_systemfiles_for shared
run_buildscripts_for shared

# Install Edward's Brewfiles
mkdir -p /usr/share/ublue-os/homebrew
cp -avf "${CONTEXT_PATH}/brew/." /usr/share/ublue-os/homebrew/

CUSTOM_NAME="edward"
copy_systemfiles_for ../files
run_buildscripts_for ..
CUSTOM_NAME=""

copy_systemfiles_for "$(arch)"
run_buildscripts_for "$(arch)"

if [ "$ENABLE_DX" == "1" ]; then
	copy_systemfiles_for dx
	run_buildscripts_for dx
	copy_systemfiles_for "$(arch)-dx"
	run_buildscripts_for "$(arch)/dx"
fi

if [ "$ENABLE_NVIDIA" == "1" ]; then
	copy_systemfiles_for nvidia
	run_buildscripts_for nvidia
	copy_systemfiles_for "$(arch)-nvidia"
	run_buildscripts_for "$(arch)/nvidia"
fi

printf "::group:: ===Image Cleanup===\n"
"${BUILD_SCRIPTS_PATH}/cleanup.sh"
printf "::endgroup::\n"
