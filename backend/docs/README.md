# OMNIVEST backend — documentation

The documentation set for this project. Every document has one concern; the
project's other top-level Markdown files are indexed here too.

| Document | Concern |
|---|---|
| [`../README.md`](../README.md) | What this is, how to run it, how to test it, the 31 API routes |
| [`../AGENTS.md`](../AGENTS.md) | Instructions for changing the code: locked decisions, conventions, traps |
| [`../STATE.md`](../STATE.md) | Verified build status — the one file that is regenerated, never hand-written |
| [`../CHANGELOG.md`](../CHANGELOG.md) | What changed, by commit, newest first |

## Where the real design record lives

There is no `PLAN.md` and no separate architecture document, deliberately. The
design decisions that matter are documented **at the point of code**:

| Topic | Read |
|---|---|
| Why SAFE mode is the default and what it blocks | `app/guardrails.py` module docstring |
| Why unknown fields are rejected | `app/main.py` request models + `test_api.py` contract checks |
| Why the reload scope is narrowed | `run.py` docstring |
| Why every write has an undo | `_delete_entries_where` docstring in `app/main.py` |
| Why synthetic bars are labelled | `app/market.py` and the `NO_DATA` path in `app/strategy.py` |

If you add a document here, put it in this table. `scripts/verify_projects.py`
fails the build when a top-level Markdown file is not named in this index.
