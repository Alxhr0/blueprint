#!/bin/bash
set -ouex pipefail

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/nixos"/. /

nix-channel --add https://nixos.org/channels/nixos-24.05 nixos
nix-channel --update

mkdir -p /etc/nixos
cat > /etc/nixos/configuration.nix <<'EOF'
{ config, pkgs, ... }:

{
  imports = [ ];

  bootc.enable = true;

  environment.systemPackages = with pkgs; [
    bootc
    git
    curl
    wget
    jq
    vim
    nano
    htop
    btop
    tmux
    screen
    sshfs
    fuse
    podman
    docker
    skopeo
    buildah
    python3
    python3-pip
    nodejs
    npm
    yarn
    rustc
    cargo
    go
    jdk
    gcc
    gdb
    strace
    ltrace
    perf
    bpftrace
    bpftool
    iperf3
    netcat
    nmap
    tcpdump
    wireshark
    whois
    dnsutils
    iputils
    ethtool
    pciutils
    usbutils
    lshw
    dmidecode
    smartmontools
    hdparm
    sdparm
    parted
    gptfdisk
    dosfstools
    e2fsprogs
    xfsprogs
    btrfs-progs
    nilfs-utils
    zfs
    lvm2
    cryptsetup
    mdadm
    bcache-tools
    nfs-utils
    cifs-utils
    sshfs
    autofs5
    systemd
    systemd-boot
    systemd-resolved
    systemd-networkd
    systemd-timesyncd
    chrony
    ntp
    openssh
    sudo
    doas
    pass
    pass-otp
    age
    sops
    gnupg
    pinentry
    pinentry-curses
    pinentry-gtk2
    openssl
    libsecret
    keyutils
    krb5
    ldapvi
    adcli
    realmd
    sssd
    nsswitch
    pam_krb5
    pam_ldap
    pam_mount
    ecryptfs
    encfs
    gocryptfs
    cryfs
    veracrypt
    truecrypt
    luksipc
    clevis
    tang
    cryptsetup-yubikey
    yubikey-manager
    yubico-pam
    pam_u2f
    oath-toolkit
    pamtester
    libpam
    linux-pam
  ];

  services.bootc = {
    enable = true;
    autoUpdate = false;
  };

  system.stateVersion = "24.05";
}
EOF

nixos-rebuild build --flake /etc/nixos#default 2>/dev/null || nixos-rebuild build

mkdir -p /output/etc/nixos
cp /etc/nixos/configuration.nix /output/etc/nixos/configuration.nix
cp /etc/nixos/flake.nix /output/etc/nixos/flake.nix 2>/dev/null || true
cp /etc/nixos/lock.json /output/etc/nixos/lock.json 2>/dev/null || true

mkdir -p /output/etc/bootc
cp /etc/bootc.toml /output/etc/bootc/bootc.toml 2>/dev/null || true

mkdir -p /output/nix/store
cp -r /nix/store/* /output/nix/store/ 2>/dev/null || true

mkdir -p /output/etc/systemd/system
cp -r /etc/systemd/system/* /output/etc/systemd/system/ 2>/dev/null || true

mkdir -p /output/var/lib/bootc
cp -r /var/lib/bootc/* /output/var/lib/bootc/ 2>/dev/null || true
