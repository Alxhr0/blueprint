# Edward-specific customizations

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
