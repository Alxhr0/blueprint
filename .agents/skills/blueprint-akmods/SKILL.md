---
name: blueprint-akmods
description: >-
  The akmods/ sub-project: a cached kernel-modules image for the
  OpenGamingCollective (OGC) Arch kernel (linux-ogc). Covers how it pulls and
  pins linux-ogc, builds nvidia + zfs modules against it, and publishes a
  scratch cache image downstream bootc images COPY from. Use when changing
  akmods/ (Containerfile, build_files, images.yaml, its workflow) or wiring a
  variant to consume the cache.
---

# blueprint-akmods

## When to Use

- Changing anything under `akmods/` (Containerfile, `build_files/*`, `Justfile`,
  `images.yaml`, `scripts/resolve-kernel.sh`) or its workflow at
  `.github/workflows/build-akmods.yml` (repo root)
- Wiring a downstream image (e.g. holo-nvidia) to consume the akmods cache
- Bumping/pinning the OGC kernel or the zfs release series

## When NOT to Use

- Adding packages to a variant image — see `blueprint-packages`
- The nvidia packages in a *variant build* — the cache has no prebuilt userspace
  drivers, only kernel modules; variant driver/GL install is separate

## Core Process

`akmods/` is a **self-contained** sub-project (not a variant of the root
`Containerfile`). It mirrors `ublue-os/akmods` for one Arch kernel (`ogc`):

1. **Pin the kernel** in `images.yaml` → `ogc.tag` (e.g. `7.2.1-ogc2`, or `latest`
   to track the stream — not a stable pin). The artifact
   `ghcr.io/opengamingcollective/kernel-packages-arch:<tag>` ships
   `linux-ogc*`/`linux-ogc-headers*` `.pkg.tar.zst` layers.
2. **Fetch** with `build_files/prep/fetch-kernel.sh`: `skopeo inspect --raw` +
   `oras blob fetch` to pull the pinned kernel + headers packages (mirrors
   ublue's ogc branch, adapted from RPMs to `*.pkg.tar.zst`).
3. **Install + prep** (`build_files/prep/build-prep.sh`): `pacman -U` the pinned
   kernel + headers, install build deps (base-devel, dkms, zfs build deps).
4. **Build modules** against the exact pinned headers:
   - `build_files/nvidia/build-kmod-nvidia.sh`: official `nvidia-open-dkms`
     (Extra repo), verified with `dkms autoinstall -k <kver>`.
   - `build_files/zfs/build-kmod-zfs.sh`: build **OpenZFS from the upstream
     source tarball** (zfs is NOT in official Arch — CDDL/GPL; not AUR either).
5. **Assemble** (`build_files/post/build-post.sh`): copy the pinned kernel
   packages + built `.ko` modules into `$CACHE_ROOT` (default
   `/var/cache/rpms`).
6. **Publish**: the scratch `cache` stage exports `/var/cache/rpms`; the
   `build-akmods.yml` workflow pushes `ghcr.io/huntedraven7/akmods:<tag>` and
   cosigns.

Consumers `COPY --from=<akmods image> /var/cache/rpms /` and install/merge the
kernel packages + modules for the pinned kernel.

## Why kernel pinning

- `nvidia-open` (stock prebuilt) only matches stock Arch `linux`; a custom
  kernel needs `nvidia-open-dkms` compiled against installed headers.
- zfs is compiled against the kernel's exact headers and only supported across
  specific kernel versions. Pinning `linux-ogc` guarantees nvidia + zfs always
  match the exact kernel available to downstream.

## Where the kernel version comes from

`scripts/resolve-kernel.sh <ogc-image>` prints the exact kernel version (e.g.
`7.2.1.ogc2-1-x86_64`) from the artifact manifest; CI uses it for tags/labels,
the build scripts read it from `$KERNEL_CACHE/kernel-version`.

## Common Rationalizations

| Rationalization                                                     | Reality                                                                                       |
| ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| "Install zfs from a pacman repo."                                   | zfs is not in official Arch (CDDL vs GPL) and we avoid AUR → build from the openzfs source.    |
| "Use prebuilt nvidia-open for the OGC kernel."                      | Prebuilt `nvidia-open` only matches stock `linux`; use `nvidia-open-dkms` for custom kernels. |
| "akmods is a blueprint variant, add a case arm."                    | No — it is its own scratch cache image, not a `blueprint` variant.                            |

## Red Flags

- `images.yaml` `ogc.tag` left on `latest` for long — treat it as a pin you make
  explicit once downstream images depend on it.
- Editing `image-versions.yaml` for the akmods kernel — the pin lives in
  `akmods/images.yaml`, not the root file.

## Verification

- [ ] `just --unstable --fmt --check -f akmods/Justfile` passes
- [ ] `shellcheck` + `shfmt -d` clean on every `akmods/**/*.sh`
- [ ] `python3 -c "import yaml; yaml.safe_load(open('<file>'))"` on YAML
- [ ] `actionlint .github/workflows/build-akmods.yml`
