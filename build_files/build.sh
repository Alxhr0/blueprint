#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files"/. /

mkdir -p /var/roothome

if [ -L /root ]; then
  target=$(readlink -f /root)
  mkdir -p "$target"
else
  mkdir -p /root
fi

curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install linux \
    --init none \
    --no-confirm \
    --no-modify-profile \
    --prefer-upstream-nix

mkdir -p /nix

dnf5 -y install fedora-workstation-repositories
dnf5 -y copr enable scottames/ghostty
dnf5 -y config-manager setopt google-chrome.enabled=1

PACKAGES=(
    google-chrome-stable
    steam
    ghostty
  )

dnf5 -y install "${PACKAGES[@]}"

dnf5 -y copr disable scottames/ghostty

mkdir -p /usr/etc/flatpak/system

cat <<EOF >> /usr/etc/flatpak/system/install
io.github.tanaybhomia.Whisp
com.discordapp.Discord
com.heroicgameslauncher.hgl
md.obsidian.Obsidian
it.mijorus.gearlever
com.vysp3r.ProtonPlus
org.kde.krita
org.inkscape.Inkscape
com.github.johnfactotum.Foliate
org.gnome.gitlab.ilhooq.Bookup
com.super_productivity.SuperProductivity
com.ticktick.TickTick
org.prismlauncher.PrismLauncher
com.protonvpn.www
dev.vencord.Vesktop
us.zoom.Zoom
io.github.Faugus.faugus-launcher
io.podman_desktop.PodmanDesktop
com.jeffser.Alpaca
net.cozic.joplin_desktop
com.logseq.Logseq
io.github.alainm23.planify
com.vixalien.sticky
org.zotero.Zotero
com.adamcake.Bolt
io.gitlab.news_flash.NewsFlash
moe.launcher.the-honkers-railway-launcher
moe.launcher.sleepy-launcher
moe.launcher.an-anime-game-launcher
info.febvre.Komikku
com.rafaelmardojai.Blanket
io.github.dvlv.boxbuddyrs
page.kramo.Cartridges
io.github.qwersyk.Newelle
net.runelite.RuneLite
io.github.faridjaff.StickyNotesCanvas
org.localsend.localsend_app
net.lutris.Lutris
EOF

cat <<EOF >> /usr/etc/flatpak/system/remove
org.mozilla.firefox
EOF

systemctl enable podman.socket
systemctl enable tailscaled.service

if command -v chcon > /dev/null; then
    chcon -R -t unconfined_mgmt_t /nix || true
fi
