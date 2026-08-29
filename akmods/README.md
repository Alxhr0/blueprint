# akmods — cached kernel modules for the OGC Arch kernel

A personal, Arch-native mirror of [ublue-os/akmods](https://github.com/ublue-os/akmods)
for the [OpenGamingCollective](https://github.com/OpenGamingCollective) Arch
kernel (`linux-ogc`).

Instead of compiling nvidia/zfs modules on every machine, this builds them once
against a **pinned** `linux-ogc` release and publishes a small scratch cache
image carrying:

- the pinned `linux-ogc` + `linux-ogc-headers` packages, and
- the `nvidia` (`nvidia-open`) and `zfs` kernel modules built against **that
  exact kernel**.

Downstream bootc images `COPY --from=ghcr.io/huntedraven7/akmods:ogc-x86_64 /var/cache/rpms /` (or mount the cache) so nvidia/zfs always match the kernel with no per-machine rebuild.

## Why kernel pinning (and why zfs)

- `nvidia-open` (stock prebuilt) only matches the stock Arch `linux` kernel, so
  a custom kernel needs `nvidia-open-dkms` (official Extra repo) compiled
  against the installed headers.
- `zfs` is **not** in the official Arch repos (CDDL vs GPL licensing). It is
  built here from the upstream OpenZFS source release, which is only supported
  against specific kernel versions — hence the pinned kernel guarantees the
  zfs module is built for (and stays matched to) the exact `linux-ogc` you run.

## Layout

```
Containerfile          multi-stage: prep → nvidia → zfs → post → scratch cache
Justfile               local build / push
images.yaml            pinned OGC kernel artifact + module targets + zfs pin
build_files/
  prep/fetch-kernel.sh     oras-pull the pinned linux-ogc packages
  prep/build-prep.sh       install kernel + build env (dkms, compilers)
  nvidia/build-kmod-nvidia.sh  nvidia-open-dkms against pinned kernel
  zfs/build-kmod-zfs.sh        OpenZFS source build against pinned kernel
  post/build-post.sh          assemble kernel pkgs + modules into the cache
../.github/workflows/build-akmods.yml   schedule + dispatch + push + cosign (repo root; GitHub only runs root workflows)
```

## Bumping the kernel

Edit `akmods/images.yaml` → `ogc.tag` to a concrete OGC release (e.g.
`7.2.1-ogc2`) or leave `latest` to track the upstream stream (not a stable
pin). Rebuilds re-resolve the version and relabel tags.

## Local build

```
just -f akmods/Justfile build
```
