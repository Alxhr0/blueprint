#!/usr/bin/env bash
set -xeuo pipefail

READ_PKGS="python3 /run/context/build_scripts/scripts/read-packages"
PKGS_TOML="/run/context/build_scripts/packages/base.toml"

MAJOR_VERSION_NUMBER="$(sh -c '. /usr/lib/os-release ; echo ${VERSION_ID%.*}')"

# Install dnf plugins core first (provides config-manager)
dnf -y install dnf-plugins-core

# Enable CRB (PowerTools/EPEL equivalent for AlmaLinux)
dnf config-manager --set-enabled crb

# Install EPEL
dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${MAJOR_VERSION_NUMBER}.noarch.rpm"
dnf config-manager --set-enabled epel

# Multimedia codecs from negativo17
dnf config-manager --add-repo=https://negativo17.org/repos/epel-multimedia.repo
dnf config-manager --set-disabled epel-multimedia

# Install dnf versionlock plugin
dnf -y install 'dnf-command(versionlock)'

# GNOME 50+ COPR repo (built for EL10, compatible with AlmaLinux 10)
# This provides GNOME 50+ packages not yet in stock AlmaLinux 10 repos.
dnf config-manager --add-repo "https://copr.fedorainfracloud.org/coprs/jreilly1821/c10s-gnome-50/repo/epel-${MAJOR_VERSION_NUMBER}/jreilly1821-c10s-gnome-50-epel-${MAJOR_VERSION_NUMBER}.repo"
GNOME50_REPO=$(find /etc/yum.repos.d/ -name "*jreilly1821*gnome-50*" | head -1)
echo "exclude=libjxl*" >> "${GNOME50_REPO}"

# These upgrades MUST happen before the GNOME group install.
# glib2: EL10 ships 2.80.x; GNOME 50 requires newer API symbols.
# fontconfig: COPR pango 1.57+ links FcConfigSetDefaultSubstitute (added in
#   fontconfig 2.17.0); EL10 base ships 2.15.0 — causes a symbol lookup error
#   at gnome-shell startup.
dnf -y upgrade glib2 fontconfig

# Install GNOME packages from manifest
readarray -t GNOME_PKGS    < <($READ_PKGS "$PKGS_TOML" gnome)
readarray -t GNOME_EXCL    < <($READ_PKGS "$PKGS_TOML" gnome_excluded)
GNOME_EXCLUDE_ARGS=()
for pkg in "${GNOME_EXCL[@]}"; do GNOME_EXCLUDE_ARGS+=(-x "$pkg"); done
dnf -y install "${GNOME_EXCLUDE_ARGS[@]}" "${GNOME_PKGS[@]}"

# Additional desktop packages
dnf -y install \
	plymouth \
	plymouth-system-theme \
	fwupd \
	systemd-{resolved,container,oomd}

# Remove centos-logos if present and replace with generic
rpm --erase --nodeps centos-logos 2>/dev/null || true
