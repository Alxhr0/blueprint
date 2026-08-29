# Build Scripts

Build scripts for the `robin` image: an Arch Linux KDE Plasma desktop with NVIDIA
built on `ghcr.io/huntedraven7/arch-bootc:testing`, with flatpak integration and
custom ujust recipes.

## Layout

```
build/
├── 10-build.sh          # pacman: KDE Plasma, SDDM, NVIDIA, flatpak, overlays
└── clean-stage.sh       # clean pacman caches/build artifacts; always runs last
```

## Containerfile Chain

`containerfiles/robin/Containerfile.robin` runs them explicitly:

```dockerfile
RUN --mount=type=bind,from=ctx,source=/,target=/ctx ... /ctx/build/10-build.sh
RUN --mount=type=bind,from=ctx,source=/,target=/ctx ... /ctx/build/clean-stage.sh
```

Build with `just build-containerfile robin` (see the Justfile `build-containerfile`
recipe — it `cd`s into `containerfiles/robin/` and uses `Containerfile.robin`).

## Base Image

`ghcr.io/huntedraven7/arch-bootc:testing` — Arch Linux bootc base. KDE Plasma,
NVIDIA drivers, and flatpak integration are layered here.

## Package Manager

All package operations use `pacman` (Arch-native):

```bash
pacman -S --noconfirm --needed package-name
```

- `10-build.sh` order matters:
    1. Configure pacman (enable multilib).
    2. Install KDE Plasma + SDDM + NVIDIA + tooling.
    3. Overlay flatpak preinstalls, custom ujust recipes, and system_files.
- `custom/` and `system_files/` context dirs provide overlays.

## Build Script Numbering

| Prefix             | Purpose                                                     |
| ------------------ | ----------------------------------------------------------- |
| `10-build.sh`      | Main script: KDE Plasma, SDDM, NVIDIA, flatpak, services    |
| `clean-stage.sh`   | Always runs last: clears caches and artefacts               |
