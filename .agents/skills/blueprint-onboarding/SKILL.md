---
name: blueprint-onboarding
description: >-
  How to add a new image variant to the blueprint personal bootc builder. Use
  when introducing a new image flavor: a "unified" variant built from the root
  Containerfile (inline case arm in the Justfile + workflow, no per-variant
  Containerfile or env file).
---

# blueprint Onboarding — Adding a New Variant

This is **not** a fork-the-template repo; `blueprint` is one repository that
builds many images. "Onboarding" here means **adding a new image variant** to
the existing builder, not bootstrapping a new repo.

## When to Use

- Adding a brand-new image variant (e.g. a new desktop or device image)
- Promoting a `.example` or scratch build into a first-class variant
- Promoting a `.example` or scratch build into a first-class variant

## When NOT to Use

- The repository already has the variant and you're just adding packages — use `blueprint-packages` / `blueprint-build`
- Updating CI workflows generally — use `blueprint-ci`

## Core Process

There is **one** primary way to add a variant (Path A, the unified root
`Containerfile`).

### Path A — "unified" variant (root `Containerfile`)

Use this for variants that fit the generic `ctx → builder(RUN $BUILDER_SCRIPT) →
system(RUN $BUILD_SCRIPT)` flow of the root `Containerfile` (e.g. distro base
images and derived images: `arch`/`debian`/`opensuse`/`gentoo`/`nixos`/`ubuntu`/
`holo-amd`/`holo-nvidia`). A unified variant is a **two-part** set:

1. **An inline `case` arm in the `Justfile` `build` recipe** — hardcode the
   identity (IMAGE_NAME, DEFAULT_TAG, description, BIB_IMAGE) and set the
   `BASE_IMAGE` / `BUILDER_SCRIPT` / `BUILD_SCRIPT` used by the root
   `Containerfile` (nixos additionally sets `LINT=0`). There is **no**
   `images/<variant>.env` and **no** `containerfiles/Containerfile.<variant>` —
   the `build` recipe sets `CONTAINERFILE="Containerfile"` and passes
   `--build-arg VARIANT=<name> --build-arg BASE_IMAGE=<base> --build-arg BUILDER_SCRIPT=<script> --build-arg BUILD_SCRIPT=<script>`.
2. **A build workflow** (or add the variant to an existing matrix) under
   `.github/workflows/`. Mirror `build-arch.yml` / `build-holo.yml` for the
   build→rechunk→tag→push→sign steps. Use `projectbluefin/actions/bootc-build/*`
   composite actions where possible. For promoted base images (`arch`/`debian`/
   `opensuse`), also add `promote-<base>.yml` + `tag-<base>-stable.yml`.

### Why the parts matter

`just build <variant>` resolves metadata from the Justfile `build` recipe `case`
arm (inline identity, no env file). A variant with no workflow never
publishes. Keep each variant's identity unique — its `DEFAULT_TAG` must not
collide with any other Justfile `case` arm or `buildstream/images/fsdk.env`.

## Standard additions checklist

### Unified variant (Path A — root Containerfile)

- [ ] An inline `case` arm exists in the `Justfile` `build` recipe (IMAGE_NAME, DEFAULT_TAG, description, BIB_IMAGE, BASE_IMAGE/BUILDER_SCRIPT/BUILD_SCRIPT)
- [ ] `DEFAULT_TAG` does not collide with any other variant (shared `blueprint` repo)
- [ ] A build workflow exists (or the variant is added to an existing matrix); promoted bases also have `promote-<base>.yml` + `tag-<base>-stable.yml`
- [ ] Build script exists under `build_files/base/` (`builder-<variant>.sh` / `build-<variant>.sh`)
- [ ] `bootc container lint` present (LINT arg) if other variants of that base have it

## Adding a variant that consumes a promoted base

`holo-amd` / `holo-nvidia` build `FROM arch-bootc:stable`. If your new variant
depends on a base image, build `FROM <base>-bootc:stable` and ensure that base
is promoted (`:stable` digest in `image-versions.yaml`) before relying on it.

## Common Rationalizations

| Rationalization                                                 | Reality                                                                                     |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| "I'll add a per-variant `Containerfile` + `.env`."               | This repo has no per-variant `Containerfile` or `images/*.env`; all identity lives inline in the `Justfile` `case` arm (Path A). |
| "I'll reuse the primary `DEFAULT_TAG` for my new variant too."  | All `blueprint` variants share one registry repo; a duplicate tag overwrites another image. |
| "I'll add the Containerfile later, the env is enough."          | `just build` resolves the Containerfile path from the variant name; a missing file fails.   |
| "A workflow isn't needed — I'll build locally."                 | Nothing publishes to GHCR without a workflow; CI is the source of truth.                     |

## Red Flags

- New per-variant `Containerfile.<variant>` with no matching identity (inherits the primary/default identity) — unified variants correctly have neither
- A `DEFAULT_TAG` repeated across two variants (shared `blueprint` repo)
- New variant references a base `:stable` that hasn't been promoted
- Build script under `build_files/` but not invoked by the Containerfile `RUN` (unified: the root `Containerfile` `RUN`s `$BUILDER_SCRIPT`/`$BUILD_SCRIPT`)

## Verification

- [ ] For a unified variant: the Justfile `case` arm exists (no per-variant Containerfile or env needed)
- [ ] `just check` and `just lint` pass?
- [ ] `DEFAULT_TAG` is unique across the Justfile `case` arms and `buildstream/images/fsdk.env`?
- [ ] A workflow builds and would publish under the intended tag?
- [ ] Does the new variant use the correct native package manager for its base?
