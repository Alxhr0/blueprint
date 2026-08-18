# Blueprint Server Installer — Anaconda Kickstart
# Used by livemedia-creator to build a live ISO that boots into the ncurses installer.

lang en_US.UTF-8
keyboard us
timezone UTC
zerombr
clearpart --all --initlabel
autopart --type=plain

# Network — DHCP in live environment
network --bootproto=dhcp --activate

# No root password for live environment — we're just building a live image
# The installer script handles the real root password for the target system
rootpw --lock --plaintext live

# Packages needed in the live environment
%packages
@core
kernel
dracut-live
bash
coreutils
util-linux
systemd
-@dial-up
-@input-methods
%end

# Post-install: set up the live environment
%post --log=/var/log/blueprint-live-setup.log
set -ex

# Enable networking
systemctl enable NetworkManager

# Set hostname for the live environment
hostnamectl set-hostname blueprint-installer

# Allow root login on tty1 for the installer
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM
EOF

# Set root to drop straight into the installer on tty1
mkdir -p /root
cat > /root/.bash_profile <<'EOF'
if [[ -z "$BLUEPRINT_INSTALLED" ]] && [[ "$(tty)" == "/dev/tty1" ]]; then
    export BLUEPRINT_INSTALLED=1
    /usr/bin/blueprint-install
fi
EOF

%end
