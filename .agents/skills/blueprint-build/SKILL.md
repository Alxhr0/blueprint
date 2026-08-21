---
name: blueprint-build
description: >-
  Containerfile build stages, image digest pinning, the Justfile build recipes,
  build_files scripts, BuildStream (fsdk), and rechunking. Use when changing
  Containerfile, Justfile, build_files, buildstream, or image pins.
---

# blueprint Build System

## When to Use

- Editing the root `Containerfile` (FROM, stages, RUN)
- Editing the `Justfile` (build recipe, tag strategy, rechunk)
- Adding or modifying `build_files/**/*.sh`
- Editing the BuildStream project (`buildstream/`)
- Debugging why a local build differs from CI

## When NOT to Use

- CI workflow changes (`.github/workflows/`) — use `blueprint-ci`
- Runtime customizations (`system_files/`, `brew/`) — use `blueprint-custom`

## Core Process

1. **Identify which `FROM` line / env drives your change**
2. **All image digests** are pinned in `FROM` lines and `image-versions.yaml`; Renovate updates them
3. **Run `just build <variant>`** locally before opening a PR; `just lint` for shellcheck; `just check` for justfmt
4. **For fsdk**, use `just build-fsdk` (BuildStream), not `just build`

## The `Justfile` `build` recipe

`just build <target_image> [tag]` is the single entrypoint. It:

- Resolves metadata from the `Justfile` `build` recipe `case` block — all variant identity is inlined there (no per-variant `images/*.env`; the old shared `dotenv-filename` primary env is gone).
- For all variants (`arch`/`debian`/`opensuse`/`gentoo`/`nixos`/`ubuntu`/`holo-amd`/`holo-nvidia`) the `case` block supplies the identity inline (no env file).
- Picks the root `Containerfile` (with `CONTAINERFILE="Containerfile"` and the `VARIANT`/`BASE_IMAGE`/`BUILDER_SCRIPT`/`BUILD_SCRIPT` build args; nixos also sets `LINT=0`) for every variant.
- Builds with `podman build --build-arg ... --pull=newer --tag <IMAGE_NAME>:<TAG>`.
- Adds ArtifactHub/OCI labels (only when the git tree is clean, so source/version
  URLs resolve to a real commit).

Key args: `MAJOR_VERSION` (default `10`), `GNOME_VERSION` (default `50`),
`ENABLE_DX` (default `0`), `BASE_IMAGE`, `COMMON_IMAGE_REF`, `BREW_IMAGE_REF`,
`ENABLE_NVIDIA`, `AKMODS_VERSION` (variant-specific; set in the relevant Justfile `case` arm).

## Containerfile stage pattern

Most variants follow:

```dockerfile
FROM scratch AS ctx
COPY build_files /                       # (or per-subdir for a per-variant build)
COPY system_files/global /system_files/global
COPY system_files/<variant> /system_files/<variant>

FROM <base> AS builder                   # distro-specific compile stage (arch/debian/gentoo/ubuntu/nixos)
...
FROM <base> AS system
COPY --from=builder /output /
RUN --mount=type=bind,from=ctx ... /ctx/<variant>/build-<variant>.sh
LABEL containers.bootc 1
RUN bootc container lint
```

**Keep `RUN bootc container lint`** in any Containerfile that already has it.

## Image Pinning Pattern

Base/distro images are pinned by digest in `FROM` lines (and in `image-versions.yaml`):

```dockerfile
ARG BASE_IMAGE="${BASE_IMAGE:-ghcr.io/projectbluefin/bluefin-lts-nvidia:testing@sha256:<current>}"
FROM ${BASE_IMAGE}
```

**Never update digests manually.** Renovate opens PRs for digest bumps
(custom manager for `image-versions.yaml`; dockerfile manager for Containerfile
`FROM` lines). To change an image or tag, edit its `FROM` line; to bump a base
release, update the matching arg and the digest together.

## Rechunking

- `just rechunk <image> <tag>` — uses `quay.io/coreos/chunkah:latest` (currently
  unpinned; TODO to pin once mature) to split the image for smaller bootc deltas.
- `just ostree-rechunk <image> <tag>` — classical `rpm-ostree compose build-chunked-oci`;
  **requires root** and only applies to rpm-based images.
- Base-image workflows run `just rechunk` after build (except `fsdk`, which skips it).
- `fsdk` is produced by BuildStream and exported as an OCI image; it does not use
  rechunk.

## BuildStream (fsdk)

`buildstream/` is a standalone BuildStream project:

- `just -C buildstream build` composes `oci/fsdk.bst` and exports a `blueprint:fsdk` image.
- `just -C buildstream validate` shows the dependency graph (run before PRs).
- The `bst` wrapper runs on a remote BuildBarn grid by default; `BST_LOCAL=1`
  forces local execution.
- Pinned via `freedesktop-sdk.bst` junction `ref` and `include/slim.yml` (distroless cleanup).

## Common Rationalizations

| Rationalization                                                   | Reality                                                                                             |
| ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| "I'll skip the digest pin and use a floating tag."                | Non-reproducible builds and breaks supply-chain traceability. The `FROM` line should always be pinned. |
| "Renovate won't notice a manually pinned digest in `FROM`."       | Renovate's dockerfile manager tracks `FROM image:tag@sha256:...` automatically.                      |
| "I'll drop `bootc container lint` to speed up the build."         | It catches broken enablement symlinks and image structure regressions. Keep it.                     |
| "fsdk can use `just build fsdk` like the others."                 | No — fsdk is BuildStream; use `just build-fsdk`.                                                     |
| "I'll uncomment `[multilib]` in pacman.conf with a sed pattern match." | Recent `archlinux:latest` base images removed the commented `[multilib]` section (and `#Include = /etc/pacman.conf.d/*.conf`) entirely; the sed is a no-op. Use a check-and-append fallback: `if ! grep -q '^\[multilib]'; then sed -i '/^#\[multilib\]/s/^#//' ...; [ -z "$(grep '^\[multilib]' ...)" ] && echo '[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf; fi`. This pattern is mirrored in `build_files/base/build-arch.sh` and the holo build scripts. |

## Red Flags

- Floating tags (`FROM image:latest` without `@sha256:...`)
- Hand-edited digests in `FROM` lines or `image-versions.yaml` (let Renovate)
- `bootc container lint` removed from a Containerfile that had it
- Variant build script using a package manager that isn't its native one
- `system_files/global` copied after the variant overlay
- A shared `images/*.env` / `dotenv-filename` env file reintroduced (variant identity must stay inline in the `Justfile` `build` recipe `case` arms)
- `just build fsdk` instead of `just build-fsdk`

## Verification

- [ ] Are all `FROM` lines pinned with `@sha256:...` (except editable `ARG` defaults)?
- [ ] Does `just build <variant>` succeed locally?
- [ ] Does `just lint` (shellcheck) and `just check` (justfmt) pass clean?
- [ ] Is `bootc container lint` present where it was before?
- [ ] For fsdk: did `just -C buildstream validate` pass?
- [ ] Is all variant identity inline in the `Justfile` `build` recipe `case` arms (no `images/*.env`)?
