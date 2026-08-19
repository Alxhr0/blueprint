#!/usr/bin/env bash
set -xeuo pipefail

MAJOR_VERSION_NUMBER="$(sh -c '. /usr/lib/os-release ; echo ${VERSION_ID%.*}')"

# Main application/tooling packages (EL10 / Alma + EPEL).
dnf -y install \
  flatpak \
  distrobox \
  fastfetch \
  firewalld \
  gum \
  just \
  wl-clipboard \
  xhost \
  xdg-terminal-exec \
  wireguard-tools \
  ntfs-3g \
  btrfs-progs \
  buildah \
  containerd \
  pcsc-lite \
  tuned-ppd \
  nss-mdns \
  gnome-disk-utility \
  fpaste

# Multimedia codecs (negativo17 epel-multimedia).
dnf config-manager --add-repo=https://negativo17.org/repos/epel-multimedia.repo
dnf config-manager --set-disabled epel-multimedia
dnf -y --enablerepo=epel-multimedia install \
  ffmpeg libavcodec gstreamer1-plugins-{bad-free,bad-free-libs,good,base} lame{,-libs} libjxl ffmpegthumbnailer || true

# Tailscale (EL repo).
dnf config-manager --add-repo "https://pkgs.tailscale.com/stable/el/${MAJOR_VERSION_NUMBER}/tailscale.repo"
dnf config-manager --set-disabled "tailscale-stable"
dnf -y --enablerepo "tailscale-stable" install tailscale || true

# uupd (pinned in image-versions.yaml, tracked by Renovate).
UUPD_VERSION=$(grep '^\s*uupd:' /run/context/image-versions.yaml | sed 's/.*"\(.*\)".*/\1/' || true)
if [[ -n "${UUPD_VERSION}" ]]; then
  curl -fsSL "https://github.com/ublue-os/uupd/releases/download/${UUPD_VERSION}/uupd_Linux_x86_64.tar.gz" \
    | tar -xzf - -C /usr/bin uupd
  chmod 0755 /usr/bin/uupd
  UUPD_RAW="https://raw.githubusercontent.com/ublue-os/uupd/${UUPD_VERSION}"
  curl -fsSL "${UUPD_RAW}/uupd.service" -o /usr/lib/systemd/system/uupd.service
  curl -fsSL "${UUPD_RAW}/uupd.timer"   -o /usr/lib/systemd/system/uupd.timer
fi

# A GCC toolchain is required so Homebrew works indefinitely without breaking
# when a new GCC lands in the base repos.
dnf -y --setopt=install_weak_deps=False install gcc

# Offline Bluefin documentation (best-effort).
curl --retry 3 -fsSL -o /tmp/bluefin.pdf https://github.com/projectbluefin/documentation/releases/download/0.1/bluefin.pdf \
  && install -Dm0644 -t /usr/share/doc/bluefin/ /tmp/bluefin.pdf || true

# Add linuxbrew to the sudo secure_path so privileged brew works.
sed -Ei "s/secure_path = (.*)/secure_path = \1:\/home\/linuxbrew\/.linuxbrew\/bin/" /etc/sudoers || true
