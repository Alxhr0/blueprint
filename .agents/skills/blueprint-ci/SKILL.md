---
name: blueprint-ci
description: >-
  GitHub Actions workflows, Renovate configuration, projectbluefin/actions
  composite actions, the promote/tag-stable digest promotion flow, and cosign
  signing. Use when changing .github/workflows/, renovate.json5, or understanding
  the base-image promotion pipeline.
---

# blueprint CI

## When to Use

- Editing any `.github/workflows/*.yml`
- Editing `renovate.json5`
- Adding a new build or promotion workflow
- Debugging CI failures
- Understanding how base images promote `:testing` → `:stable`

## When NOT to Use

- Containerfile / Justfile / build_files changes — use `blueprint-build`
- Runtime customisations — use `blueprint-custom`

## Core Process

1. **Identify the workflow responsible** for your change (see table below)
2. **Check `projectbluefin/actions`** to confirm a composite action exists and its inputs
3. **Pin any new third-party action** to a commit SHA (Renovate tracks SHAs)
4. **Validate** locally: `actionlint .github/workflows/*.yml` and `python3 -c "import yaml; yaml.safe_load(open('f'))"`
5. **Run `zizmor.yml`** mentally / via the workflow — it scans workflow security

## Workflow Map

| File | Trigger | Purpose |
| --- | --- | --- |
| `build-all.yml` | dispatch | `homepage`, `nixos`, `ubuntu`, `fsdk` (convenience) |
| `build-base-images.yml` | schedule (every 3 days), dispatch | `fsdk` (BuildStream) |
| `build-arch.yml` | schedule (every 2 days), dispatch | `arch-bootc:testing` |
| `build-debian.yml` | schedule (every 2 days), dispatch | `debian-bootc:testing` |
| `build-opensuse.yml` | schedule (every 2 days), dispatch | `opensuse-bootc:testing` |
| `build-nixos.yml` | schedule (every 2 days), dispatch | `nixos-bootc:testing` |
| `build-ubuntu.yml` | schedule (every 2 days), dispatch | `ubuntu-bootc:testing` |
| `build-holo.yml` | schedule (daily), dispatch | `holo-amd`, `holo-nvidia` (FROM `arch-bootc:stable`) |
| `build-disk.yml` | dispatch, PR on disk/iso toml | BIB qcow2 / anaconda-iso via `osbuild/bootc-image-builder-action` |
| `build-homepage.yml` | schedule (weekly), dispatch | external Codeberg Homepage image |
| `promote-arch.yml` | dispatch | skopeo → PR pinning `arch-bootc:testing` digest |
| `promote-debian.yml` | dispatch | skopeo → PR pinning `debian-bootc:testing` digest |
| `promote-opensuse.yml` | dispatch + 2-week cron (`0 4 1,15 * *`) | skopeo → PR pinning `opensuse-bootc:testing` digest |
| `promote-nixos.yml` | dispatch + 2-week cron (`0 4 1,15 * *`) | skopeo → PR pinning `nixos-bootc:testing` digest |
| `promote-ubuntu.yml` | dispatch + 2-week cron (`0 4 1,15 * *`) | skopeo → PR pinning `ubuntu-bootc:testing` digest |
| `tag-arch-stable.yml` | merged PR w/ `promote` label + title match | pull/pin/retag `arch-bootc:stable` + sign |
| `tag-debian-stable.yml` | same, debian | retag `debian-bootc:stable` + sign |
| `tag-opensuse-stable.yml` | same, opensuse | retag `opensuse-bootc:stable` + sign |
| `tag-nixos-stable.yml` | same, nixos | retag `nixos-bootc:stable` + sign |
| `tag-ubuntu-stable.yml` | same, ubuntu | retag `ubuntu-bootc:stable` + sign |
| `zizmor.yml` | PR/push on workflows | workflow supply-chain security scan |

## Base-Image Promotion Flow (digest-pin)

There is **no** `stable` git branch. Promotion is at the registry level:

1. `build-<base>.yml` publishes `<base>-bootc:testing` on a schedule.
2. `promote-<base>.yml` runs `skopeo inspect` to read the `:testing` digest,
   opens branch `promote/<base>-stable-<digest12>`, edits `image-versions.yaml`
   (`<base>-bootc: digest: <digest>`), and opens a PR labeled `promote` against `main`.
3. A human reviews/tests `:testing`, then merges the PR.
4. `tag-<base>-stable.yml` fires on the merged PR, pulls the pinned digest,
   re-tags it `:stable`, pushes, and cosign-signs it.

**Never hand-edit a `:stable` digest** in `image-versions.yaml` — use the promote workflow.
**Always test the `:testing` image before merging the promotion** — `holo-amd`/`holo-nvidia`
build `FROM arch-bootc:stable`, so a broken base breaks every downstream variant.

## Composite Action Pins

Third-party actions are pinned to commit SHAs, e.g.:

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7
- uses: projectbluefin/actions/bootc-build/setup-runner@v1
- uses: projectbluefin/actions/bootc-build/push-image@v1
- uses: osbuild/bootc-image-builder-action@30960621b85c9e76c653082f9ef4cab5a10210d5 # main
```

For `projectbluefin/actions` the workflows currently use the floating `@v1` tag
for `setup-runner`/`push-image`. Renovate does not auto-bump workflow digests
here (see `renovate.json5` `packageRules`), so **bump these deliberately and with
care**, and prefer a SHA pin over a moving tag for security-sensitive steps.

## Cosign Signing

Signing uses a static key from the `SIGNING_SECRET` repo secret:

```yaml
cosign sign -y --new-bundle-format=false --use-signing-config=false \
  --key env://COSIGN_PRIVATE_KEY "${REGISTRY}/${IMAGE_NAME}@${DIGEST}"
```

`--new-bundle-format=false` is required for cosign 3.x compatibility. `cosign.pub`
is the only key material in-tree; `cosign.key` is `.gitignore`-d.

## Renovate (`renovate.json5`)

- Extends `config:best-practices`; `rebaseWhen: never`; daily schedule.
- **Custom manager** for `image-versions.yaml` tracks pinned base digests
  (`images:` block) and bumps them via PR.
- **Automerge** enabled for `pin` / `pinDigest` update types.
- **Disabled** automatic digest bumps inside `.github/workflows/**` (those SHAs
  are bumped deliberately).
- Binary downloads (e.g. `uupd`) are tracked via inline `# renovate: datasource=...`
  comments in `image-versions.yaml` (`downloads:` block).

## Adding a New Tool

Pin to a specific version with a Renovate tracking comment:

```yaml
- name: Install <tool>
  env:
    # renovate: datasource=github-releases depName=owner/repo
    TOOL_VERSION: "1.2.3"
  run: |
    sudo wget -qO /usr/local/bin/<tool> "https://github.com/owner/repo/releases/download/v${TOOL_VERSION}/<tool>-linux-amd64"
```

Never use `/releases/latest/` — non-reproducible.

## Common Rationalizations

| Rationalization                                              | Reality                                                                                  |
| ------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| "I'll use `/releases/latest/` for now and pin it later."     | You won't. Non-reproducible builds silently fail months later. Pin immediately.          |
| "The `@v1` tag for projectbluefin/actions is fine."          | Moving tags are a supply-chain risk; prefer SHA pins, and bump deliberately.             |
| "I'll edit the `:stable` digest directly — faster."          | Use `promote-<base>.yml`. Hand edits bypass review and the tag-stable workflow.          |
| "Renovate will bump these workflow SHAs."                    | It won't here (disabled for workflows). Bump deliberately and validate with actionlint.  |

## Red Flags

- Third-party action used with a floating tag instead of a commit SHA (where security-sensitive)
- A `:stable` digest hand-edited in `image-versions.yaml`
- `promote-<base>.yml` PR merged without testing `:testing` first
- `cosign.key` or `SIGNING_SECRET` value committed
- A new workflow not run through `actionlint` and `zizmor.yml`
- A promote/tag-stable pair whose title/label matching logic drifts

## Verification

- [ ] Every third-party `uses:` is pinned (SHA preferred for sensitive steps)?
- [ ] `actionlint .github/workflows/*.yml` passes clean?
- [ ] YAML validation passes for edited files?
- [ ] `zizmor.yml` ran (or would pass) on the changed workflows?
- [ ] Promote/tag-stable pairs are consistent (skopeo reads `:testing`, tag retags `:stable`)?
- [ ] `cosign.pub` only; no private key material in tree?
