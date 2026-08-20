---
name: blueprint-overview
description: >-
  Architecture, repo layout, and the real variant/base-image map for the
  blueprint personal bootc builder. Use when orienting to the repository,
  understanding how variants and base images relate, or before picking a skill
  with blueprint-router.
---

# blueprint Overview

## When to Use

- Starting a new session in this repo
- Explaining how blueprint is organized (variants vs base images)
- Orienting before using `blueprint-router` to pick a skill
- Onboarding a new contributor or agent

## When NOT to Use

- You already know the area — use the relevant skill directly
- You need specific build or CI mechanics — use `blueprint-build` or `blueprint-ci`

## Core Process

1. **Read AGENTS.md `## Start here`** for repository-wide rules and the skill sequence
2. **Identify your change area** (Containerfile/Justfile → build, workflows → ci, new variant → onboarding)
3. **Load the relevant skill** before touching anything
4. **Verify against current patterns** in `projectbluefin/actions` and the variant's upstream before deviating

## Architecture

`blueprint` is a **single repository that builds many independent bootc OS
images**. There is ONE `Justfile` build entrypoint. Every variant builds from a
SINGLE root `Containerfile` selected by build args
(`--build-arg VARIANT=<name> --build-arg BASE_IMAGE=<base> --build-arg BUILDER_SCRIPT=<script> --build-arg BUILD_SCRIPT=<script>`;
nixos also passes `--build-arg LINT=0`). `bootc-image-builder` (BIB) turns that
into qcow2/raw/iso disk images via the `just build-qcow2/raw/iso` recipes.
`fsdk` is special: it is composed with BuildStream (`buildstream/` +
`just build-fsdk`), not a `Containerfile`.

Every variant shares the native package manager of its upstream base:

| Variant | Containerfile | `images/*.env` | Native manager | Base image |
| --- | --- | --- | --- | --- |
| `gentoo` | `Containerfile` (root) | *(inline in Justfile)* | `emerge` | `gentoo/stage3:systemd` *(local build only — not built in CI; see `docs/GENTOO.md`)* |
| `nixos` | `Containerfile` (root) | *(inline in Justfile)* | `nix-env` | `nixos/nix:latest` |
| `ubuntu` | `Containerfile` (root) | *(inline in Justfile)* | `apt-get` | `ubuntu:26.04` |
| `holo-amd` | `Containerfile` (root) | *(inline in Justfile)* | `pacman` | `arch-bootc:stable` (downstream base) |
| `holo-nvidia` | `Containerfile` (root) | *(inline in Justfile)* | `pacman` | `arch-bootc:stable` (downstream base) |
| `arch` *(base)* | `Containerfile` (root) | *(inline in Justfile)* | `pacman` | `archlinux:latest` |
| `debian` *(base)* | `Containerfile` (root) | *(inline in Justfile)* | `apt` | `docker.io/library/debian:testing` |
| `opensuse` *(base)* | `Containerfile` (root) | *(inline in Justfile)* | `zypper` | `registry.opensuse.org/opensuse/tumbleweed:latest` |
| `fsdk` *(buildstream)* | `buildstream/` | `buildstream/images/fsdk.env` | BuildStream elements | `freedesktop-sdk` junction |

**Unified variants** (`arch`/`debian`/`opensuse`/`gentoo`/`nixos`/`ubuntu`/`holo-amd`/`holo-nvidia`)
build from the single root `Containerfile` (selected by `VARIANT`/`BASE_IMAGE`/`BUILDER_SCRIPT`/`BUILD_SCRIPT`
build args; nixos also sets `LINT=0`) and have NO `images/*.env`; their identity
(IMAGE_NAME, DEFAULT_TAG, description, BIB_IMAGE) is hardcoded in the `case` block
of the `Justfile` `build` recipe.

## Repo Layout

```
├── AGENTS.md                  # High-level agent instructions and mandatory gates
├── Justfile                   # Single build entrypoint (just build <variant>, build-all, build-qcow2/raw/iso, rechunk)
├── image-versions.yaml        # Pinned base digests (Renovate; promoted :stable digests)
├── artifacthub-repo.yml       # ArtifactHub metadata (currently placeholder: "my-custom-id-here")
├── cosign.pub                 # cosign public signing key (private key is a GH secret, never committed)
├── .github/
│   ├── renovate.json5         # Renovate config (digest/action pins, custom manager for image-versions.yaml)
│   └── workflows/
│       ├── build.yml          # PR + push + schedule; rechunk + push `blueprint` tags
│       ├── build-all.yml      # manual dispatch, all variants + external "homepage"
│       ├── build-base-images.yml  # nixos, ubuntu, fsdk (gentoo is local-only, see docs/GENTOO.md)
│       ├── build-arch.yml / build-debian.yml / build-opensuse.yml  # → <base>-bootc:testing
│       ├── build-holo.yml     # holo-amd, holo-nvidia (FROM arch-bootc:stable)
│       ├── build-disk.yml     # BIB disk/iso via osbuild/bootc-image-builder-action
│       ├── build-homepage.yml # external Codeberg Homepage image
│       ├── promote-arch/debian/opensuse.yml  # skopeo → PR pinning :testing digest
│       ├── tag-arch/debian/opensuse-stable.yml # merged promote PR → retag :stable + sign
│       └── zizmor.yml         # workflow security scan
├── Containerfile              # unified root Containerfile for all variants (selected by VARIANT/BASE_IMAGE/BUILDER_SCRIPT/BUILD_SCRIPT)
├── containerfiles/            # (retired) per-variant Containerfiles; all variants build from the root Containerfile
├── images/                    # (retired) per-variant .env; all variant identity is inlined in the Justfile `build` recipe `case` arms
├── build_files/               # build-*.sh scripts run inside each Containerfile
│   ├── base/                  # builder-* + build-* per distro (arch/debian/gentoo/opensuse/ubuntu)
│   ├── core/                  # shared helpers (arch-cachy.sh, enable-user-services.sh)
│   ├── holo/                  # build-amd.sh / build-nvidia.sh (pacman)
│   ├── nixos/                 # per-variant build script (nixos)
├── buildstream/               # FSDK BuildStream project (elements/, include/, images/fsdk.env)
├── system_files/              # runtime overlays copied into images
│   ├── global/                # copied FIRST so per-variant overlays win
│   ├── <variant>/             # per-variant overlay (arch, debian, holo, nixos, opensuse, ubuntu, ...)
│   └── fsdk/                  # fsdk-specific system config
├── brew/                      # Homebrew bundles (per-variant packages.Brewfile with brew/cask/flatpak entries)
├── disk_config/               # BIB disk/ISO configs: disk.toml, iso-gnome.toml, iso-kde.toml, iso-server.toml
├── installer/                 # ncurses server installer ISO (lorax/livemedia-creator)
├── sysext/                    # systemd-sysext extensions (sysext/steam/)
├── tests/                     # unit tests (rechunker ordering, bats)
└── .agents/skills/            # Discoverable <skill-name>/SKILL.md directories
```

## Scope Rules

To keep changes minimal and safe:

- **Doc tasks** (README, Agent Skills, `AGENTS.md`) → No CI impact, free to edit
- **CI tasks** (`.github/workflows/`, `renovate.json5`) → Run `actionlint` + `zizmor.yml` + YAML validation; consider supply-chain impact
- **Build tasks** (`Containerfile.*`, `build_files/`, `Justfile`) → Run `just check` + `shellcheck` (`just lint`); `bootc container lint` runs in CI
- **BuildStream tasks** (`buildstream/`) → Run `just -C buildstream validate` before opening a PR
- **Runtime tasks** (`system_files/`, `brew/`, `disk_config/`) → Validate file-specific syntax

### Files to AVOID Modifying (unless asked)

- `.github/renovate.json5` — Renovate config (auto-updates)
- `images/` — the per-variant `*.env` dotenv files are retired; variant identity is inline in the `Justfile` `build` recipe `case` arms (do not reintroduce them)
- `image-versions.yaml` — hand-edit only via `promote-<base>.yml` for `:stable` digests
- `cosign.pub` / any key material — `cosign.key` is `.gitignore`-d
- `LICENSE`, `.gitignore`

### Modify with extreme caution

- `.github/workflows/build-*.yml` — Users rely on these
- The `Justfile` `build` recipe `case` block (unified-variant + base-image identity)
- Any `FROM` line with a pinned digest (let Renovate bump it)

## Common Rationalizations

| Rationalization                                       | Reality                                                                  |
| ----------------------------------------------------- | ------------------------------------------------------------------------ |
| "AGENTS.md has everything — no need to use skills."    | AGENTS.md holds global rules. Skills provide task-specific instructions.  |
| "It's a personal repo, so conventions don't matter."  | The same agents and CI run on every push; mistakes break every image.    |

## Red Flags

- Making `Containerfile.*` / `build_files/` changes without using `blueprint-build`
- Adding a workflow without verifying the `projectbluefin/actions` composite action exists
- Updating pinned `@sha256:...` digests manually instead of letting Renovate
- Forgetting that the unified variants (`arch`/`debian`/`opensuse`/`gentoo`/`nixos`/`ubuntu`/`holo-amd`/`holo-nvidia`) have no `images/*.env` (their identity is inlined in the `Justfile` `build` recipe `case` block)

## Verification

- [ ] Do I know which skill covers my change area?
- [ ] Have I loaded that skill?
- [ ] Does the change match the variant's native package manager and upstream patterns?
