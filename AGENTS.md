# WORKSHOP — monorepo instructions

A container for several unrelated products plus one older finance/forensics app.
**There is no single application here.** Identify which project a task belongs to
before touching anything.

## Layout

| Path | What it is | State |
|---|---|---|
| `projects/agora/` | Flutter desktop (AppImage) multi-AI council orchestrator, drives real Chrome over CDP | **active** — 135 tests green, engine + storage built, UI built but **not mounted** |
| `projects/rgx/` | Python quant research harness — factors → ranker → regime → portfolio → validation | 2.8k LOC, **no tests**, synthetic-data self-validation |
| `projects/cleantube/` | Android-first Flutter ad-blocker (WebView + native YouTube client + DNS sinkhole) | **plan only — zero code** |
| `backend/` | Python + FastAPI finance/forensics service | older project |
| `frontend/` | Flutter app | older project |
| `scripts/` | `verify_api.sh` only | |
| `archive/`, `tools/` | empty | |
| `skills` | symlink → `~/.config/opencode/skills-active` | |

`package.json` declares workspaces `["backend", "frontend", "projects/*", "tools/*"]`,
but `backend/` and `frontend/` have no `package.json`, so those globs resolve to
nothing. `projects/story-app` is declared but **does not exist** — stale entry,
ignore it.

## Per-project instructions

Each project directory carries its own `AGENTS.md` with identity, scope, locked
decisions, and conventions, plus a `STATE.md` with verified build status. **When
working inside a project, read its `AGENTS.md` first** — it is more specific than
this file and wins where they conflict.

- `projects/agora/AGENTS.md` · `projects/agora/STATE.md`
- `projects/cleantube/AGENTS.md` · `projects/cleantube/STATE.md`
- `projects/rgx/` — **quant research harness, not a trading system.** It validates
  itself against synthetic data with a planted edge; its central invariant is that
  it **can return nothing**. Read its `AGENTS.md` first — it carries the locked
  methodological decisions and their citations. `tests/` contains only `__init__.py`,
  so **there is no suite to run and no green to claim** until one exists.

## New projects appear without orientation docs

`projects/rgx/` materialized during a session that had already oriented the repo.
Do not assume the layout table above is complete or that every project has
orientation files. When work lands in a directory that has no `AGENTS.md`, read
the code first and treat any existing `STATE.md` as unverified until the build
command has actually been run.

## Rules for this repo

- **`projects/agora` is the active project.** Recent commits are all Agora work.
- **Plan docs are the contract.** `agora/PLAN.md` is `Status: PLAN APPROVED`;
  `agora/PLAN-GROUPCHAT.md` is `Status: PROPOSED` and untracked, so it is *not*
  ratified. CleanTube's `PLAN.md` is the sole design doc. Never invent a design
  that contradicts an APPROVED plan — record the divergence instead.
- **Assume another agent is working here.** This repo has parallel agents as a
  normal condition, not an incident. Before editing a file you did not create,
  claim it — `python3 scripts/devsup.py claim <path> --note "why"` — and check
  `devsup.py claims` first. A refusal means coordinate, not overwrite. Release
  when done. If a file's mtime moves between your read and your write, someone is
  mid-write: re-read, do not assume your earlier read still holds.
- **Check `git status` before assuming a file is untouched.** There is usually
  uncommitted work in flight, and it may be someone else's.
- **A `STATE.md` pinned to an old commit is a red line.** Run `make docs-check`. It
  fails when a state file is staler than HEAD or an agent is defined in two places
  at once. Docs go stale here within minutes, not weeks.
- **`projects/agora/ARCHITECTURE-legacy.md` is archived.** It documents the deleted
  Python backend. Never build against it or resurrect its patterns.
- **`backend/` and `frontend/` are a different stack** — Python/FastAPI and Flutter,
  no CDP, no drift. Do not apply Agora's conventions to them, or vice versa.
- **Never `git push`, force-push, or reset `--hard`** without explicit confirmation
  in the current session.

## Verification commands

- `backend/` — run the Python suite in `app/tests/`.
- `projects/agora/` — run the Dart/Flutter suite in `test/`. Real-Chrome checks live
  in `tool/` and are **manual, opt-in**; do not wire them into CI.
- `projects/cleantube/` — nothing to run; no code exists.

Run the real command and read the output before reporting done.

## Orientation

At the start of work on a project you have not oriented in this session, invoke the
`project-orientation` skill. It answers what the project is, what its scope is,
what has been decided, what is built versus what the plan claims, and refreshes
`STATE.md`.

Do this before planning, not after. Contradictions between a plan and the code are
the norm here, not the exception — the `agora` dispatch model was one of them. It
was **closed** by Amendment R1 (`PLAN.md` §18, ratified 2026-10-06), so check
`projects/agora/AGENTS.md` before treating it as open. Others may still be live.