# RGX — project instructions

Load this before touching anything in `projects/rgx/`.

## What this is

A **quantitative research harness that validates its own methods against synthetic
data with a known, planted edge.** It is not a trading system, not a live strategy,
and it does not fetch market data. There is no broker, no portfolio state, no
capital.

`RunConfig.edge` is either `"planted"` (a real edge is injected) or `"null"` (no
edge exists). Everything in this project exists to answer one question: **when no
edge exists, does the pipeline correctly report that there isn't one?**

## The one invariant that matters

> The pipeline **can return nothing.** A run with `edge="null"` must produce an
> out-of-sample Sharpe indistinguishable from zero and a large p-value. If it does
> not, there is a leak, and no result from this code should be believed until that
> leak is found.
>
> — `rgx/pipeline.py:12`

This is not paranoia. Gençay (arXiv:2608.27734) showed a **deliberately leaky
oracle** posting a Sharpe of 35 survives Deflated Sharpe and PBO testing completely —
**statistical correction catches selection, never look-ahead.** No amount of
significance testing substitutes for architectural leakage prevention.

**Never weaken a leak barrier, an embargo, or the `null` control to make a result
look better.** A harness that cannot fail is worse than no harness.

## Architecture — six layers, wired by `pipeline.run_evaluation`

1. **Point-in-time universe** (`data/synthetic.py`) — no survivorship bias, as-of joins only
2. **Price/volume factors** (`factors/price_volume.py`) — deliberately classical
3. **Microstructure regime gate** (`model/regime.py`) — observable book-density routing
4. **LambdaRank ensemble** (`model/ranker.py`) — GBDT, explicitly not a transformer
5. **Cost-aware portfolio** (`portfolio/construction.py`) — vol target, quarter-Kelly, ADV cap
6. **Honest evaluation** (`validation/`) — walk-forward, base rates, DSR, PBO, cost grid

Cross-cutting numerics live in `ops.py` — everything there operates on `(T, n)`
panels, one row per date, one column per name. Read `ops.py` before writing any new
array maths; the panel convention is easy to get silently wrong.

## Locked methodological decisions

These are deliberate and citable. Changing one is a research decision, not a
refactor. Each is a place where the obvious choice was rejected on evidence.

| Decision | Why |
|---|---|
| **`MIN_T_STAT = 3.0`**, not the conventional 2.0 | Harvey, Liu & Zhu (RFS 2016): a factor needs a much higher hurdle. |
| **Selection-noise floor** `sqrt(2·ln N)`, N=100 → ~3.0 | Any in-sample Sharpe below this lies inside its own search's noise. |
| **GBDT ranker, not a transformer** | Zeng et al. (arXiv:2205.13504): self-attention is **permutation-invariant**, and in a time series ordering *is* the signal. Structural mismatch, not a tuning gap. Also arXiv:2301.00790, 2608.27076, 2510.14156. |
| **Classical factors only** | Gu, Kelly & Xiu (RFS 2020): trees and deep nets agree on the same dominant signals — momentum, liquidity, volatility. The feature set is not where you win; the regime gate, cost model and validation discipline are. |
| **Point-in-time universe bands** | Gençay (arXiv:2608.27734) — leakage must be prevented architecturally, not corrected statistically. |
| **Cost-aware rebalance** (`MIN_EDGE_TO_TRADE_BPS = 2.0`) | AlphaOpsBench (arXiv:2609.31390): costs alter subsequent price paths rather than acting as a pure ex-post deduction. |
| **Cost model**: Alperovic & Petajisto (2005) decomposition + square-root impact | All terms are fractions of traded notional, centralised in `config.py`. |
| **Cost grid up to 100 bp** | Kargarzadeh et al. (arXiv:2608.12283) stress level. |
| **Backtest-engine risk treated as first-order** | arXiv:2603.20319 — the engine, not just the strategy, is a source of error. Hence `config.py` centralises every constant that affects a reported number. |
| **Regime gate is the differentiator** | arXiv:2607.01550. |
| **Base-rate comparison required** | Cheung (arXiv:2607.12248) is why `validation/baselines.py` exists. |

## Config is frozen and central

**Every constant that affects a reported number lives in `rgx/config.py`.** If you
find yourself about to hardcode a threshold anywhere else, stop — that is the exact
failure mode arXiv:2603.20319 describes, and this project centralised config
specifically to prevent it.

Notable values: `MIN_MARKET_CAP = 2.0e9` / `MAX_MARKET_CAP = 200.0e9` ·
`MIN_DOLLAR_VOLUME = 5.0e6` · `FORWARD_RETURN_DAYS = 20` · `MOM_LONG/SKIP/SHORT =
252/21/21` (12-1 momentum, skipping the last month to avoid short-term reversal) ·
`DECILE_CUT = 0.10` · `TARGET_ANNUAL_VOL = 0.12` · `KELLY_FRACTION = 0.25`
(quarter-Kelly) · `MAX_ADV_PARTICIPATION = 0.02` (never take more than 2% of a day's
dollar volume) · `TRAIN_YEARS = 5` / `TEST_MONTHS = 6` / `EMBARGO_DAYS = 10` ·
`MARKET_DRIFT = 0.0` (frozen — a nonzero value re-introduced a beta-only rankable
edge in the null arm; see the mechanism in `config.py:101-112`) ·
`COST_SENSITIVITY_BPS = (2, 5, 10, 25, 50, 100)`.

## How to run

```bash
cd projects/rgx
.venv/bin/python -m rgx.pipeline planted   # injected edge exists
.venv/bin/python -m rgx.pipeline null      # control — must find nothing
```

`__main__` takes the edge string as `argv[1]` and defaults to `"planted"`. Output is
a formatted report from `format_report(...)`.

**The default config is 800 names × 2510 days (~10 years) and it is slow — minutes,
not seconds.** It is CPU-bound on LightGBM. Run it in the background; do not poll.

## Traps that will bite you

- **`run_evaluation` raises `RuntimeError` if no walk-forward folds fit.** With
  `TRAIN_YEARS = 5` you need roughly 5×252 + 126 test days + embargo. A short panel
  (`n_days` ≈ 760) raises `no walk-forward folds fit in N dates at 5y train`. **This
  is validation working correctly, not a bug** — do not "fix" it by shortening the
  train window.
- **`edge="null"` is the control.** If you only ever run `planted`, you are testing
  nothing. Any claim about this harness requires both runs.
- **Reproducibility is `RunConfig.seed`.** `RunConfig` is a frozen dataclass
  serialised alongside results for auditability. Do not introduce ambient
  randomness.
- **Panel convention is `(T, n)`** — dates × names. Transposing silently produces
  plausible-looking nonsense.

## Known gaps — do not assume otherwise

- **Two suites, and only one runs by default.** `tests/test_invariants.py`
  (47 tests) guards component contracts — look-ahead, NaN preservation, split
  embargoes, cost monotonicity, DSR units. `tests/test_null_control.py`
  (4 `def test_`, parametrized to 6) **does** exercise `run_evaluation`
  end-to-end on both arms — but it is gated behind `RGX_SLOW=1` because each
  run costs a full LightGBM fit.
- **The default `pytest tests/` does NOT prove the central invariant.** It
  reports `47 passed, 6 skipped`, and those 6 skips *are* the null control.
  Any claim about the harness's verdict logic requires
  `RGX_SLOW=1 .venv/bin/python -m pytest tests/ -q` → **53 passed**. Quoting
  the fast number as evidence the pipeline can return nothing is quoting a
  test that never ran.
- **No CLI beyond `__main__`.** No argument parsing, no config file, no
  hyperparameters exposed.
- **Synthetic data only.** The entire result set is a control experiment against
  generated panels. Nothing here demonstrates edge on real markets, and no output
  from this code should be presented as if it did.