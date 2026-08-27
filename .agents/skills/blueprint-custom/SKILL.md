---
name: blueprint-custom
description: >-
  Runtime layer of blueprint: system_files overlays, the Homebrew bundle, and
  disk/ISO configs. Use when modifying system_files/, brew/, or disk_config/,
  or explaining the runtime-vs-build-time distinction.
---

# blueprint Runtime Layer

## When to Use

- Adding or editing runtime overlays in `system_files/<variant>/`
- Adding or editing the Homebrew bundle (`brew/<variant>/packages.Brewfile`)
- Adding or editing BIB disk/ISO configs (`disk_config/*.toml`)
- Explaining the runtime vs build-time distinction to contributors

## When NOT to Use

- Containerfile / Justfile / build_files changes — use `blueprint-build`
- CI workflow changes — use `blueprint-ci`
- Adding system packages at build-time — use `blueprint-packages`

## Core Process

1. **Identify the runtime need**: overlay file, Homebrew package, or disk/ISO layout
2. **Choose the right location**: `system_files/`, `brew/`, or `disk_config/`
3. **Apply correct syntax** for each file type
4. **Validate locally** before opening a PR

## Runtime overlays: `system_files/`

`system_files/` holds files copied into the built image. Structure:

- `system_files/global/` — copied **first** in every variant, so per-variant
  files win when they conflict. (Currently holds only `.gitkeep` placeholders —
  the copying convention is still load-bearing; keep the `global` copy order.)
- `system_files/<variant>/` — per-variant overlay (e.g. `arch`, `holo`,
  `opensuse`, `ubuntu`, `fsdk`, ...). Most have a `.gitkeep`
  only; the variant-specific layer holds container-launch, dconf, overrides, and
  service units where a variant needs them.

**Rules:**

- The `Containerfile` (or variant build script) must COPY `system_files/global`
  before `system_files/<variant>` so the variant overlay takes precedence.
- Each variant's build script copies `system_files/<variant>` (after the shared
  `system_files/global`); see the variant's `build_files/` layout.
- Copy each overlay with its **contents**, i.e. `cp -avf "/ctx/system_files/global"/. /`
  then `cp -avf "/ctx/system_files/<variant>"/. /`. Never copy the parent
  `system_files` dir into `/` (`cp -avf "/ctx/system_files"/. /`): that drops
  the `global/` and `<variant>/` folders themselves into `/`, leaving stray
  `/global` and `/<variant>` dirs in the image root (issue #19).
- Don't ship secret material in overlays.

## Homebrew bundle: `brew/<variant>/packages.Brewfile`

Per-variant bundles live under `brew/<variant>/packages.Brewfile`. A Brewfile
has four entry kinds:

```ruby
tap "ublue-os/tap", trusted: true
cask "visual-studio-code-linux"
brew "eza"
flatpak "com.valvesoftware.Steam"
```

**Rules:**

- `brew "..."` → CLI/dev tools; `cask "..."` → GUI apps distributed as casks;
  `flatpak "..."` → GUI apps installed via Flatpak (verify the ID on Flathub).
- The build wires this into `/usr/share/ublue-os/homebrew/Brewfile` and a
  `brew-bundle.conf` pointing at the raw GitHub URL (see the variant's build script).
- Per-variant bundles live under `brew/<variant>/` so each image can differ.

**Validation:**

- Verify `brew`/`cask` names resolve; verify Flatpak IDs exist on Flathub.

## Disk / ISO configs: `disk_config/`

BIB consumes TOML configs when building disk/ISO images:

- `disk.toml` — generic qcow2/raw filesystem layout (`[[customizations.filesystem]]`).
- `iso-gnome.toml` — live GNOME installer ISO (bootc-installer, minimal Anaconda modules).
- `iso-kde.toml` — KDE installer ISO.
- `iso-server.toml` — Anaconda server ISO with kickstart (`customizations.installer.kickstart`).

**Note:** the `Justfile` `build-iso` recipe and `build-disk.yml` reference
`disk_config/iso.toml`, which **does not exist**. Use the explicit variants
(`just build-iso-gnome` → `iso-gnome.toml`, `just build-server-iso` →
`iso-server.toml`) instead. See `blueprint-troubleshooting`.

## The ncurses installer: `installer/`

`installer/build-installer-iso.sh` builds a server installer ISO with lorax +
livemedia-creator (requires root). It uses `blueprint-installer.ks` and the
`installer/systemd/blueprint-installer.service`. Invoke via
`just build-installer-iso` / `just run-installer-iso`.

## Common Rationalizations

| Rationalization                                                       | Reality                                                                                          |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| "I'll put the variant overlay in `global` to keep it simple."         | `global` is copied first and is meant to be shared; per-variant changes belong in `system_files/<variant>/`. |
| "I'll add the GUI app via dnf5/apt so it's baked in."                | Runtime apps go in the Brewfile (`brew`/`cask`/`flatpak`), not the image.                         |
| "system_files/global is empty, so I can skip copying it."            | The copy order is load-bearing: variant files must overwrite global. Keep the ordering.          |

## Red Flags

- `system_files/global` copied AFTER the variant overlay (variant files would lose)
- Flatpak ID in a Brewfile not verified on Flathub
- `disk_config/iso.toml` referenced but missing (use the explicit variant tomls)
- Secret material committed inside a `system_files/` overlay

## Verification

- [ ] Is the overlay in the correct `system_files/<variant>/` directory?
- [ ] Is `system_files/global` copied before the variant overlay?
- [ ] Do all Flatpak IDs in the Brewfile resolve on Flathub?
- [ ] Is the correct `disk_config/*.toml` referenced (not the missing `iso.toml`)?
- [ ] Did `just lint` / `just check` pass for any changed scripts?
