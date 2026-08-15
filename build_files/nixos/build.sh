#!/bin/sh
set -eux

cp -avf "/ctx/system_files/global"/. /
cp -avf "/ctx/system_files/nixos"/. /

nix-channel --add https://nixos.org/channels/nixos-26.05 nixos
nix-channel --add https://nixos.org/channels/nixos-26.05 nixpkgs
nix-channel --update

mkdir -p /etc/nixos
cat > /etc/nixos/bootc.nix <<'EOF'
{ config, lib, pkgs, ... }:

{
  options = {
    bootc.enable = lib.mkEnableOption "bootc (bootable container) support";
    services.bootc = {
      enable = lib.mkEnableOption "the bootc systemd services";
      autoUpdate = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to automatically fetch and apply bootc updates on a timer.";
      };
    };
  };

  config = lib.mkIf config.bootc.enable {
    system.etc.overlay.enable = lib.mkDefault true;
    environment.systemPackages = [ pkgs.bootc ];
    systemd = lib.mkIf config.services.bootc.enable {
      packages = [ pkgs.bootc ];
      timers."bootc-fetch-apply-updates" = lib.mkIf config.services.bootc.autoUpdate {
        wantedBy = [ "timers.target" ];
      };
    };
  };
}
EOF

cat > /etc/nixos/configuration.nix <<'EOF'
{ config, lib, pkgs, ... }:

{
  imports = [
    ./bootc.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader.grub.enable = false;
  fileSystems."/" = {
    device = "/dev/null";
    fsType = "tmpfs";
  };

  environment.systemPackages = with pkgs; [
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
    python314Packages.pip
    pipx
    nodejs
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
    bpftools
    iperf3
    netcat
    nmap
    tcpdump
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
    autofs5
    systemd
    chrony
    ntp
    openssh
    sudo
    (pass.withExtensions (exts: [ exts.pass-otp ]))
    age
    sops
    gnupg
    pinentry-curses
    openssl
    libsecret
    keyutils
    krb5
    ldapvi
    adcli
    realmd
    sssd
    pam_krb5
    pam_ldap
    pam_mount
    encfs
    gocryptfs
    veracrypt
    clevis
    tang
    yubikey-manager
    yubico-pam
    pam_u2f
    oath-toolkit
    pamtester
    linux-pam
  ];

  bootc.enable = true;

  services.bootc = {
    enable = true;
    autoUpdate = false;
  };

  system.stateVersion = "26.05";
}
EOF

export NIX_PATH="nixos-config=/etc/nixos/configuration.nix:nixpkgs=/root/.nix-defexpr/channels/nixpkgs:/root/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels"

nixos-rebuild build -I nixos=/root/.nix-defexpr/channels/nixos --flake /etc/nixos#default 2>/dev/null || nixos-rebuild build -I nixos=/root/.nix-defexpr/channels/nixos

SYSTEM_PATH=$(readlink -f result)

mkdir -p /sysroot/ostree/repo
ostree init --mode=bare-user --no-fsync --path=/sysroot/ostree/repo

ostree commit --repo=/sysroot/ostree/repo \
  --branch=blueprint/nixos \
  --subject="Blueprint NixOS bootc image" \
  --add-metadata-string="version=$(date +%Y%m%d)" \
  --no-xattrs \
  "${SYSTEM_PATH}"

ostree summary --repo=/sysroot/ostree/repo --update --ref=blueprint/nixos

mkdir -p /sysroot/ostree/deploy/blueprint/nixos/0

ln -sT sysroot/ostree /ostree
ln -sT var/roothome /root
ln -sT var/srv /srv
ln -sT var/mnt /mnt
ln -sT var/opt /opt
ln -sT var/home /home
ln -sT var/usrlocal /usr/local

printf 'd /var/home 0755 root root -\nd /var/srv 0755 root root -\nd /var/mnt 0755 root root -\nd /var/opt 0755 root root -\nd /var/usrlocal 0755 root root -\nd /var/roothome 0700 root root -\nd /run/media 0755 root root -\n' > /usr/lib/tmpfiles.d/bootc-base-dirs.conf

printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' > /usr/lib/ostree/prepare-root.conf

mkdir -p /output/etc/bootc
cp /etc/nixos/configuration.nix /output/etc/bootc/configuration.nix
cp /etc/bootc.toml /output/etc/bootc/bootc.toml 2>/dev/null || true

mkdir -p /output/etc/nixos
cp /etc/nixos/configuration.nix /output/etc/nixos/configuration.nix
cp /etc/nixos/bootc.nix /output/etc/nixos/bootc.nix
cp /etc/nixos/flake.nix /output/etc/nixos/flake.nix 2>/dev/null || true
cp /etc/nixos/lock.json /output/etc/nixos/lock.json 2>/dev/null || true

mkdir -p /output/var/lib/bootc
cp -r /var/lib/bootc/* /output/var/lib/bootc/ 2>/dev/null || true

mkdir -p /output/sysroot/ostree
cp -r /sysroot/ostree/repo /output/sysroot/ostree/repo

mkdir -p /output/ostree
ln -sfnT /sysroot/ostree /output/ostree
