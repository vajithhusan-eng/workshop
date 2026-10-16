# Agora — documentation

The documentation set for Agora. Every document has one concern; the project's
other top-level Markdown files are indexed here too, because they are part of the
project's permanent record and must not be orphaned.

| Document | Concern | Authority |
|---|---|---|
| [`../README.md`](../README.md) | How to install, run and understand the app | product framing |
| [`../AGENTS.md`](../AGENTS.md) | Instructions for changing the code: locked decisions, traps | project instructions |
| [`../STATE.md`](../STATE.md) | Derived build status — regenerated, never hand-written | derived |
| [`../CHANGELOG.md`](../CHANGELOG.md) | What changed, by commit, newest first | history |
| [`../PLAN.md`](../PLAN.md) | **The plan of record** | **binding** — `Status: PLAN APPROVED` |
| [`../PLAN-GROUPCHAT.md`](../PLAN-GROUPCHAT.md) | The group-chat proposal that became Amendment R1 | **superseded** — keep as record only |
| [`../VISION.md`](../VISION.md) | The original vision, in the user's own words | historical — verbatim, add-only |
| [`../ARCHITECTURE-legacy.md`](../ARCHITECTURE-legacy.md) | The deleted Python backend | **archived** — never build against it |

## Reading order

1. [`../README.md`](../README.md) — what Agora is and how to run it.
2. [`../PLAN.md`](../PLAN.md) §0 (TL;DR), §2 (non-negotiables) and **§18
   Amendment R1** (the ratified dispatch model).
3. [`../AGENTS.md`](../AGENTS.md) — the traps, and what is deliberately unbuilt.

## `PLAN-GROUPCHAT.md` is not authority

It is `Status: PROPOSED` and it is superseded. Its D1 round-robin **was** ratified
on 2026-10-06 — but as `PLAN.md` **§18 Amendment R1**, under the approved plan,
and renamed `broadcast`. Keep the file as the record of what was proposed; never
cite it as authority over `PLAN.md`. It also names files that never existed under
those names (`security_firewall.dart` → actual `safety.dart`;
`context_compiler.dart` → actual `prompt_compiler.dart`), so it is not a literal
task list.

## `ARCHITECTURE-legacy.md` is archived

It documents the Python backend that was deleted when Agora moved to Flutter +
raw CDP + SQLite. It is kept for history. Building against it would reverse locked
decision #2 in [`../AGENTS.md`](../AGENTS.md).

## Related

Nothing outside `projects/agora/` shares these conventions. `PROJECT-STANDARD.md`
at the repo root defines the document set every project carries.
