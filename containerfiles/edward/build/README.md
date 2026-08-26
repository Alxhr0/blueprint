# Build Scripts

Build scripts for the `edward` image (bluefin-lts-nvidia base — CentOS Stream 10
bootc + GNOME + NVIDIA). This is the per-variant directory for edward; sibling
variants live in `build/aira/` and `build/server/`.

## Layout

```
build/edward/
├── 10-build.sh          # EPEL+terra repos, base tooling, COPR (quickshell+niri), overlays, services
└── clean-stage.sh       # cleanup, always runs last
```

## Containerfile Chain

`custom/edward/container/Containerfile.edward` runs them explicitly:

```dockerfile
RUN ... /ctx/build/10-build.sh
RUN ... /ctx/build/clean-stage.sh
```

## Base Image

The base is `ghcr.io/projectbluefin/bluefin-lts-nvidia:testing` — CentOS Stream
10 bootc with GNOME/GDM, NVIDIA driver (matched kernel + kmod pair) and ublue
batteries. The base ships its own kernel with paired nvidia modules, so no
separate akmods stage, kernel swap, or nvidia build script is needed.

## Package Manager

The base is CentOS Stream 10 (c10s). It ships **dnf 4** (no dnf5), so all
package operations use plain `dnf`, same as upstream bluefin-lts scripts:

```bash
dnf -y install package-name
```

- `10-build.sh` pre-filters packages against `rpm -q` so already-shipped
  packages are skipped, keeping the transaction small.
- Wired-in repos: EPEL (`epel-release-latest-$releasever`) and terra EL
  (`terrael$releasever` via `terra-release`, stays enabled).
- COPR repos (quickshell, niri) are enabled, used, and disabled within the
  build so they do not persist in the final image.
- GNOME/GDM, codecs and the full ujust recipe set come FROM the base — there is
  no `common` OCI stage in edward's Containerfile because the base already ships
  common's shared/bluefin files.
- The Containerfile breaks the ostree hardlink on `/etc/dnf/dnf.conf` before
  sed-ing in build-time options.

## Build Script Numbering

| Prefix             | Purpose                                                        |
| ------------------ | -------------------------------------------------------------- |
| `10-build.sh`      | Main script: repos, packages, overlays, system configuration    |
| `clean-stage.sh`   | Always runs last: clears caches and artefacts                   |

## Adding Scripts

Add numbered scripts to this directory and an explicit `RUN` block to the
Containerfile:

```bash
# 20-development.sh - dev tools
# 30-gaming.sh      - gaming software
```

### Best Practices

- **Use descriptive names**: `30-gaming.sh` is better than `30-stuff.sh`
- **One purpose per script**: Easier to debug and maintain
- **Clean up after yourself**: Remove temporary files
- **Test incrementally**: Add one script at a time and test builds
