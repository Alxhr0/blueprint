---
name: blueprint-examples
description: >-
  Index of runnable build patterns and activation guidance for blueprint. Covers
  how build scripts are wired into Containerfiles, the per-variant
  build_files layout, and the distro-builder stage pattern. Use when adding new
  build steps or explaining the activation pattern to contributors.
---

# blueprint Example Patterns

## When to Use

- You need to add a build step to a variant
- You want to understand how `build_files/*.sh` are wired into a `Containerfile`
- You are creating a new per-variant build script and want a starting point
- You need to document a new pattern for contributors

## When NOT to Use

- You are modifying existing active `.sh` scripts directly — edit them, don't re-activate
- You are adding a simple package — put it in the variant's build script, no example needed

## Core Process

1. **Find the variant's build script** under `build_files/<variant>/build-<variant>.sh`
2. **Add your logic** there (or create the script + Containerfile `RUN` if new)
3. **Use the variant's native package manager** (see `blueprint-packages`)
4. **Validate** with `just lint` and `just build <variant>`
5. **Commit** (via PR to `main`)

## The activation pattern

Unlike templates with `.example` → `.sh` renames, blueprint wires build scripts
directly into each `Containerfile` via a `RUN --mount=type=bind,from=ctx ...`
block. There is no auto-discovery of numbered scripts — the `Containerfile`
explicitly calls the script path.

Common shape (unified / root `Containerfile` variants):

```dockerfile
FROM scratch AS ctx
COPY build_files /

FROM <base>
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/<variant>/build-<variant>.sh
```

All variants build from this unified root `Containerfile`.

## Distro builder stage pattern (arch/debian/gentoo/ubuntu/nixos — unified root Containerfile)

These use a two-stage build in the **root `Containerfile`**: a `builder` stage
compiles tooling against the base, copies output to `/output`, then a `system`
stage `COPY --from=builder /output /` and runs the install script via the
`BUILDER_SCRIPT`/`BUILD_SCRIPT` build args. Example (the root `Containerfile`,
selected with `VARIANT=arch`):

```dockerfile
FROM ${BASE_IMAGE} AS builder
RUN pacman -Syu --noconfirm base-devel git rust cargo ...
RUN --mount=type=bind,from=ctx,source=/,target=/ctx /ctx/base/${BUILDER_SCRIPT}

FROM ${BASE_IMAGE} AS system
COPY --from=builder /output /
RUN --mount=type=bind,from=ctx,source=/,target=/ctx /ctx/base/${BUILD_SCRIPT}
RUN if [ "${LINT}" != "0" ]; then bootc container lint; fi
```

`build_files/base/` holds the shared `builder-*` (compile) and `build-*` (install)
scripts per distro; `build_files/core/` holds shared helpers (`arch-cachy.sh`,
`enable-user-services.sh`).

## Existing build scripts (reference)

| Script | What it does |
| --- | --- |
| `build_files/holo/build-amd.sh` | pacman install Plasma + CachyOS kernel, gaming stack |
| `build_files/base/build-opensuse.sh` | zypper install kernel/ostree/podman, enable networkd/resolved/sshd |
| `build_files/base/build-gentoo.sh` / `builder-gentoo.sh` | emerge ostree/openssh toolchain |
| `build_files/base/build-ubuntu.sh` / `builder-ubuntu.sh` | apt-based build of ubuntu bootc |

## Creating a New Build Script

1. **Name it** `build_files/<variant>/build-<variant>.sh` (or a focused helper).
2. **Shebang + strict mode**: `#!/usr/bin/env bash` and `set -euo pipefail` (some scripts use `set -eo pipefail`).
3. **Copy overlays** in the right order: `system_files/global` first, then `system_files/<variant>`.
4. **Use the native manager** with a non-interactive flag.
5. **Enable services** with `systemctl enable` where needed.
6. **End with cleanup + `bootc container lint`** matching the upstream pattern.
7. **Wire it** by adding/updating the `RUN` block in the unified root `Containerfile` that invokes your script (a `case` arm in the `Justfile` `build` recipe sets `BUILDER_SCRIPT`/`BUILD_SCRIPT` and points at `build_files/base/`); there is no separate per-variant `Containerfile`.
8. **Validate**: `just lint` and `just build <variant>`.

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "I'll just inline my commands in the Containerfile RUN." | Keep build logic in `build_files/*.sh` so it's testable with `shellcheck` and reusable across stages. |
| "I'll add my script but not call it from the Containerfile." | The Containerfile must explicitly `RUN` the script; there is no auto-discovery. |
| "I'll copy the variant overlay before `global`." | `global` must be copied first so the variant overlay wins on conflict. |

## Red Flags

- A `build_files/*.sh` not invoked by any `Containerfile` `RUN`
- Script without `set -euo pipefail` / proper shebang
- Variant overlay copied before `system_files/global`
- Build script using a package manager that isn't the variant's native one
- Missing shellcheck validation before committing

## Verification

- [ ] Does the `Containerfile` `RUN` explicitly invoke your script?
- [ ] Did you copy `system_files/global` before the variant overlay?
- [ ] Does `just lint` pass on the new/changed script?
- [ ] Did `just build <variant>` succeed?
- [ ] For distro builds: are `builder` and `system` stages both present where needed?
