# OMNIVEST backend — project instructions

Python + FastAPI service for the OMNIVEST education / self-analytics / journal
terminal. It predates the `projects/` tree: it shares this repository, not its
stack (no Flutter, no CDP, no drift).

## Authority

- [`README.md`](README.md) — how to run and test it, and the API surface.
- `STATE.md` — derived build status. Regenerate with the `project-orientation` skill.
- **There is no `PLAN.md`.** The design record is the module docstrings — read
  `app/guardrails.py`, `app/main.py` and `run.py` before changing behaviour.

## Locked decisions — violating these reverses work already done

1. **SAFE mode is the default.** Advice is opt-in via `OMNIVEST_ADVISER_MODE=1`
   and only a SEBI-registered IA/RA partner may set it. Never weaken
   `guardrails.BLOCKED_PATTERNS`, and never let a rating or price target through
   while `ADVISER_MODE` is false.
2. **Unknown fields are a 422, never a silent default.** A misspelled field once
   produced a confident verdict computed from default numbers. The Pydantic
   models set `model_config = ConfigDict(extra="forbid")` deliberately.
3. **Synthetic data is labelled.** No real bars → `NO_DATA` verdict plus a
   `data_warning`. Never fill in plausible-looking prices.
4. **A journal you cannot correct is not a journal.** Every write path needs a
   matching undo — see `_delete_entries_where`.
5. **No database server.** JSON on disk, stdlib plus the pinned dependencies.
   Adding a dependency is a decision, not a convenience.
6. **`omnivest_journal.json` is user data**, gitignored, and tests must leave no
   residue in it.

## Conventions

- `from __future__ import annotations`, type hints throughout, no ORM.
- Dependencies pinned exactly in `requirements.txt`:
  `fastapi==0.116.1`, `uvicorn[standard]==0.30.6`, `pydantic==2.9.2`,
  `python-multipart==0.0.19`, `httpx==0.27.2`.
- **Routes live only in `app/main.py`**; the logic lives in the sibling modules.
- Test suites in `app/tests/` are script-style: they print their own totals
  (`ALL n CHECKS PASSED`) and exit non-zero on failure.

## Run and verify

```bash
cd backend
./.venv/bin/python run.py      # terminal 1 — http://127.0.0.1:8123
make test-unit                 # terminal 2 — 143 checks, no server needed
make test-api                  # needs the server running: 168 checks
```

## Traps

- **`pytest app/tests` and `run.py` want different things.** `test_api.py` is a
  live-server smoke test; `conftest.py` excludes it from pytest collection. The
  two "failures" a bare `pytest app/tests` used to show were only that.
- **Reload flap.** Watching the repo root made the server restart on every test
  write and occasionally lose the race to re-read `run.py`. `reload_dirs` is
  narrowed to `app/` with `tests/` excluded.
- **`ADVISER_MODE` is read at import time.** Changing the env var needs a restart.
- **`run.py` bootstraps `sys.path`** with its own directory so `app.*` imports
  resolve when the file is executed directly.

## Scope

Only `backend/`. The Flutter client for this product is the sibling
[`frontend/`](../frontend/); they are separate projects with separate instructions.
