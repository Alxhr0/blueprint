#!/usr/bin/env bash
set -xeuo pipefail

# Remove any pre-installed distro containerd / docker packages to avoid obsoletion/replacement conflicts
dnf -y remove \
    containerd \
    docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-engine \
    moby-engine || true

# Docker CE (newer than the LTS default container stack)
curl -fsSL https://download.docker.com/linux/centos/docker-ce.repo \
    -o /etc/yum.repos.d/docker-ce.repo

dnf clean all

dnf -y \
    --refresh \
    --setopt=retries=10 \
    --setopt=timeout=60 \
    install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
