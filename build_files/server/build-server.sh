#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/server"/. /

mkdir -p /var/roothome

dnf5 -y install \
    openssh-server \
    git \
    htop

systemctl enable cockpit.service
systemctl enable sshd.service
