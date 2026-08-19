# Edward-specific customizations

# Remove GNOME packages that conflict with COSMIC (from the bluefin-lts base)
# First clear the GNOME 50 versionlock so these can actually be removed
dnf versionlock clear 2>/dev/null || true

GNOME_CONFLICT_PKGS=(
    gdm
    gnome-shell
    mutter
    gnome-session-wayland-session
    gnome-settings-daemon
    gnome-control-center
    gnome-remote-desktop
    gnome-initial-setup
    gnome-bluetooth
    gnome-color-manager
    gnome-user-docs
    xdg-desktop-portal-gnome
    xdg-user-dirs-gtk
    adwaita-fonts-all
    centos-backgrounds
    gnome-disk-utility
    papers-thumbnailer
    yelp-tools
)
dnf5 -y remove --skip-unavailable "${GNOME_CONFLICT_PKGS[@]}" 2>/dev/null || true

# Install COSMIC Desktop from the enterprise-cosmic COPR
dnf5 -y copr enable ligenix/enterprise-cosmic || true
dnf5 -y install --skip-unavailable cosmic-desktop || true
dnf5 -y copr disable ligenix/enterprise-cosmic || true

# Replace GDM with COSMIC Greeter (greetd)
systemctl disable gdm.service || true
systemctl enable cosmic-greeter.service || true

# Enable user services (only if they exist to avoid dangling symlinks)
mkdir -p /etc/systemd/user/graphical-session.target.wants
mkdir -p /etc/systemd/user/default.target.wants

if [ -f /usr/lib/systemd/user/homepage.service ]; then
    ln -sfn /usr/lib/systemd/user/homepage.service \
        /etc/systemd/user/default.target.wants/homepage.service
fi
if [ -f /usr/lib/systemd/user/ai.service ]; then
    ln -sfn /usr/lib/systemd/user/ai.service \
        /etc/systemd/user/default.target.wants/ai.service
fi
