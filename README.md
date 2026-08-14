<div align="center">
  <img src="assets/Engineer_Tux.png" alt="blueprint logo" width="200"/>

  # blueprint

  Custom bootc-based OS images.
</div>

## Overview

`blueprint` builds a family of custom, container-native (bootc) OS images — one Containerfile per flavor, sharing common build scripts and system files where it makes sense.

This also host images such as the AI, Edward, Crmy and Aira images these are not made to be for everyone infact these are made for myself and my friends it is not recommended to use unless 
unless you have read what the images do and they fit you!

## Flavors

| Flavor | Containerfile | Notes |
|---|---|
| edward | `containerfiles/Containerfile.edward` | Edward's own desktop image |
| arch | `containerfiles/Containerfile.arch` | Arch-based |
| debian | `containerfiles/Containerfile.debian` | Debian-based |
| gentoo | `containerfiles/Containerfile.gentoo` | Gentoo-based |
| opensuse | `containerfiles/Containerfile.opensuse` | OpenSUSE Tumbleweed-based |
| ubuntu | `containerfiles/Containerfile.ubuntu` | Ubuntu 26.04-based |
| server | `containerfiles/Containerfile.server` | headless/server |
| ai | `containerfiles/Containerfile.ai` | AI tooling |
| aira | `containerfiles/Containerfile.aira` | A custom Bazzite image for my Friend! |
| crmy | `containerfiles/Containerfile.crmy` | A custom dev focused image for my Friend! |
| holo-amd / holo-nvidia | `containerfiles/Containerfile.holo-*` | GPU-specific SteamOS like variants |

## Repository layout

```
blueprint/
├── .github/                     # CI: dependabot, renovate, build workflows
├── Justfile                     # build/dev commands
├── artifacthub-repo.yml         # ArtifactHub metadata
├── cosign.pub                   # image signing public key
├── assets/                      # logos
├── brew/                        # Homebrew bundle files
├── build_files/                 # build-*.sh scripts run inside each Containerfile
├── containerfiles/              # one Containerfile per image flavor
├── disk_config/                 # disk/ISO layout configs (disk.toml, iso-*.toml)
├── images/                      # per-flavor .env build config
├── sysext/                      # systemd-sysext extensions (e.g. steam)
├── system_files/                # files to all flavors such as Edward, Aira, Arch and Holo copied into the image
```

## Building

```sh
just <recipe>
```

See `Justfile` for available build recipes.

## Signing

Images are signed with cosign. Public key: `cosign.pub`.
