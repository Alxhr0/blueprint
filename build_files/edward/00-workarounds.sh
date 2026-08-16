#!/usr/bin/env bash
set -xeuo pipefail

MAJOR_VERSION_NUMBER="$(sh -c '. /usr/lib/os-release ; echo ${VERSION_ID%.*}')"

# Enable CRB (PowerTools/EPEL equivalent for AlmaLinux)
dnf config-manager --set-enabled crb

# Install EPEL
dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${MAJOR_VERSION_NUMBER}.noarch.rpm"

# Enable EPEL
dnf config-manager --set-enabled epel

# Multimedia codecs from negativo17
dnf config-manager --add-repo=https://negativo17.org/repos/epel-multimedia.repo
dnf config-manager --set-disabled epel-multimedia
