# RGX — documentation

The documentation set for the RGX research harness. Every document has one
concern; the project's other top-level Markdown files are indexed here too.

| Document | Concern |
|---|---|
| [`../README.md`](../README.md) | What the harness is, how to run it, and its limitations |
| [`../AGENTS.md`](../AGENTS.md) | Instructions for changing it: locked methodological decisions and their citations |
| [`../STATE.md`](../STATE.md) | Verified status — suite results, entry points, known gaps |
| [`../CHANGELOG.md`](../CHANGELOG.md) | What changed, by commit, newest first |

## There is no `PLAN.md`

This is a research harness, not a product. Its design record is
[`AGENTS.md`](../AGENTS.md) (the locked decisions and their citations) plus
`rgx/config.py`, which is the single frozen place every constant that affects a
reported number lives. See `AGENTS.md` §"Config is frozen and central".

## Where the design record lives

| Topic | Read |
|---|---|
| The central invariant — the harness must be able to return nothing | `rgx/pipeline.py` (module docstring) and `AGENTS.md` |
| Why a GBDT and not a transformer | `AGENTS.md` → Zeng et al. (arXiv:2205.13504) |
| Why `MIN_T_STAT = 3.0` and the selection-noise floor | `AGENTS.md` → Harvey, Liu & Zhu (RFS 2016) |
| The cost model and its constants | `rgx/config.py`, centralised deliberately |
| The panel convention `(T, n)` | `ops.py` — read it before writing any new array maths |

## Two suites, one invariant

`tests/test_invariants.py` (47 tests) guards component contracts.
`tests/test_null_control.py` is gated behind `RGX_SLOW=1` because each run costs a
full LightGBM fit — and **it is the only suite that exercises the central
invariant end-to-end.** A plain `pytest` reporting `47 passed, 6 skipped` has not
proved that the pipeline can return nothing. See [`../STATE.md`](../STATE.md).

## Related

Nothing outside `projects/rgx/` shares this project's conventions. Do not import
its patterns into `projects/agora/` or `backend/`.
