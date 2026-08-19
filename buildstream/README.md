# FSDK BuildStream Project

This directory is a [BuildStream](https://buildstream.build/) project that follows the [projectbluefin/fsdk-containers](https://github.com/projectbluefin/fsdk-containers) philosophy:

- **Distroless by default** — ship only the runtime, strip the bloat
- **Slim recipes** — explicit removal of build tools, locale data, sanitizers, and other non-runtime artifacts
- **Reproducible builds** — pinned FSDK junction refs, deterministic package sets
- **Unified image** — base + Python + Skopeo + Buildah + OSTree in one container

## Directory Structure

```
buildstream/
├── README.md                   # This file
├── Justfile                    # BuildStream-specific just recipes
├── project.conf                # BuildStream project configuration
├── elements/                   # BuildStream elements (BST files)
│   ├── freedesktop-sdk.bst     # FSDK junction ref
│   ├── targets.json            # Canonical manifest of image targets
│   ├── base/                   # Base image composition
│   │   ├── base-init-script.bst
│   │   ├── base-runtime.bst
│   │   └── base-stack.bst
│   ├── fsdk/                   # Unified FSDK image
│   │   ├── fsdk-stack.bst      # Stack: base + python + skopeo + buildah + ostree
│   │   └── fsdk-runtime.bst    # Runtime: chiseled to runtime-only
│   ├── oci/
│   │   └── fsdk.bst            # OCI image definition
│   └── plugins/                # BuildStream plugins
├── include/                    # Shared YAML includes (slim recipes, versions)
│   ├── aliases.yml
│   └── slim.yml
├── system_files/
│   ├── global/                 # Global system files (brew, presets)
│   └── fsdk/                   # fsdk-specific system configs
└── images/
    └── fsdk.env                # Image metadata (name, tags, description)
```

## How It Works

The fsdk image is composed from raw FSDK components, then chiseled with a BuildStream `compose` element that drops every non-runtime split-rule domain, and finally run through the **SLIM recipe** that removes large runtime-domain bloat.

Pipeline: `stack` (deps) -> `compose` (chisel) -> `script` (slim + oci-builder).

## Building

### Build with BuildStream (distroless, recommended)

```bash
cd buildstream
just build
```

### Build all images (from repo root)

```bash
just build-all
```

This builds every variant defined in `images/*.env` plus the fsdk image via BuildStream.

## Adding Packages

### To BuildStream elements

1. Edit `buildstream/elements/fsdk/fsdk-stack.bst` and add the FSDK component to `depends:`
2. Update the slim recipe in `buildstream/include/slim.yml` if the component brings runtime bloat
3. Update `buildstream/elements/targets.json` if adding a new image

## Image Variants

| Variant | Description |
|---------|-------------|
| `fsdk` | Unified FSDK dev image: Python + Skopeo + Buildah + OSTree, distroless |
| `edward` | CentOS Stream 10 + KDE Plasma desktop, NVIDIA (akmods), dev tools, Homebrew |
| `aira` | KDE Plasma, AMD-focused |
| `holo-amd` | Arch + CachyOS kernel, AMD GPU, gaming |
| `holo-nvidia` | Arch + CachyOS kernel, NVIDIA GPU, gaming |
| `ai` | Ubuntu base for AI/ML containers |
| `server` | Minimal server image |
| `gentoo` | Gentoo-based image |
| `opensuse` | openSUSE-based image |
| `debian` | Debian-based image |
| `ubuntu` | Ubuntu base image |
