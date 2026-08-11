#!/bin/bash
set -ouex pipefail

mkdir -p /sysext/usr/lib/extension-release.d

dnf5 -y install --installroot=/sysext --releasever=44 \
    --setopt=install_weak_deps=False \
    --skip-unavailable \
    steam

dnf5 -y --installroot=/sysext clean all

cp /steam-src/extension-release \
  /sysext/usr/lib/extension-release.d/extension-release.steam
