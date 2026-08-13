#!/bin/bash
set -ouex pipefail

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain stable --profile minimal
export PATH=/root/.cargo/bin:${PATH}

git clone "https://github.com/bootc-dev/bootc.git" /tmp/bootc
make -C /tmp/bootc bin install-all DESTDIR=/output
rm -rf /tmp/bootc
