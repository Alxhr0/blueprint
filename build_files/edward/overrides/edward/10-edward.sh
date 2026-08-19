# Edward-specific customizations

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
