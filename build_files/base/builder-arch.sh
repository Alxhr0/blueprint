#!/bin/bash
set -ouex pipefail

# Toolchain bootstrap (moved from Containerfile.arch into this self-contained
# builder script so the unified root Containerfile can drive every variant).
pacman -Syu --noconfirm \
    base-devel \
    git \
    rust \
    cargo \
    go-md2man \
    ostree \
    glibc \
    pkgconf \
    python-setuptools

git clone "https://github.com/bootc-dev/bootc.git" /tmp/bootc
make -C /tmp/bootc bin install-all DESTDIR=/output
rm -rf /tmp/bootc
