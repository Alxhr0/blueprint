---
name: blueprint-troubleshooting
description: >-
  Consolidated symptom-cause-fix table for blueprint. Covers local podman
  builds, bootc-image-builder (BIB) disk/ISO, CI failures, rechunk/chunkah,
  cosign issues, and Renovate problems. Use when something is broken and you
  need a quick diagnosis.
---

# blueprint Troubleshooting

## When to Use

- A local build fails and you need to diagnose the cause
- CI is failing on a PR and the error is unclear
- A BIB disk/ISO build fails
- Rechunk/chunkah or cosign signing fails
- Renovate is not creating or is failing PRs

## When NOT to Use

- You are still setting up a new variant — use `blueprint-onboarding`
- You are deciding where to add a package — use `blueprint-packages`
- You need to plan ongoing maintenance — use `blueprint-maintain`

## Core Process

1. **Identify the symptom** from the tables below
2. **Check the likely cause**
3. **Apply the solution**
4. **Verify the fix**

## Local Build Failures

| Symptom | Cause | Solution |
| --- | --- | --- |
| `just build` fails: "IMAGE_NAME empty" / env errors | the `Justfile` `build` recipe `case` block (the source of all variant identity) is missing/renamed or its `case` arms were edited incorrectly — identity is inline there, not in a shared env file | Restore the inline identity in the `Justfile` `build` recipe `case` arms |
| Build fails: "permission denied" writing `/sysroot` | BIB / rootless podman issue | BIB needs rootful podman; use `just sudoif` or run as root for disk builds |
| Build fails: "package not found" | Typo or wrong manager for the variant | Use the variant's native manager (`pacman`/`dnf5`/`apt`/`zypper`/`emerge`/`nix-env`) |
| Build fails: "base image not found" | Invalid `FROM` line or stale digest | Verify the `FROM` line; `podman pull` the base; let Renovate bump digests |
| `bootc container lint` fails | Dangling systemd enablement symlink, or invalid image structure | Check `/etc/systemd/system` symlinks (arch enforces this); fix the unit or enablement |
| `just` errors: "yq not installed" | `yq` missing | Install yq (brew: `brew install yq`) — required by the `build` recipe |
| Build diff from CI | Local cached layers / different podman version | Start from a clean `just build` on the same commit CI used |

## BIB / Disk / ISO Failures

| Symptom | Cause | Solution |
| --- | --- | --- |
| `just build-iso` / `build-disk.yml` fails: `disk_config/iso.toml` not found | That file **does not exist**; the recipe references it | Use explicit tomls: `just build-iso-gnome` (`iso-gnome.toml`), `just build-server-iso` (`iso-server.toml`), or `just build-installer-iso` (ncurses) |
| BIB fails: "image not found" | The `:latest`/`DEFAULT_TAG` ref isn't published yet | Build & push the container image first (`just build <variant>`), then disk |
| BIB needs root / privileged | BIB runs rootful podman with `--privileged` | Run disk builds as root or via `just sudoif` |
| `run-vm-*` fails: no KVM | Nested virt / `/dev/kvm` missing | Ensure KVM available; the recipe binds `--device=/dev/kvm` |
| Installer ISO build fails | Missing `lorax`/`livemedia-creator`/`xorriso` (root required) | Run `just build-installer-iso` as root; deps install automatically |

## CI Failures

| Symptom | Cause | Solution |
| --- | --- | --- |
| `just check` fails in CI | Unformatted `*.just` or `Justfile` | Run `just fix` locally (justfmt) before pushing |
| shellcheck fails | Syntax error in `build_files/*.sh` | Run `just lint` locally, fix errors |
| `actionlint` fails | YAML issue in a workflow | Run `actionlint .github/workflows/*.yml`; fix schema/indent |
| `zizmor.yml` flags a workflow | Supply-chain issue (unpinned action, secret exposure) | Pin third-party actions to SHAs; avoid echoing secrets |
| Build fails: permission/secret | Missing `SIGNING_SECRET` or wrong permissions | Ensure the repo secret exists; workflow needs `id-token: write`, `packages: write` |
| Push fails: 401/403 | Not on `main` / PR context | Push workflows only run on default branch + non-PR events |
| Digest mismatch between promote and tag | `image-versions.yaml` edited by hand | Revert hand edit; let `promote-<base>.yml` own the `:stable` digest |

## Rechunk / Chunkah Failures

| Symptom | Cause | Solution |
| --- | --- | --- |
| `just rechunk` pulls `chunkah:latest` (unpinned) | Intended TODO; image not yet pinned | Acceptable for now; pin once mature. Don't pin blindly. |
| `just ostree-rechunk` fails: "needs root" | rpm-ostree rechunk requires root | Run as root; only valid for rpm-based images |
| Rechunk OOM on CI | Full image copy; limited runner space | Expected on small runners; chunkah notes this in-repo |

## Cosign / Signing Failures

| Symptom | Cause | Solution |
| --- | --- | --- |
| `cosign sign` fails: key error | `SIGNING_SECRET` missing or malformed | Ensure repo secret set; must be the private key matching `cosign.pub` |
| Sign step fails on cosign 3.x | New bundle format incompatible | Keep `--new-bundle-format=false --use-signing-config=false` |
| Verify fails | Wrong identity / key | Verify with `cosign.pub`; signing uses static key, not keyless OIDC |

## Renovate Issues

| Symptom | Cause | Solution |
| --- | --- | --- |
| Renovate not creating PRs | Custom manager regex mismatch, or digest bumps disabled for workflows | Validate `renovate.json5`; remember workflow SHAs are deliberately excluded |
| Renovate updates wrong files | Misconfigured custom manager matchStrings | `renovate-config-validator` isn't wired; sanity-check the regex manually |
| Digest PR changes the wrong image | `matchStrings` too loose | Tighten the `image-versions.yaml` custom manager pattern |

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "The build failed in CI but works locally — it must be a CI bug." | CI is the source of truth. Local caches differ. Start from a clean `just build`. |
| "I'll just use `just build-iso` like the others." | It references a missing `disk_config/iso.toml`. Use the explicit variant tomls. |
| "Renovate is broken — no PRs in days." | Workflow SHAs are excluded from automerge; digest PRs only for `image-versions.yaml`. Check the config. |
| "I'll hand-edit the `:stable` digest to fix promotion." | Use `promote-<base>.yml`. Hand edits break the tag-stable contract. |

## Red Flags

- `disk_config/iso.toml` referenced but missing
- A shared `images/*.env` / `dotenv-filename` env file reintroduced (variant identity must stay inline in the `Justfile` `build` recipe `case` arms)
- A `:stable` digest hand-edited in `image-versions.yaml`
- Unpinned (or wrongly pinned) cosign bundle format
- Skipping local `just build` before opening a PR

## Verification

- [ ] Did you identify the correct category (local, BIB, CI, rechunk, cosign, Renovate)?
- [ ] Did you check the symptom-cause table for your specific error?
- [ ] Did you apply the recommended solution?
- [ ] Did you verify the fix by running the relevant test (`just build`, `just check`, `just lint`, `actionlint`)?
- [ ] If a base promotion is involved, was `:testing` tested before merging?
