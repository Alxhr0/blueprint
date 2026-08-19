#!/usr/bin/env bash
set -xeuo pipefail

# Install a GNOME desktop on top of the minimal AlmaLinux Kitten 10 bootc base.
# Alma 10 ships GNOME in AppStream; we enable CRB + EPEL for the extras the
# bluefin/common desktop files expect.

MAJOR_VERSION_NUMBER="$(sh -c '. /usr/lib/os-release ; echo ${VERSION_ID%.*}')"

# CodeReady Builder provides many desktop/tooling dependencies.
dnf config-manager --set-enabled crb || true

# EPEL 10 (best-effort; harmless if the repo is not yet published)
dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${MAJOR_VERSION_NUMBER}.noarch.rpm" || true
dnf config-manager --set-enabled crb || true

# Full GNOME Workstation environment.
dnf -y group install "Workstation" \
  || dnf -y install @gnome-desktop-environment

# Core desktop plumbing that we want explicitly present.
dnf -y install \
  gdm \
  plymouth \
  plymouth-system-theme \
  fwupd \
  systemd-resolved \
  systemd-oomd \
  xdg-user-dirs-gtk \
  xdg-desktop-portal-gnome \
  network-manager-applet

# Rebuild the gsettings schema cache now so later steps can compile overrides.
glib-compile-schemas /usr/share/glib-2.0/schemas 2>/dev/null || true
