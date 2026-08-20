---
name: blueprint-templates
description: >-
  Defining a variant's image identity (IMAGE_NAME/DEFAULT_TAG inline in the
  Justfile `build` recipe `case` arm) and AGENTS.md update rules. Use when adding or
  renaming a variant, defining unified-variant or base-image metadata in the
  Justfile, or updating AGENTS.md and setup docs.
---

# blueprint Templates & Variant Identity

## When to Use

- Defining a new variant's identity inline in the `Justfile` `build` recipe `case` arm
- Adding an inline `case` arm for a new base image in the `Justfile`
- Updating `AGENTS.md` or these agent instructions
- Documenting a new mandatory setup step

## When NOT to Use

- First-time variant bootstrap procedure — use `blueprint-onboarding`
- Build-system changes — use `blueprint-build`
- CI workflow changes — use `blueprint-ci`

## Core Process

1. **Define the identity** in an inline `case` arm in the `Justfile` `build` recipe (a unified variant: `arch`/`debian`/`opensuse`/`gentoo`/`nixos`/`ubuntu`/`holo-amd`/`holo-nvidia`, built from the root `Containerfile`).
2. **A unified variant has no per-variant `Containerfile` and no env** — the `build` recipe selects the root `Containerfile` via `VARIANT`/`BASE_IMAGE`/`BUILDER_SCRIPT`/`BUILD_SCRIPT` build args.
3. **Ensure `DEFAULT_TAG` is unique** across all variants
4. **Update AGENTS.md** per the rules below
5. **Verify** against the checklist at the end of this skill

## Variant identity lives inline in the Justfile (no per-variant env)

This repo has **no** per-variant `images/*.env` files — every variant's identity
(IMAGE_NAME, DEFAULT_TAG, description, BIB_IMAGE, BASE_IMAGE/BUILDER_SCRIPT/BUILD_SCRIPT)
is hardcoded in the `Justfile` `build` recipe `case` block. There is no shared
primary `dotenv-filename` env file anymore; all identity lives inline in the
`Justfile`.

### Critical: `DEFAULT_TAG` uniqueness

All `blueprint` variants publish into **one** registry repository
(`ghcr.io/huntedraven7/blueprint`). `DEFAULT_TAG` is the tag. Two variants with
the same `DEFAULT_TAG` will overwrite each other. Keep one tag per variant.

### `IMAGE_NAME` is shared

The **unified** variants (`arch`/`debian`/`opensuse`/`gentoo`/`nixos`/`ubuntu`/`holo-amd`/`holo-nvidia`)
and base images (`arch-bootc`, `debian-bootc`, `opensuse-bootc`) do NOT have an
`images/*.env`; their identity is hardcoded in the `Justfile` `build` recipe
`case` block. `arch`/`debian`/`opensuse` are promoted bases (own registry
repository); `gentoo`/`nixos`/`ubuntu`/`holo-amd`/`holo-nvidia` publish as
`blueprint:<tag>` and are not promoted (gentoo is local-build-only — see
`docs/GENTOO.md`). The shared `blueprint` repo means `DEFAULT_TAG` must stay unique.

## Unified / base-image identity (inline in the Justfile `build` recipe)

The "unified" variants and base images are resolved in the `build` recipe's `case`:

```bash
arch*)
  IMAGE_NAME="arch-bootc"
  DEFAULT_TAG="testing"
  IMAGE_DESC="Arch Linux Bootc Image"
  IMAGE_KEYWORDS="bootc,oci,linux,arch"
  IMAGE_LOGO_URL="https://avatars.githubusercontent.com/u/120078124?s=200&v=4"
  REPO_ORGANIZATION="huntedraven7"
  BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"
  ;;
```

`arch`/`debian`/`opensuse` (promoted bases) plus `gentoo`/`nixos`/`ubuntu`/
`holo-amd`/`holo-nvidia` all use a `case` arm here — there is **no**
`images/<variant>.env` and **no** `containerfiles/Containerfile.<variant>` for
these; the `build` recipe sets `CONTAINERFILE="Containerfile"` and passes
`--build-arg VARIANT=<name> --build-arg BASE_IMAGE=<base> --build-arg BUILDER_SCRIPT=<script> --build-arg BUILD_SCRIPT=<script>`
(nixos also sets `LINT=0`). To add a new unified variant or base, add a `case`
arm (with a glob like `mybase*`) here.

## Signing

Images are signed with **cosign** using a static key. The private key is the
`SIGNING_SECRET` repository secret; the public key is `cosign.pub` in-tree.
Signing uses the older bundle format (`--new-bundle-format=false`) for cosign
3.x compatibility. **Never commit `cosign.key`** (it is `.gitignore`-d) and
**never** put a `SIGNING_SECRET` value in the repo.

## AGENTS.md Update Rules

`AGENTS.md` is the agent instructions file. When updating it:

- **Line-number references are fragile** — use semantic references (`IMAGE_NAME`, `FROM`) not line numbers
- **Keep the `## Start here` section pointing at the skills and the router** — this is the established pattern
- **Update `Last Updated` date** on every substantive change
- **Do not add resolved items** (PR numbers, "✅ done" entries) — those belong in git history
- **Reflect blueprint reality**: `main`-only branch, digest-pin promotion, personal-repo ownership

## Common Rationalizations

| Rationalization                                                  | Reality                                                                                         |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| "I'll reuse the primary `DEFAULT_TAG` for my new variant."            | Shared registry repo → silent overwrite of another image. Keep one tag per variant.             |
| "Unified variants need an env file too."                         | No — unified/base identity is hardcoded in the `Justfile` `case` block. Adding one confuses `just build`. |
| "I'll update AGENTS.md later once the build is working."         | AGENTS.md drives agent behaviour on every subsequent session. Update it with the change.        |

## Red Flags

- A `DEFAULT_TAG` repeated across two Justfile `case` arms, `images/*.env` files, or `fsdk.env`
- A unified variant (`arch`/`debian`/`opensuse`/`gentoo`/`nixos`/`ubuntu`/`holo-amd`/`holo-nvidia`) given an `images/<variant>.env` it shouldn't have
- `cosign.key` or a `SIGNING_SECRET` value committed to the repo
- AGENTS.md referencing line numbers instead of semantic identifiers
- `## Start here` section removed or not routing tasks to Agent Skills

## Verification

- [ ] `DEFAULT_TAG` unique across the Justfile `case` arms and `buildstream/images/fsdk.env`?
- [ ] Unified variant has its identity in the Justfile `case` (no per-variant env/Containerfile)?
- [ ] Unified/base identity (if applicable) lives in the `Justfile` `case`, not an env file?
- [ ] `cosign.pub` only — no private key material in tree?
- [ ] `AGENTS.md` uses semantic references and has a current `Last Updated` date?
