# FSDK Image Build Guide

## Philosophy

This image follows the [freedesktop-sdk containers](https://github.com/projectbluefin/fsdk-containers) philosophy:

- **Distroless by default** — ship only the runtime, strip the bloat
- **Slim recipes** — explicit removal of build tools, locale data, sanitizers, and other non-runtime artifacts
- **Reproducible builds** — pinned FSDK junction refs, deterministic package sets
- **Clear separation** — base runtime, dev tools, and user data are kept separate

The `buildstream/` directory contains the full BuildStream project for proper FSDK-based distroless images. The `Containerfile.fsdk` provides a simpler podman-based path for the full-featured development image.

## Directory Structure

```
buildstream/
├── Containerfile.fsdk          # Podman build entrypoint for the full-featured image
├── GUIDE.md                    # This file
├── Justfile                    # BuildStream-specific just recipes
├── project.conf                # BuildStream project configuration
├── elements/                   # BuildStream elements (BST files)
│   ├── freedesktop-sdk.bst     # FSDK junction ref
│   ├── targets.json            # Canonical manifest of image targets
│   ├── base/                   # Base image composition
│   ├── oci/                    # OCI image definitions
│   ├── lab-runner/             # Shell-enabled CI image
│   └── ...
├── include/                    # Shared YAML includes (slim recipes, versions)
├── build_files/
│   └── fsdk/
│       └── build.sh            # Build script for Containerfile.fsdk
├── system_files/
│   └── fsdk/                   # System configs (copied into the image)
└── images/
    └── fsdk.env                # Image metadata (name, tags, description)
```

## Adding Packages

### To the Containerfile.fsdk (podman build)

Edit `buildstream/build_files/fsdk/build.sh` and add packages to the `PACKAGES` array:

```bash
PACKAGES=(
    # ... existing packages ...
    your-new-package
    another-package
)
```

### To BuildStream elements

For proper FSDK distroless images, edit the relevant `.bst` file under `buildstream/elements/`:

1. **Identify the element** — e.g., `elements/oci/base.bst` for the base image
2. **Add to build-depends** — declare the FSDK component you need:

```yaml
build-depends:
  - freedesktop-sdk.bst:components/your-component.bst
```

3. **Update the slim recipe** — if the component brings in runtime bloat, add removal commands to `buildstream/include/slim.yml` or the element's `config.commands`

4. **Register in targets.json** — add the image name to `oci_images` and define its `image_paths`

## Adding System Files

Place configuration files in `buildstream/system_files/fsdk/`. They will be copied to the root of the image during build:

```
buildstream/system_files/fsdk/
├── etc/
│   └── your-config.conf
└── usr/
    └── bin/
        └── your-script
```

## Building

### Build the full-featured image (Containerfile.fsdk)

```bash
just build-fsdk
```

### Build with BuildStream (distroless)

```bash
cd buildstream
just build
```

### Build all images

```bash
just build-all
```

This builds every variant defined in `images/*.env` plus the fsdk image.

## Image Variants

| Variant | Description |
|---------|-------------|
| `edward` | Ubuntu + GNOME desktop, dev tools, NVIDIA, gaming |
| `aira` | KDE Plasma, AMD-focused |
| `holo-amd` | Arch + CachyOS kernel, AMD GPU, gaming |
| `holo-nvidia` | Arch + CachyOS kernel, NVIDIA GPU, gaming |
| `fsdk` | Full-featured FSDK-inspired dev image (this directory) |
| `ai` | Ubuntu base for AI/ML containers |
| `server` | Minimal server image |
| `gentoo` | Gentoo-based image |
| `opensuse` | openSUSE-based image |
| `debian` | Debian-based image |
| `ubuntu` | Ubuntu base image |

## Adding a New Variant

1. Create `images/<name>.env` with the metadata
2. Create `containerfiles/Containerfile.<name>` or `buildstream/Containerfile.<name>`
3. Create `build_files/<name>/build.sh` or `buildstream/build_files/<name>/build.sh`
4. Add the name to the `list-images` exclusion list in the root `Justfile` if needed
