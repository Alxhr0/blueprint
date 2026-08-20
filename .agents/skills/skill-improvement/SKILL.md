---
name: skill-improvement
description: Record durable blueprint-specific learning after discovering a command, convention, workaround, or failure mode in the blueprint repo.
---

# Skill Improvement

## When to Use

- A task reveals a blueprint-specific command, constraint, workaround, or failure mode.
- Updating a local skill, the task router, or agent instructions.
- Preparing a pull request or handoff after nontrivial work.

## When NOT to Use

- The finding is a general bootc/ublue-os rule owned upstream (e.g. `projectbluefin/actions`, `ublue-os/*`).
- The information is transient task state, a backlog item, or a resolved PR.
- The work contains no reusable learning.

## Core Process

1. Decide whether the finding is specific to `blueprint` or a general upstream rule.
2. Update the closest relevant local skill with the timeless operating rule and
   its validation command.
3. Route upstream/general learning to the appropriate project; never edit
   `ublue-os/*`, `projectbluefin/*`, or `freedesktop-sdk/*`.
4. Validate the updated guidance in the same change as the implementation.

`blueprint` is a personal repository (`huntedraven7/blueprint`). Keep
blueprint-specific knowledge in `.agents/skills/`; do not push it upstream
unless a human opens the upstream PR.

Do not create changelogs, session logs, task notes, or "append here" documents.
They become stale and are not part of the repository knowledge base. Keep
temporary state in the agent session workspace and record only verified,
reusable guidance in a skill.

## Common Rationalizations

| Rationalization | Reality |
| --- | --- |
| "The lesson is obvious." | If it changed how this task was performed, future agents need it. |
| "I will document it later." | The implementation context is most accurate in the same PR. |
| "A session note is quicker." | Session notes rot; skills are the durable operating model. |

## Red Flags

- A nontrivial task ends without a relevant skill update.
- A skill contains session history, an issue list, or unresolved task state.
- A blueprint-specific lesson is written only in a PR comment or commit message.
- Upstream/general learning is committed into `blueprint` skills instead of routed upstream.

## Verification

- Confirm the learning is specific to `blueprint` rather than a general upstream rule.
- Update the relevant skill with the command, boundary, and validation evidence.
- Route general/upstream learning to the owning project; never edit `ublue-os/*`,
  `projectbluefin/*`, or `freedesktop-sdk/*`.
