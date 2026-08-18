#!/usr/bin/env bash
set -xeuo pipefail

# Docker CE (newer than the LTS default container stack)
curl -fsSL https://download.docker.com/linux/centos/docker-ce.repo \
    -o /etc/yum.repos.d/docker-ce.repo

dnf -y install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
