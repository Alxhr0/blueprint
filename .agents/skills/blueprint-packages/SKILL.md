---
name: blueprint-packages
description: >-
  Decision tree for where to add packages in blueprint. Maps requests to the
  correct file and install method: build-time Containerfile/build_files RUN,
  runtime Homebrew bundle, or BuildStream elements. Use when deciding how to add
  a new package or tool.
---

# blueprint Package Decision Tree

## When to Use

- A user or agent asks "how do I add package X?"
- You need to decide whether a package belongs at build-time or runtime
- Reviewing a PR that adds packages and verifying they are in the right place
- Editing a `build_files/` script or a `Brewfile`

## When NOT to Use

- You already know the target file and install method — go edit it directly
- You are debugging why a package fails to install — use `blueprint-troubleshooting`

## Core Process

1. **Identify the variant and its native package manager**
2. **Use the decision table below** to map it to the correct path
3. **Apply the installation pattern** for that path, using `-y`/non-interactive flags
4. **Consider scope**: doc tasks (no CI impact) vs build/CI tasks (trigger validation)

## Native package managers by variant

| Variant | Manager | Install command |
| --- | --- | --- |
| `ubuntu` | `apt`/`apt-get` | `apt-get install -y pkg` |
| `arch`, `holo-amd`, `holo-nvidia` | `pacman` | `pacman -S --noconfirm pkg` |
| `debian` | `apt` | `apt-get install -y pkg` |
| `opensuse` | `zypper` | `zypper install -y pkg` |
| `gentoo` | `emerge` | `emerge pkg` |
| `nixos` | `nix-env` | `nix-env -iA nixpkgs.pkg` |
| `fsdk` | BuildStream elements | edit `buildstream/elements/fsdk/fsdk-stack.bst` |

**Never mix managers inside one variant.** A variant's build script uses exactly
one manager consistent with its base image.

## Decision Table

| Request                              | Action                                              | Location                                      |
| ------------------------------------ | --------------------------------------------------- | --------------------------------------------- |
| Add a system package (rpm/dnf5)      | `dnf5 install -y pkg`                               | `build_files/<variant>/build-<variant>.sh`    |
| Add a system package (arch/pacman)   | `pacman -S --noconfirm pkg`                         | `build_files/holo/build-amd.sh` etc.          |
| Add a system package (apt)           | `apt-get install -y pkg`                            | `build_files/base/build-ubuntu.sh` etc.       |
| Add a system package (zypper)        | `zypper install -y pkg`                             | `build_files/base/build-opensuse.sh`          |
| Add a system package (gentoo)        | `emerge pkg`                                        | `build_files/base/build-gentoo.sh`            |
| Enable a systemd service             | `systemctl enable service.name`                     | the variant's build script                    |
| Add a CLI tool (runtime, Homebrew)   | `brew "pkg"`                                        | `brew/<variant>/packages.Brewfile`            |
| Add a GUI app (runtime, Flatpak)     | `flatpak "org.app.id"`                              | `brew/<variant>/packages.Brewfile`            |
| Add a Homebrew cask                  | `cask "name"`                                       | `brew/<variant>/packages.Brewfile`            |
| Add a component to FSDK              | add to `depends:` in `fsdk-stack.bst`              | `buildstream/elements/fsdk/fsdk-stack.bst`    |
| Switch base image | Update the `BASE_IMAGE` arg in the Justfile `case` arm (root `Containerfile`), not a `FROM` line | `Justfile` `build` recipe `case` (root `Containerfile` `ARG BASE_IMAGE`) |

## Build-Time: `build_files/<variant>/build-<variant>.sh`

System packages are installed at build-time and baked into the container image.
Each variant has its own build script (e.g. `build_files/holo/build-amd.sh`). The
`Containerfile` invokes it via a `RUN --mount=type=bind,from=ctx ...` block.

**Rules:**

- Use the variant's native manager (table above) — never `dnf`/`yum`/`rpm-ostree` in a
  Fedora-family variant; use `dnf5`.
- Always use a non-interactive flag (`-y`, `--noconfirm`, `-y --no-install-recommends`).
- Copy `system_files/global` **before** the per-variant overlay (arch/opensuse/holo
  build scripts COPY `system_files/global` then `system_files/<variant>` at build context stage).
- End with cleanup + `bootc container lint` where the upstream pattern does.

## Runtime Homebrew: `brew/<variant>/packages.Brewfile`

`brew/<variant>/packages.Brewfile` is the per-variant Homebrew bundle. It supports three
entry kinds: `tap`, `brew`, `cask`, and `flatpak` (a Brewfile extension used by
the ublue-os homebrew bundle). These install **after first boot**.

**Rules:**

- Keep package selections in the `Brewfile`, not baked into the image.
- Add new taps at the top with `trusted: true` (e.g. `ublue-os/tap`).
- The build wires the Brewfile into `/usr/share/ublue-os/homebrew/Brewfile` and a
  `brew-bundle.conf` (see the variant's build script).

## BuildStream (FSDK): `buildstream/elements/`

`fsdk` is composed from `freedesktop-sdk` components. Add a package by editing
`buildstream/elements/fsdk/fsdk-stack.bst` `depends:`, updating the slim recipe
in `buildstream/include/slim.yml` if it brings runtime bloat, and
`buildstream/elements/targets.json` if adding a new image. Validate with
`just -C buildstream validate` before opening a PR.

## Scope Rules

### Doc Tasks (No CI Impact)

README edits, comments, AGENTS.md/skills → no CI.

### CI / Build Tasks

- Modified `build_files/*.sh` → `just lint` (shellcheck) + `just check`
- Modified `*.just` → `just --unstable --fmt --check -f <file>`
- Modified `buildstream/` → `just -C buildstream validate`
- Modified `Brewfile` → verify entries exist (flatpak IDs on Flathub)

## Common Rationalizations

| Rationalization                                                       | Reality                                                                                                  |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| "I'll put this CLI tool in the build script so it's always available."| Build-time packages bloat the image. Runtime Homebrew is preferred for CLI tools installed on demand.    |
| "I'll add a GUI app via dnf5/apt so it works offline."                | Flatpaks (via the Brewfile `flatpak` entries) are the runtime standard; keep the container small.        |
| "I'll use `dnf`/`yum` since dnf5 might not be installed."             | Never. `dnf5` is the canonical tool for Fedora-family variants. Use the variant's native manager only.   |
| "This variant can use pacman and dnf5 together."                      | Never mix managers. Each variant has exactly one native manager.                                         |

## Red Flags

- A package manager that doesn't match the variant's base (e.g. `dnf5` in an `arch`/`holo` build)
- A build script missing a non-interactive flag
- A `flatpak`/GUI app installed at build-time instead of via the Brewfile
- A Brewfile entry whose Flatpak ID isn't verified on Flathub
- FSDK package added without updating `fsdk-stack.bst` `depends:`

## Verification

- [ ] Does the package type match the chosen install method and the variant's native manager?
- [ ] Does the build script use a non-interactive install flag?
- [ ] Is `system_files/global` copied before the variant overlay (where applicable)?
- [ ] For Brewfile: do `brew`/`cask`/`flatpak` entries resolve?
- [ ] For FSDK: did `just -C buildstream validate` pass?
- [ ] Does the changed path trigger the correct validation (`just lint`, `just check`)?
