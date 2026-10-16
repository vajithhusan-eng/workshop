# RGX — Regime-Gated Cross-Sectional Ensemble

A research harness for a multi-signal, microstructure-gated equity factor, built
to be **honest before it is profitable**. The centrepiece is a validation
invariant that must hold: **under a zero-edge null, the pipeline must return no
edge.** If it ever does, the harness is lying and every result is void.

## What this is

- A 6-layer architecture: point-in-time universe → price/volume factors →
  microstructure regime gate → GBDT (LambdaRank) ranker → cost-aware portfolio →
  honest evaluation (purged walk-forward / CPCV splits, base-rate baselines,
  cost sensitivity grid, Newey-West t-stat, Deflated Sharpe Ratio, PBO,
  trial-count deflation, and a random-signal null).
- A deterministic synthetic panel generator with a controllable planted signal,
  so the harness can be power-tested and null-tested without touching markets.

## What it is not

- Not a production trading system. No live brokerage, no real order routing.
- Not a promise of alpha. The null control must always win or the code is wrong.
- Not a transformer. On financial tabular data, gradient-boosted trees have
  repeatedly matched or beaten much larger models on RankIC; attention's
  gains have not survived point-in-time cost-aware evaluation.

## Results (honest, from the synthetic harness)

Measured post-fix at 200×1400 (4 seeds per arm), zero market drift:

| Arm      | Harness RankIC (mean) | Oracle RankIC | Verdict         |
|----------|----------------------|---------------|-----------------|
| null     | +0.0312 (4/4 positive) | —             | `NO RELIABLE EDGE` (correct) |
| planted  | +0.0235               | +0.079…+0.103 | `NO RELIABLE EDGE` |

Both arms correctly report **no reliable edge** (NW t max 2.48 < 3.0, deflated
p min ≈ 0.75) — the null control does not manufacture a false positive, which is
the project's central invariant. **What is NOT yet demonstrated is separation**:
at these panel sizes the null arm reads *higher* than the planted arm, because
the synthetic null panel carries rankable variance structure (vol/turnover
factors show +0.025…+0.040 IC with 4/4 seed signs on the null; see `STATE.md`).
The oracle signal is recoverable in principle (+0.079…+0.103 RankIC, tested at
generator level), but the pipeline does not yet extract it at 200×1400.

## Run it

```bash
cd projects/rgx
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
pytest                      # 47 invariant tests, ~4s
RGX_SLOW=1 pytest            # + 6 slow end-to-end null-control tests, ~55s
.venv/bin/python -m rgx.pipeline null      # control — must find nothing
.venv/bin/python -m rgx.pipeline planted   # injected edge exists
```

`run_evaluation` takes a `RunConfig`, not an edge string. The CLI above is the
supported entry point; to vary the panel size, construct the config yourself:

```python
from rgx.config import RunConfig
from rgx.pipeline import run_evaluation, format_report

print(format_report(run_evaluation(
    RunConfig(seed=3, n_names=300, n_days=1600, edge="planted")
)))
```

## Files

- `rgx/config.py` — constants (cost model, label horizon, decile, turnover)
- `rgx/ops.py` — vectorised cross-sectional primitives
- `rgx/data/synthetic.py` — seeded panel generator, planted vs null
- `rgx/factors/price_volume.py` — 9 classical factors
- `rgx/model/regime.py` — microstructure gate + its observable diagnostics
- `rgx/model/ranker.py` — LightGBM LambdaRank
- `rgx/portfolio/construction.py` — weights, vol target, Kelly, ADV cap
- `rgx/validation/` — costs, metrics, splits, baselines
- `rgx/pipeline.py` — orchestration + formatted report
- `tests/test_invariants.py` — invariant suite (47 tests)
- `tests/test_null_control.py` — end-to-end null/planted pipeline + oracle power (6 slow tests, `RGX_SLOW=1`)

## Cost model

Default fixed cost ≈ 5 bps + 10 bps impact per side (tunable
`COST_SENSITIVITY_BPS`). A strategy whose edge is smaller than the cost of
turnover has no edge. We report a grid, not a point, because the "true" cost is
a distribution.

## Limitations (stated, not buried)

- At 200×1400 the harness does **not** demonstrate planted-vs-null separation
  (null +0.0312 vs planted +0.0235) — the oracle itself is only +0.079…+0.103.
  Separation is the central open question; see `STATE.md`.
- Cost grid flattens above 25 bps (participation/impact saturates) — see
  `STATE.md`.
- The regime gate shows a 0.316 Spearman / 0.686 AUC lift against latent
  regime on synthetic data, but real persistence has not been measured.
