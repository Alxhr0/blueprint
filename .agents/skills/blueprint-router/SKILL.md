---
name: blueprint-router
description: >-
  Task router for the blueprint repo: which skill covers what, and the
  overview → domain → PR-checklist sequence. Use when unsure which skill
  fits, or to add a skill to the routing table.
---

# blueprint Router

## When to Use

- You don't know which skill covers your task
- You want the standard sequence before starting a multi-phase task
- You are adding, renaming, or removing a skill
- You are onboarding a new agent or contributor

## When NOT to Use

- You already know the area — load the matching skill directly, not this one
- You need mechanics (build, CI, runtime) — those live in the domain skills

## Core Process

1. **Run the standard sequence** for an unfamiliar multi-phase task: start with
   `blueprint-overview`, continue with the domain skill, finish with
   `blueprint-pr-checklist`.
2. **Find your task in the table** below and load the matching skill.

| I need to…                                  | Load                                        |
| ------------------------------------------- | ------------------------------------------- |
| Orient to repo architecture                 | `blueprint-overview`                        |
| Add a new image variant to blueprint        | `blueprint-onboarding`                      |
| Define a variant's image identity / AGENTS  | `blueprint-templates`                       |
| Add/remove a package                        | `blueprint-packages`                        |
| Change system_files overlays, brew/, disk   | `blueprint-custom`                          |
| Change Containerfile, Justfile, build_files, buildstream, digest pins | `blueprint-build`  |
| Fix CI, Renovate, promote/tag-stable flow   | `blueprint-ci` / `blueprint-maintain`       |
| Open a PR / validate a change               | `blueprint-pr-checklist`                    |
| Debug a build, BIB, CI, rechunk, or cosign failure | `blueprint-troubleshooting`         |
| Follow a worked example / activation pattern| `blueprint-examples`                        |
| Capture a durable lesson                    | `skill-improvement`                         |
| Pick a skill for a new task                 | `blueprint-router` (this skill)             |

## Common Rationalizations

| Rationalization                                           | Reality                                                                 |
| --------------------------------------------------------- | ----------------------------------------------------------------------- |
| "The router table is in AGENTS.md — update it there."     | AGENTS.md holds rules. This skill owns the routing table, so it stays in sync with the skill set. |
| "Every skill should list where it fits."                  | One table means one place to update; skills point here instead.         |

## Red Flags

- A second routing table appears in AGENTS.md, `.agents/skills/README.md`, or a skill — route edits to this file
- A new skill exists but is missing from this table

## Verification

- [ ] The table lists every skill in `.agents/skills/`
- [ ] AGENTS.md and `.agents/skills/README.md` point here instead of carrying their own tables
- [ ] `name` frontmatter matches the directory name
