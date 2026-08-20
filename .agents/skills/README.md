# blueprint Skills Router

## About

This directory contains discoverable Agent Skills for the `blueprint` personal
bootc image builder. Each skill lives in a lowercase directory with a required
`SKILL.md` file whose frontmatter tells compatible agents when to load it.

`blueprint` is a single repository that builds many independent OS image
variants plus three base images; the `Justfile` is the single build entrypoint.
These skills encode how the repo is structured and how to extend it safely.

## Skill Index

| Skill | What it covers |
| --- | --- |
| [`blueprint-router`](blueprint-router/SKILL.md) | The task routing table: which skill covers what, and the standard sequence. Load when unsure. |
| [`blueprint-overview`](blueprint-overview/SKILL.md) | Repository architecture and file layout. Start here for orientation. |
| [`blueprint-onboarding`](blueprint-onboarding/SKILL.md) | How to add a new image variant to blueprint (Containerfile + env + workflow, or inline base case). |
| [`blueprint-templates`](blueprint-templates/SKILL.md) | Defining a variant's image identity (IMAGE_NAME/DEFAULT_TAG/Containerfile/env or inline base case), AGENTS.md update rules. |
| [`blueprint-packages`](blueprint-packages/SKILL.md) | Where packages go: Containerfile RUN, build_files scripts, brew bundle, BuildStream elements. |
| [`blueprint-custom`](blueprint-custom/SKILL.md) | Runtime customization: system_files overlays, brew/, disk_config. |
| [`blueprint-build`](blueprint-build/SKILL.md) | Containerfile, Justfile, build_files, buildstream, image digest pinning, rechunking. |
| [`blueprint-ci`](blueprint-ci/SKILL.md) | GitHub Actions workflows, Renovate, projectbluefin/actions composite actions, the promote/tag-stable flow. |
| [`blueprint-maintain`](blueprint-maintain/SKILL.md) | Ongoing work: Renovate PRs, adding base-image workflows, local test loops, rechunk. |
| [`blueprint-troubleshooting`](blueprint-troubleshooting/SKILL.md) | Symptom → cause → fix tables for podman build, BIB, CI, rechunk, cosign. |
| [`blueprint-pr-checklist`](blueprint-pr-checklist/SKILL.md) | Pre-commit and per-change-type validation checklists. |
| [`blueprint-examples`](blueprint-examples/SKILL.md) | Runnable example scripts / activation patterns for adding build steps. |
| [`skill-improvement`](skill-improvement/SKILL.md) | Capture durable, blueprint-specific operational learning. |

Looking for "I need to… → which skill?" — that table lives in
[`blueprint-router`](blueprint-router/SKILL.md), its single canonical home.

## How to Extend Skills

When adding a new skill:

1. **Create a lowercase, hyphenated directory** under `.agents/skills/`
2. **Add `SKILL.md`** with `name` and `description` frontmatter; `name` must match the directory
3. **Describe when to use the skill** precisely so agents can select it automatically
4. **Include the standard sections**: When to Use, When NOT to Use, Core Process, Common Rationalizations, Red Flags, Verification
5. **Add the skill to this README** and to the routing table in `blueprint-router/SKILL.md`
6. **Keep `SKILL.md` focused** — split deep sub-topics into sibling `.md` files in the same directory and link them from `SKILL.md` (relative links, e.g. `[AGENT-BRIEF.md](AGENT-BRIEF.md)`)

## References

- [Adding agent skills for GitHub Copilot](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills)
- [Agent Skills specification](https://agentskills.io/specification)
- [AGENTS.md](../../AGENTS.md) — high-level instructions and mandatory gates
