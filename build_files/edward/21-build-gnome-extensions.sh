#!/usr/bin/bash

set -eoux pipefail

echo "::group:: ===$(basename "$0")==="

dnf -y install glib2-devel

EXTENSIONS_DIR="/usr/share/gnome-shell/extensions"

# AppIndicator Support
APPINDICATOR_URL="https://extensions.gnome.org/extension-data/appindicatorsupportrgcjonas.gmail.com.v64.shell-extension.zip"
curl -fsSL "$APPINDICATOR_URL" -o /tmp/appindicator.zip
unzip -o /tmp/appindicator.zip -d "$EXTENSIONS_DIR/appindicatorsupport@rgcjonas.gmail.com"
rm /tmp/appindicator.zip

# Blur My Shell
BMS_URL="https://extensions.gnome.org/extension-data/blur-my-shellaunetx.v72.shell-extension.zip"
curl -fsSL "$BMS_URL" -o /tmp/blur-my-shell.zip
unzip -o /tmp/blur-my-shell.zip -d "$EXTENSIONS_DIR/blur-my-shell@aunetx"
rm /tmp/blur-my-shell.zip

# Bazaar Companion (installed by RPM, schemas compiled below)

# Caffeine
CAFFEINE_URL="https://extensions.gnome.org/extension-data/caffeinepatapon.info.v60.shell-extension.zip"
curl -fsSL "$CAFFEINE_URL" -o /tmp/caffeine.zip
unzip -o /tmp/caffeine.zip -d "$EXTENSIONS_DIR/caffeine@patapon.info"
rm /tmp/caffeine.zip

# Custom Command Menu
CCM_URL="https://extensions.gnome.org/extension-data/custom-command-liststorageb.github.com.v15.shell-extension.zip"
curl -fsSL "$CCM_URL" -o /tmp/custom-command-menu.zip
unzip -o /tmp/custom-command-menu.zip -d "$EXTENSIONS_DIR/custom-command-list@storageb.github.com"
rm /tmp/custom-command-menu.zip

# Dash to Dock
DTD_URL="https://extensions.gnome.org/extension-data/dash-to-dockmicxgx.gmail.com.v105.shell-extension.zip"
curl -fsSL "$DTD_URL" -o /tmp/dash-to-dock.zip
unzip -o /tmp/dash-to-dock.zip -d "$EXTENSIONS_DIR/dash-to-dock@micxgx.gmail.com"
rm /tmp/dash-to-dock.zip

# GSConnect
GSCONNECT_URL="https://extensions.gnome.org/extension-data/gsconnectandyholmes.github.io.v72.shell-extension.zip"
curl -fsSL "$GSCONNECT_URL" -o /tmp/gsconnect.zip
unzip -o /tmp/gsconnect.zip -d "$EXTENSIONS_DIR/gsconnect@andyholmes.github.io"
rm /tmp/gsconnect.zip

# Gradia Capture (not on extensions.gnome.org yet, build from source)
dnf -y install meson sassc cmake dbus-devel
GRADIA_DIR="$EXTENSIONS_DIR/gradia-integration@alexandervanhee.github.io"
bash "$GRADIA_DIR/build.sh"
unzip -o "$GRADIA_DIR/gradia-integration@alexandervanhee.github.io.shell-extension.zip" -d "$GRADIA_DIR"
rm -f "$GRADIA_DIR/gradia-integration@alexandervanhee.github.io.shell-extension.zip"
dnf -y remove meson sassc cmake dbus-devel

# Search Light (v37 for GNOME 47; v42+ requires GNOME 48+)
SEARCHLIGHT_URL="https://extensions.gnome.org/extension-data/search-lighticedman.github.com.v37.shell-extension.zip"
curl -fsSL "$SEARCHLIGHT_URL" -o /tmp/search-light.zip
unzip -o /tmp/search-light.zip -d "$EXTENSIONS_DIR/search-light@icedman.github.com"
rm /tmp/search-light.zip

rm -f /usr/share/glib-2.0/schemas/gschemas.compiled
glib-compile-schemas /usr/share/glib-2.0/schemas

dnf -y remove glib2-devel
rm -rf "$EXTENSIONS_DIR/tmp"

echo "::endgroup::"
