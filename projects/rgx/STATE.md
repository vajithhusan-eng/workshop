# RGX — STATE

**Derived file.** Regenerate by verifying, not by trusting this file or any commit message.
**Verified:** 2026-10-17 · `HEAD 8e823e5` · fast suite **47 passed, 6 skipped** (4.95s); slow null control **53 passed** (`RGX_SLOW=1`, 66.7s).

## How to verify this file

```bash
cd projects/rgx
.venv/bin/python -c "import rgx.pipeline"           # imports cleanly
.venv/bin/python -m pytest tests/ -q                 # 47 passed, 6 skipped (fast)
RGX_SLOW=1 .venv/bin/python -m pytest tests/ -q      # 53 passed (adds 6 end-to-end null-control tests, ~55s)
wc -l rgx/*.py rgx/*/*.py | tail -1                  # 2910 lines
grep -c '^def test_' tests/test_invariants.py        # 47
grep -c '^def test_' tests/test_null_control.py      # 4 (parametrized → 6 tests)
```

## Verified green

| Check | Result |
|---|---|
| `import rgx.pipeline` | **OK** |
| `pytest tests/` | **47 passed, 6 skipped** (4.5s) |
| `RGX_SLOW=1 pytest tests/` | **53 passed** (55.5s) |
| `tests/test_invariants.py` | `def test_` count: **47** |
| `tests/test_null_control.py` | **6 tests** (4 `def test_`, one parametrized ×3 seeds) |
| Python version | **3.14.4** (`.venv`, rebuilt 2026-10-06 after system upgrade removed 3.12) |
| Deps | numpy 2.5.3 · pandas 3.0.6 · scipy 1.18.1 · scikit-learn 1.9.1 · lightgbm 4.7.0 · pytest 9.1.1 |
| Git tracking | HEAD `8e823e5` · working tree **clean** apart from the five uncommitted STATE.md pins (rule 4.1) · the previously-uncommitted leak-fix work and the untracked docs/`tests/` are now committed; **26 tracked files** under `projects/rgx/` · no push attempted (no GitHub credentials on this machine). This file is left uncommitted on purpose — `scripts/verify_docs.py` reads the **working-tree** pin, so committing the pin into its own commit immediately re-stales it (see `projects/agora/STATE.md`). |

## Build status

**2,910 LOC across 18 modules. Fast suite **47 passed + 6 skipped**; slow suite (`RGX_SLOW=1`) **53** = 47 invariants + 6 end-to-end null-control tests, all green. Docs: `AGENTS.md`, `README.md`, this file.**

`pipeline.py` wires six layers into `run_evaluation`; `validation/` holds metrics, splits, costs, baselines; `model/` holds the GBDT ranker and microstructure gate; `portfolio/` holds construction; `factors/` holds price/volume factors; `data/synthetic.py` generates planted-edge and null panels.

## Verification status — the honest part

- The beta-drift leak is **closed and frozen**: `MARKET_DRIFT = 0.0` in `config.py:112`, with the mechanism documented in its comment. Previously 0.0002 × heterogeneous fixed `beta` gave every name `E[r_h] = h·drift·beta_i` — a rankable beta-only IC of +0.0175 (t = +5.86 as-shipped) on the "null" arm. At zero drift, pooled pooled beta IC drops to +0.00700 (t = +0.83).
- **Measured contrast at 200×1400 (seeds 4 each): null mean RankIC +0.0312 (all 4 seeds positive: +0.029 / +0.055 / +0.034 / +0.007) vs planted mean +0.0235 — the contrast is INVERTED.** At 300×1600: null +0.0057, planted +0.0067. All 16 post-fix runs report `NO RELIABLE EDGE` (NW t max 2.48 < 3.0, deflated p min ≈ 0.75). **End-to-end power is NOT demonstrated at these panel sizes.**
- **Why the null still reads positive — variance scaling in the compound return.** Vol/turnover factors (`idio_vol_60` and friends) carry +0.025…+0.040 rank IC on the null panel with 4/4 seed signs, growing with horizon (h=1: +0.0016 → h=80: +0.0156). Random-score controls sit at ~0, so the IC layer itself is unbiased. This artifact does **not** respond to `MARKET_DRIFT`. It is structure in the synthetic generator: a null panel whose realized compound return variance is a function of per-name vol is genuinely rankable by vol.
- **Generator-level power, as measured:** planted panels seeded 3/7/11/19 put the oracle (true-signal) RankIC at **+0.079…+0.103** (canonical Spearman IC via `validation/metrics.py`), comfortably above `ORACLE_RANKIC_FLOOR = 0.05`. The guard `test_planted_generator_holds_a_rankable_signal` passes.
- **What is deliberately NOT asserted at pipeline level** (documented in `tests/test_null_control.py` docstring): `null RankIC < planted RankIC`, and `t_stat > 3` / `deflated_p < 0.05` on the planted arm. The first has no demonstrated power (measured contrast is inverted), and asserting it would create a test that cannot pass; the planted-arm significance assertions are the *definition* of the edge and are not yet recoverable through the 6-layer pipeline at 200×1400. A null test that cannot fail is worse than none.
- Two accuracy bugs found and fixed this session: `directional_accuracy` counted `n = mask.size` instead of `mask.sum()` (~6× overstated evidence), and `pipeline.py` zero-filled NaN forward returns (`nan_to_num(fwd, nan=0.0)`), turning ~16% of compare pairs into guaranteed-wrong (−8pp accuracy, −8pp base rate).
- The harness **refuses** a too-short panel: `RuntimeError: no walk-forward folds fit in 760 dates at 5y train`. Validation working, not a defect.
- A default-size run (`python -m rgx.pipeline planted`, 800×2510) was launched in an earlier session but did not complete inside the window; its output was **not observed**, so no number from it is quoted.

## Known gaps

1. **No real market data.** Every result is on synthetic panels with a planted edge or a known null. Nothing demonstrates edge on real market data.
2. **The generator's null is not clean.** The variance-scaling mechanism above means the null panel carries rankable vol structure — and at 200×1400 the null arm reads *higher* than the planted arm. Until separation is demonstrated, the harness cannot claim end-to-end power; it can only claim honest reporting (both arms correctly say `NO RELIABLE EDGE`).
3. **No CLI beyond `__main__`'s single `argv[1]`.** No arg parsing, no config file.
4. **Runtime.** Default-size LightGBM runs take minutes; `nohup` + redirect block-buffers stdout — use `.venv/bin/python -u -m rgx.pipeline planted` to watch progress.
5. **`.venv/` is large and must stay untracked** — never `git add` it. It was rebuilt on Python 3.14 on 2026-10-06; if a future system Python upgrade breaks `import pytest`, rebuild: `rm -rf .venv && /usr/bin/python3 -m venv .venv && pip install -r requirements.txt`.
6. **`STATE.md` was stale until this rewrite** — it previously quoted the contaminated pre-fix numbers (null RankIC ≈ +0.0011, planted ≈ +0.0224, "38 tests").

## Open questions

- How should the null-control stay honest given the generator limitation? Options: shrink panel sizes where the contrast flips back (checked at 300×1600: still unordered), re-architect `idio_vol` so the null's realized variance is cross-sectionally flat, or accept a null with known vol structure and report the oracle-vs-null contrast per factor layer rather than per pipeline.
- Should the null control become a hard test? It is the project's central invariant; `AGENTS.md` locks it but CI runs only the fast suite. The slow 6-test file exists and is green under `RGX_SLOW=1`; wiring it into CI is a runtime-cost decision.
- Should `RunConfig` grow a proper argparse surface?