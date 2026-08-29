# Build Scripts

Build scripts for the `edward` image: an Arch-based GNOME desktop built on
`ghcr.io/huntedraven7/arch-bootc:testing`, consuming the OGC `linux-ogc`
kernel + nvidia modules from the `akmods/` cache and the ublue `@ublue-os/brew`
integration.

## Layout

```
build/
├── 10-build.sh          # pacman: OGC kernel + nvidia, GNOME, XFS, brew, overlays
└── clean-stage.sh       # clean pacman caches/build artifacts; always runs last
```

## Containerfile Chain

`containerfiles/edward/Containerfile.edward` runs them explicitly:

```dockerfile
RUN --mount=type=bind,from=ctx,source=/,target=/ctx ... /ctx/build/10-build.sh
RUN --mount=type=bind,from=ctx,source=/,target=/ctx ... /ctx/build/clean-stage.sh
```

Build with `just build-containerfile edward` (see the Justfile `build-containerfile`
recipe — it `cd`s into `containerfiles/edward/` and uses `Containerfile.edward`).

## Base Image

`ghcr.io/huntedraven7/arch-bootc:testing` — minimal Arch bootc (systemd,
NetworkManager, podman, pacman + keyring, `xfsprogs`). It has **no desktop and
no nvidia**; both are layered in here. The base boots the stock `linux` kernel
via dracut; edward switches to the OGC kernel + mkinitcpio.

## Package Manager

All package operations use `pacman` (Arch-native):

```bash
pacman -S --noconfirm --needed package-name
```

- `10-build.sh` order matters:
  1. `pacman -Syu`, then install `mkinitcpio` **before** the kernel so the
     kernel's install hook can regenerate the initramfs.
  2. Install the pinned `linux-ogc` + `linux-ogc-headers` from
     `/ctx/oci/akmods/kernel/` via `pacman -U`.
  3. Install GNOME/GDM + tooling; drop the stock `linux` so linux-ogc is active.
  4. Install the cached nvidia `.ko` into `/usr/lib/modules/<kver>/extra/nvidia/`,
     run `depmod -a`.
  5. Verify XFS support and pin `MODULES=(xfs)` in `/etc/mkinitcpio.conf` so the
     initramfs can mount an XFS `/` after `bootc switch`; then `mkinitcpio -P`.
- `@ublue-os/brew` files are overlaid with `rsync /ctx/oci/brew/ /`; the Brewfiles,
  custom ujust recipes (`60-custom.just`), flatpak preinstalls, and `system_files`
  are copied from the `custom/` and `system_files/` context dirs.

## Build Script Numbering

| Prefix             | Purpose                                                     |
| ------------------ | ----------------------------------------------------------- |
| `10-build.sh`      | Main script: kernel + nvidia, packages, XFS, overlays, services |
| `clean-stage.sh`   | Always runs last: clears caches and artefacts               |
