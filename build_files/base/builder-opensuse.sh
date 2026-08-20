#!/bin/bash
set -ouex pipefail

# Toolchain bootstrap (moved from Containerfile.opensuse into this self-contained
# builder script so the unified root Containerfile can drive every variant).
zypper install -y binutils cargo git go-md2man libostree-devel make rust

git clone "https://github.com/bootc-dev/bootc.git" /tmp/bootc
make -C /tmp/bootc bin install-all DESTDIR=/output
rm -rf /tmp/bootc
