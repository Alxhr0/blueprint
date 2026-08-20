---
name: blueprint-maintain
description: >-
  Maintenance of the active blueprint repo: Renovate digest/action PRs, adding
  base-image workflows (arch/debian/opensuse pattern), local test loops, and
  rechunk cadence. Use when maintaining the builder after onboarding a variant.
---

# blueprint Maintenance

## When to Use

- Reviewing and merging Renovate PRs (digest bumps, action pins, downloads)
- Adding a new base-image build + promote + tag-stable workflow set
- Running local test builds before pushing changes
- Planning an ongoing maintenance schedule

## When NOT to Use

- First-time variant setup — use `blueprint-onboarding`
- Adding new packages for the first time — use `blueprint-packages`
- Debugging a specific build failure — use `blueprint-troubleshooting`

## Core Process

1. **Review incoming Renovate PRs** — merge if CI passes
2. **Run local test loop** before opening PRs
3. **Open PRs to `main`** — never push directly
4. **For new base images**, replicate the arch/debian/opensuse workflow trio
5. **Keep `image-versions.yaml` honest** — only the promote workflows edit `:stable` digests

## Handle Renovate PRs

Renovate opens PRs for:

- The `bluefin-lts-nvidia` digest in `image-versions.yaml` (custom manager)
- Binary download pins in `image-versions.yaml` (`downloads:`, via `# renovate:` comments)
- Some dependency/action bumps (workflow SHAs are deliberately excluded)

### Review Checklist

- [ ] CI passes (`build.yml`, `zizmor.yml`, any validation)
- [ ] The digest change is isolated to the expected file
- [ ] No unexpected base-release jump (e.g. a Fedora/major bump when it shouldn't)
- [ ] Security advisories checked (Renovate usually flags CVEs in the PR body)

### Merge Strategy

`pin`/`pinDigest` updates are configured to automerge. For non-pin changes
(major/minor bumps), review manually before merging.

## Local Test Loop

Use the local loop for rapid iteration before opening a PR.

```bash
# 1. Build a container image
just build <variant>

# 2. Build a QCOW2 disk image (needs rootful podman + BIB)
just build-qcow2 <variant>

# 3. Run it in a VM
just run-vm-qcow2 <variant>
```

### Combined (common workflow)

```bash
just build <variant> && just build-qcow2 <variant> && just run-vm-qcow2 <variant>
```

### When to run

| Scenario | Test |
| --- | --- |
| Added a system package | `just build <variant>` + `bootc container lint` |
| Changed a `*.just` | `just check` |
| Changed a `build_files/*.sh` | `just lint` (shellcheck) |
| Changed a Brewfile | verify `brew`/`cask`/`flatpak` entries resolve |
| Major base/image change | full loop: build → qcow2 → run-vm |
| FSDK change | `just -C buildstream validate` then `just build-fsdk` |

## Adding a New Base Image (workflow trio)

To add a base `mybase` (like arch/debian/opensuse):

1. **`Justfile` `build` recipe `case`** — add a `mybase*)` arm with
   `IMAGE_NAME="mybase-bootc"`, `DEFAULT_TAG="testing"`, `BIB_IMAGE`, description.
   There is **no** `containerfiles/Containerfile.mybase` and **no**
   `images/mybase.env`: the `build` recipe selects the root `Containerfile` and
   passes the `BASE_IMAGE`/`BUILDER_SCRIPT`/`BUILD_SCRIPT` args for that base
   (nixos-style bases also set `LINT=0`).
2. **`build-mybase.yml`** — schedule + dispatch; build → rechunk → tag → push → sign,
   mirroring `build-arch.yml` (image-name `<base>-bootc`, default-tag `testing`).
3. **`promote-mybase.yml`** — `skopeo inspect .../<base>-bootc:testing`, open a
   `promote/<base>-stable-<digest12>` branch, edit `image-versions.yaml`, PR labeled `promote`.
4. **`tag-mybase-stable.yml`** — on merged `promote` PR, pull/pin/retag `:stable` + sign.

Keep the promote→tag naming and label (`promote`) consistent so the trio works.

## Rechunk Cadence

`rechunk` (chunkah) produces smaller bootc deltas. Base and most variant
workflows run it after build. `fsdk` deliberately skips it. Re-run
locally with `just rechunk <image> <tag>` when validating delta behavior. The
chunkah image is currently unpinned (TODO) — pin it once mature.

## PR vs Direct Push Policy

### Always open a PR to `main`

`blueprint` has only `main`. Direct pushes bypass validation and create
untraceable changes. PRs trigger `build.yml` and `zizmor.yml`.

### PR Best Practices

Use Conventional Commits and the change-type checklists — see `blueprint-pr-checklist`.

## Common Rationalizations

| Rationalization                                                  | Reality                                                                                  |
| ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| "I'll merge this Renovate PR without reading it — just a digest."| Verify the file affected; a misconfigured manager could touch the wrong image.          |
| "Local builds are optional since CI builds everything."         | Local builds catch issues faster and don't burn CI minutes. The `just build` loop is essential. |
| "I'll push to main to save time."                               | PRs are cheap. Direct pushes bypass validation and create untraceable changes.           |
| "I'll hand-edit the `:stable` digest to promote faster."        | Use `promote-<base>.yml`. Hand edits bypass review and the tag-stable workflow.          |

## Red Flags

- Renovate PRs sitting unmerged for weeks
- No local builds run before PRs are opened
- Direct pushes to `main` bypassing CI
- A new base image missing its promote/tag-stable pair
- `image-versions.yaml` `:stable` digest edited by hand

## Verification

- [ ] Are Renovate PRs merged or under active review?
- [ ] Was `just build` run locally before the last PR?
- [ ] Are all pushes to `main` via PR with passing CI?
- [ ] For any new base image: do `build-`/`promote-`/`tag--stable` workflows all exist and are consistent?
- [ ] Is `image-versions.yaml`'s `:stable` digest only ever changed by the promote flow?
