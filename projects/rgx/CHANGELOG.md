# Changelog

All changes to RGX, newest first. Entries quote the commits that touched
`projects/rgx/`.

## 2026-10-17 — documentation standard

- `14dbbdc` test(rgx): add invariant and null-control tests for the research harness
- `d504935` docs: add monorepo and per-project orientation docs
- Added `CHANGELOG.md` and `docs/README.md`; corrected the `AGENTS.md` first line.
  No numerical model code changed.

## 2026-10-03

- `264b2ee` chore(rgx): track research harness — 2.8k LOC was invisible to git
  The six-layer harness (`data/synthetic.py`, `factors/price_volume.py`,
  `model/{regime,ranker}.py`, `portfolio/construction.py`, `validation/`,
  `ops.py`, `pipeline.py`, `config.py`) entered version control. The `null`
  control was already the central invariant at this point; this is the commit
  that made it reviewable.
