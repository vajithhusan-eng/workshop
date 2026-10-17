# WORKSHOP — monorepo instructions

A container for several unrelated products plus one older finance/forensics app.
**There is no single application here.** Identify which project a task belongs to
before touching anything.

## Layout

| Path | What it is | State |
|---|---|---|
| `projects/agora/` | Flutter desktop (AppImage) multi-AI council orchestrator, drives real Chrome over CDP | **active** — 290 tests green, engine + storage + UI built |
| `projects/rgx/` | Python quant research harness — factors → ranker → regime → portfolio → validation | 2.8k LOC, 47 fast + 6 slow tests, synthetic-data self-validation |
| `projects/cleantube/` | Android-first Flutter ad-blocker (browser + native YouTube client + DNS sinkhole) | **plan only — zero code** |
| `projects/arise/` | Research + roadmap, in flight by another agent | **exempt** from `make check` while it lands |
| `backend/` | Python + FastAPI finance/forensics service (OMNIVEST, `:8123`) | active |
| `frontend/` | Flutter web terminal for the same service (`:8081`) | active |
| `scripts/` | `devsup.py`, `new_project.py`, `verify_docs.py`, `verify_projects.py`, `verify_api.sh` | |
| `templates/project/` | the canonical project skeleton | |
| `PROJECT-STANDARD.md` | the document standard every project follows | |
| `skills` | symlink → `~/.config/opencode/skills-active` | |

`package.json` declares workspaces `["backend", "frontend", "projects/*", "tools/*"]`,
but none of those directories has a `package.json`, so an npm install here does
nothing. It is a manifest of intent only; the real entry points are the `Makefile`
and each project's own tooling.

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
  methodological decisions and their citations. `pytest tests/` runs 47 invariants
  but **skips the null control**; only `RGX_SLOW=1 pytest tests/` exercises the
  central invariant. Quoting the fast number as proof the pipeline can return
  nothing is quoting a test that never ran.
- `backend/AGENTS.md` · `frontend/AGENTS.md` — the OMNIVEST pair: a Python/FastAPI
  service and its Flutter web client. They obey the same document standard but no
  Agora convention; do not mix the two.
- `projects/arise/AGENTS.md` — in flight by another agent. Do not edit, commit or
  clean it; it is exempt from `make check` until it settles.

## New projects appear without orientation docs

`projects/rgx/` materialized during a session that had already oriented the repo.
Do not assume the layout table above is complete or that every project has
orientation files. When work lands in a directory that has no `AGENTS.md`, read
the code first and treat any existing `STATE.md` as unverified until the build
command has actually been run.

## Rules for this repo

- **`projects/agora` is the active project.** Recent commits are all Agora work.
- **Plan docs are the contract.** `agora/PLAN.md` is `Status: PLAN APPROVED`;
  `agora/docs/archive/PLAN-GROUPCHAT.md` is `Status: PROPOSED` and superseded — its
  D1 was ratified as `PLAN.md` §18 Amendment R1, so it is *not* authority. CleanTube's
  `PLAN.md` is the sole design doc. Never invent a design that contradicts an
  APPROVED plan — record the divergence instead.
- **Assume another agent is working here.** This repo has parallel agents as a
  normal condition, not an incident. Before editing a file you did not create,
  claim it — `python3 scripts/devsup.py claim <path> --note "why"` — and check
  `devsup.py claims` first. A refusal means coordinate, not overwrite. Release
  when done. If a file's mtime moves between your read and your write, someone is
  mid-write: re-read, do not assume your earlier read still holds.
- **Check `git status` before assuming a file is untouched.** There is usually
  uncommitted work in flight, and it may be someone else's.
- **A `STATE.md` pin must name a commit that exists.** Run `make check`:
  `projects-check` enforces the document set, `docs-check` that every pin resolves in
  this history and that no agent is defined twice. A pin may legitimately be older
  than HEAD; it may never be invented. Docs go stale here within minutes, not weeks.
- **Every project carries the same document set** — `README.md`, `AGENTS.md`,
  `STATE.md`, `CHANGELOG.md`, `docs/README.md` — because
  [`PROJECT-STANDARD.md`](PROJECT-STANDARD.md) says so and `make projects-check`
  enforces it. `STATE.md` holds the pin and the exact commands that produced its
  numbers; update the pin as the *last* edit of a work session, then commit it with
  the rest of the change.
- **`projects/agora/docs/archive/ARCHITECTURE-legacy.md` is archived.** It documents
  the deleted Python backend. Never build against it or resurrect its patterns.
- **The repo root carries only what belongs at the root.** No scratch files,
  screenshots or one-off scripts live there: a document belongs in the project it
  describes, a script in `scripts/`. `.gitignore` ignores `/*.png`, so a stray
  screenshot cannot come back unnoticed.
- **`backend/` and `frontend/` are a different stack** — Python/FastAPI and Flutter,
  no CDP, no drift. Do not apply Agora's conventions to them, or vice versa.
- **Never `git push`, force-push, or reset `--hard`** without explicit confirmation
  in the current session.

## Verification commands

- `backend/` — `make test-unit` (143 checks, no server needed) or `make test-api`
  (168 checks, needs the server up). `pytest app/tests` collects only the unit
  suite: `test_api.py` is a live-server smoke test and is deliberately ignored
  there.
- `frontend/` — `cd frontend && flutter test` (165 tests), or `make test-frontend`.
- `projects/agora/` — run the Dart/Flutter suite in `test/` (290 tests). Real-Chrome
  checks live in `tool/` and are **manual, opt-in**; do not wire them into CI.
- `projects/rgx/` — `.venv/bin/python -m pytest tests/` (47 fast); add `RGX_SLOW=1`
  for the 6 null-control tests that actually exercise the invariant.
- `projects/cleantube/`, `projects/arise/` — nothing to run.

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