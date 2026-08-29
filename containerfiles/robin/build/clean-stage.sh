#!/usr/bin/env bash

echo "::group:: ===$(basename "$0")==="

set -eoux pipefail

CLEAN_ROOT="${CLEAN_ROOT:-/}"

pacman -Scc --noconfirm

rm -f "${CLEAN_ROOT}/.gitkeep"

for runtime_dir in tmp boot run; do
	mkdir -p "${CLEAN_ROOT:?}/${runtime_dir}"
	find "${CLEAN_ROOT:?}/${runtime_dir}" -mindepth 1 -maxdepth 1 -print0 |
		while IFS= read -r -d '' entry; do
			if mountpoint -q "${entry}" 2>/dev/null; then
				continue
			fi
			rm -rf "${entry}"
		done
done

mkdir -p "${CLEAN_ROOT:?}/var"
find "${CLEAN_ROOT:?}/var" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true

echo "::endgroup::"
