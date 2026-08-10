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

pushd /usr/lib/kernel/install.d
mv 05-rpmostree.install 05-rpmostree.install.bak
mv 50-dracut.install 50-dracut.install.bak
printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install
printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install
chmod +x 05-rpmostree.install 50-dracut.install
popd

for pkg in kernel kernel{-core,-modules,-modules-core,-modules-extra,-tools-libs,-tools}; do
    rpm --erase "${pkg}" --nodeps 2>/dev/null || true
done

rm -rf /usr/lib/modules

dnf5 -y install \
    /tmp/kernel-rpms/kernel-[0-9]*.rpm \
    /tmp/kernel-rpms/kernel-core-*.rpm \
    /tmp/kernel-rpms/kernel-modules-*.rpm \
    /tmp/kernel-rpms/kernel-devel-*.rpm

dnf5 versionlock add kernel kernel-devel kernel-devel-matched kernel-core kernel-modules

pushd /usr/lib/kernel/install.d
mv -f 05-rpmostree.install.bak 05-rpmostree.install
mv -f 50-dracut.install.bak 50-dracut.install
popd

if rpm -q kmod-nvidia > /dev/null 2>&1; then
    rpm --erase kmod-nvidia --nodeps
fi
AKMODNV_PATH=/tmp/akmods-nvidia /tmp/akmods-nvidia/ublue-os/nvidia-install.sh

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

KERNEL_VERSION="$(rpm -q --queryformat="%{evr}.%{arch}" kernel-core)"
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible -v --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"

if command -v chcon > /dev/null; then
    chcon -R -t unconfined_mgmt_t /nix || true
fi
