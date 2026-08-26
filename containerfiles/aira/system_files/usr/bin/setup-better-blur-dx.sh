#!/bin/bash
set -euo pipefail

install_root="${1:-/}"

CONFIG_FILE="${install_root}/etc/skel/.config/kwinrc"
PLUGINS_DIR="${install_root}/usr/share/kwin/effects"

mkdir -p "$(dirname "${CONFIG_FILE}")"

if [[ ! -d "${PLUGINS_DIR}" ]]; then
    echo "KWin effects directory not found, skipping Better Blur DX setup"
    exit 0
fi

DESKTOP_FILE=$(find "${PLUGINS_DIR}" -maxdepth 1 -name "*.desktop" -exec grep -l "Better Blur DX" {} \; | head -n 1)

if [[ -z "${DESKTOP_FILE}" ]]; then
    echo "Better Blur DX desktop file not found, skipping setup"
    exit 0
fi

PLUGIN_NAME=$(basename "${DESKTOP_FILE}" .desktop)
ENABLED_KEY="${PLUGIN_NAME}Enabled"

cat > "${CONFIG_FILE}" <<EOF
[Plugins]
blurEnabled=false
${ENABLED_KEY}=true
EOF

echo "Enabled ${PLUGIN_NAME} in ${CONFIG_FILE}"
