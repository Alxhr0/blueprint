#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files"/. /

mkdir -p /var/roothome

dnf5 -y install \
    cockpit \
    cockpit-podman \
    openssh-server \
    git \
    tmux \
    htop

systemctl enable cockpit.socket
systemctl enable sshd.service
source /ctx/enable-user-services.sh
enable_user_service brew-preinstall.service
