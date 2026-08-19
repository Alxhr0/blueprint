#!/usr/bin/env bash
set -xeuo pipefail

# Enable the Terra repository (https://terrapkg.com) for CentOS Stream / EL.
# Provides a large set of extra packages not shipped in EPEL.
# Follows https://docs.terrapkg.com/usage/installing/ (AlmaLinux/CentOS Stream/Rocky section).
# crb + epel-release are already enabled earlier in the build (10/20/30 scripts).
#
# NOTE: Terra subrepos (extras/nvidia/mesa/multimedia) are not available on
# Enterprise Linux, so only the base terra repo is enabled here.

dnf config-manager --set-enabled crb || true

dnf install -y --nogpgcheck \
  --repofrompath 'terra,https://repos.fyralabs.com/terrael$releasever' \
  terra-release terra-gpg-keys
