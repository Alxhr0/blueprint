---
name: blueprint-pr-checklist
description: >-
  PR gates and pre-commit checklist by change type. Covers validation commands
  for Justfile, Containerfiles, build_files, Brewfiles, BuildStream, workflows,
  and yaml. Use before opening or reviewing a PR.
---

# blueprint PR Checklist

## When to Use

- Before opening a new pull request
- Before pushing changes that modify build scripts, CI workflows, or runtime files
- When reviewing a PR and verifying the author ran the correct validation steps

## When NOT to Use

- The PR only contains documentation changes — run `just check`/`just lint` still, but the full checklist is overkill
- You are troubleshooting an already-open PR — use `blueprint-troubleshooting`

## Core Process

0. **Check for an existing open PR** — before writing code, run
   `gh pr list --state open` and skim it. Multiple agents may work this repo
   concurrently; if a PR already addresses the issue, extend it instead of
   opening a competing one.
1. **Identify which files changed**
2. **Run the relevant validation commands** from the tables below
3. **Fix any errors** before opening the PR
4. **Open the PR** and ensure all status checks pass

## Pre-Commit Checklist (Applies to ALL Commits)

Before every commit, run:

### 1. Conventional Commits

```
<type>[optional scope]: <description>
```

Valid types: `feat`, `fix`, `docs`, `chore`, `build`, `ci`, `refactor`, `test`.
Promotion commits use the `promote:` prefix from the promote workflows — don't hand-write.

### 2. Just validation

```bash
just check        # just --unstable --fmt --check on Justfile + *.just
```

### 3. Shellcheck

```bash
just lint         # shellcheck on all *.sh
# or per-file:
shellcheck build_files/<variant>/build-<variant>.sh
```

### 4. shfmt (formatting)

```bash
shfmt -d <file>   # check; just format writes fixes
```

### 5. YAML validation

```bash
python3 -c "import yaml; yaml.safe_load(open('file.yml'))"
```

### 6. actionlint (when workflows changed)

```bash
actionlint .github/workflows/*.yml
```

**Fix ALL errors before committing.** shellcheck/actionlint in CI are hard blocks.

---

## Change-Type-Specific Checklists

### Containerfile / Justfile Changes

| Check | Command |
| --- | --- |
| Justfmt | `just check` |
| Shellcheck (if scripts modified) | `just lint` |
| Local build test | `just build <variant>` |

**CI triggers:** `build.yml`, `zizmor.yml`, variant build workflows.

### `build_files/*.sh` Changes

| Check | Command |
| --- | --- |
| Shellcheck | `just lint` (or `shellcheck build_files/.../*.sh`) |
| Local build test | `just build <variant>` |
| bootc lint | runs inside the built image (`RUN bootc container lint`) |

**CI triggers:** the matching `build-*.yml` workflow.

### BuildStream (`buildstream/`) Changes

| Check | Command |
| --- | --- |
| Element graph validation | `just -C buildstream validate` |
| Local build (optional) | `just build-fsdk` |

**CI triggers:** `build-base-images.yml` (fsdk matrix entry).

### Brewfile (`brew/<variant>/packages.Brewfile`) Changes

| Check | Command |
| --- | --- |
| Verify brew/cask names resolve | `brew bundle check --file brew/<variant>/packages.Brewfile` |
| Verify Flatpak IDs on Flathub | Visit `https://flathub.org/apps/<app-id>` |

**CI triggers:** none dedicated today — validate manually.

### `system_files/` / `disk_config/` Changes

| Check | Command |
| --- | --- |
| YAML/toml syntax | `python3 -c "import yaml; ..."` (yaml); toml sanity via build |
| Overlay ordering | confirm `system_files/global` copied before variant overlay |

**CI triggers:** the variant's build / `build-disk.yml`.

### Workflow Changes

| Check | Command |
| --- | --- |
| actionlint | `actionlint .github/workflows/*.yml` |
| YAML syntax | `python3 -c "import yaml; yaml.safe_load(open('file.yml'))"` |
| zizmor (security) | runs via `zizmor.yml` on workflow changes |

**CI triggers:** `zizmor.yml`, `build.yml`.

### `image-versions.yaml` Changes

| Check | Command |
| --- | --- |
| YAML syntax | `python3 -c "import yaml; yaml.safe_load(open('image-versions.yaml'))"` |
| Only promote flow edits `:stable` | confirm no hand-edited `:stable` digest (use `promote-<base>.yml`) |

**CI triggers:** `tag-<base>-stable.yml` (on merged `promote` PR).

### README / AGENTS.md / Skills Changes

| Check | Command |
| --- | --- |
| Justfmt (if `*.just` touched) | `just check` |
| Link/reality check | confirm variant list and tags match the Justfile `build` recipe `case` arms (unified + base identity, no per-variant env) and `buildstream/images/fsdk.env` (no `images/*.env` files remain) |

**CI triggers:** none by default.

---

## PR Status Check Reference

| Workflow | Trigger | Required? |
| --- | --- | --- |
| `build.yml` | PR → main | Yes (for image changes) |
| `zizmor.yml` | PR on workflows | Yes (for workflow changes) |
| variant `build-*.yml` | schedule / dispatch | Yes (when that variant changes) |

All relevant validation must pass before a PR is merged.

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "I'll skip shellcheck locally — CI will catch it." | CI catches it, but wastes time. Running locally takes seconds. |
| "I only changed one line in a workflow — no actionlint." | YAML is fragile. actionlint catches issues `yaml.safe_load` doesn't. |
| "The PR is small — I don't need the full checklist." | The checklist is weighted by change type. Use the relevant section. |
| "I'll fix the Brewfile syntax after the PR is open." | Validate before opening; manual checks are the only gate for Brewfiles today. |

## Red Flags

- PR opened with shellcheck / justfmt failures
- Brewfile Flatpak ID not verified on Flathub
- Workflow YAML with syntax errors (catches actionlint, not just CI)
- A `:stable` digest hand-edited in `image-versions.yaml`
- Missing Conventional Commit format in PR title or commits
- A shared `images/*.env` / `dotenv-filename` env file reintroduced (variant identity must stay inline in the `Justfile` `build` recipe `case` arms)

## Verification

- [ ] Did you run the pre-commit checklist (conventional commits, `just check`, `just lint`, yaml, actionlint if workflows)?
- [ ] Did you run the change-specific checks for your modified files?
- [ ] Do all validation commands pass locally?
- [ ] Does the PR title follow Conventional Commit format?
- [ ] Are all CI status checks green before requesting review?
- [ ] Did you confirm no `:stable` digest was hand-edited in `image-versions.yaml`?
