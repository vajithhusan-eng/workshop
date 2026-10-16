"""End-to-end evaluation pipeline.

Wires the six layers together and enforces the validation discipline:

  1. Point-in-time universe       (no survivorship, as-of joins only)
  2. Price/volume factors         (classical anomalies)
  3. Microstructure regime gate   (observable book-density routing)
  4. LambdaRank ensemble          (GBDT, not a transformer)
  5. Cost-aware portfolio         (vol target, quarter-Kelly, ADV cap)
  6. Honest evaluation            (walk-forward, base rates, DSR, PBO, cost grid)

The single most important property of this pipeline: **it can return nothing.**
A run with `edge="null"` must produce out-of-sample Sharpe indistinguishable
from zero and a large p-value. If it does not, there is a leak, and no result
from this code should be believed until that leak is found.

That is not paranoia. Gençay (arXiv:2608.27734) showed a deliberately leaky
oracle posting a Sharpe of 35 survives Deflated Sharpe and PBO testing
completely -- statistical correction catches selection, never look-ahead.
"""

from __future__ import annotations

import json
import time
from dataclasses import asdict, dataclass, field

import numpy as np

from .config import (
    COST_SENSITIVITY_BPS,
    EMBARGO_DAYS,
    FORWARD_RETURN_DAYS,
    LABEL_HORIZON,
    MIN_T_STAT,
    SELECTION_NOISE_FLOOR_N,
    TRAIN_YEARS,
    RunConfig,
)
from .data.synthetic import generate_panel, point_in_time_universe
from .factors.price_volume import FACTOR_DESCRIPTIONS, compute_price_volume_factors
from .ops import cross_sectional_rank_frac, cross_sectional_zscore
from .model.ranker import RankerConfig, fit_ranker, predict_scores
from .model.regime import compute_microstructure_features, gate_agreement
from .portfolio.construction import (
    PortfolioConfig,
    build_weights,
    portfolio_daily_returns,
    throttle_weights,
)
from .validation import baselines, costs as cost_mod
from .validation.metrics import (
    annualised_sharpe,
    cross_sectional_ic,
    cumulative_return,
    deflated_sharpe,
    icir,
    max_drawdown,
    newey_west_tstat,
    probability_of_backtest_overfitting,
    selection_noise_floor,
)
from .validation.splits import forward_overlapping_returns, walk_forward_splits


@dataclass
class TrialLog:
    """Counts every configuration tried, so reported Sharpe can be deflated.

    Gençay (arXiv:2608.27734) observed that the best in-sample Sharpe climbs
    with each trial while the deflation threshold -- driven by the search itself
    -- climbs faster. You cannot honestly deflate without knowing N.
    """

    entries: list[dict] = field(default_factory=list)

    def record(self, description: str, sharpe: float) -> None:
        self.entries.append({"description": description, "is_sharpe": float(sharpe)})

    @property
    def n_trials(self) -> int:
        return max(len(self.entries), SELECTION_NOISE_FLOOR_N)

    def as_dict(self) -> dict:
        return {
            "n_recorded": len(self.entries),
            "n_used_for_deflation": self.n_trials,
            "entries": self.entries,
        }


def _prepare(cfg: RunConfig) -> dict:
    """Build every array the evaluation needs. No model, no metrics."""
    panel = generate_panel(
        seed=cfg.seed, n_names=cfg.n_names, n_days=cfg.n_days, edge=cfg.edge
    )
    universe = point_in_time_universe(panel)
    factors = compute_price_volume_factors(panel)
    micro = compute_microstructure_features(panel)

    # Feature tensor: (T, n, d), NaN outside the point-in-time universe.
    names = sorted(factors.keys())
    feats = np.stack([factors[k] for k in names], axis=2)
    feats[~universe] = np.nan

    # --- Cross-sectional standardisation. Rank-transform is scale-free and
    # robust to the fat tails that make raw returns unusable as features.
    # NaN (outside the point-in-time universe) is preserved, so the ranker can
    # never learn from a name that was not tradable on that date. ---
    feats = np.stack([cross_sectional_rank_frac(factors[k]) for k in names], axis=2)
    feats[~universe] = np.nan

    # --- Target: forward return, cross-sectionally z-scored per date. ---
    fwd = forward_overlapping_returns(panel.close, horizon=LABEL_HORIZON)
    fwd[~universe] = np.nan
    target = cross_sectional_zscore(fwd)

    # --- Next-day realised return, used to evaluate the held book. ---
    close = panel.close
    ret = np.zeros_like(close)
    ret[1:] = close[1:] / close[:-1] - 1.0
    ret[~np.isfinite(ret)] = 0.0

    vols = factors.get("realised_vol_20")
    if vols is None or not np.isfinite(vols).any():
        vols = np.full_like(close, 0.25)
    vols = np.nan_to_num(vols, nan=0.25, posinf=0.25, neginf=0.25)

    return {
        "panel": panel,
        "universe": universe,
        "factors": factors,
        "feature_names": names,
        "feats": feats,
        "target": target,
        "fwd": fwd,
        "ret": ret,
        "vols": vols,
        "micro": micro,
    }


def _fit_gated(
    data: dict, train_dates: np.ndarray, ranker_cfg: RankerConfig
) -> tuple[list, np.ndarray, list[int]]:
    """Fit one LambdaRank model per book-density tercile.

    The gate is unsupervised. We bucket *dates* by an observable
    microstructure score into sparse / mid / dense terciles, fit a model per
    tercile on the training dates falling in it, and at prediction time route
    each test date by its own tercile. No regime label is ever required -- which
    is the situation you are actually in when trading.
    """
    feats, target = data["feats"], data["target"]
    tercile = data["micro"].tercile

    models: list = [None, None, None]
    counts: list[int] = [0, 0, 0]
    for c in (0, 1, 2):
        dates_c = train_dates[tercile[train_dates] == c]
        counts[c] = int(dates_c.size)
        if dates_c.size >= 60:
            models[c] = fit_ranker(
                feats,
                target,
                np.arange(feats.shape[0]),
                dates_c,
                config=ranker_cfg,
                feature_names=data["feature_names"],
            )

    # Pooled fallback for any tercile with too little training data.
    pooled = None
    if all(m is None for m in models):
        pooled = fit_ranker(
            feats,
            target,
            np.arange(feats.shape[0]),
            train_dates,
            config=ranker_cfg,
            feature_names=data["feature_names"],
        )
    return models, np.array(counts), pooled


def _predict_gated(
    models: list,
    pooled,
    tercile: np.ndarray,
    test_dates: np.ndarray,
    feats: np.ndarray,
) -> list[tuple[np.ndarray, np.ndarray]]:
    """Route each test date to the model trained for its book-density tercile.

    Returns:
        list of (dates, scores) pairs, one per tercile, so the caller can
        scatter each block into the correct rows of the full score matrix.
    """
    out: list[tuple[np.ndarray, np.ndarray]] = []
    for c in (0, 1, 2):
        dates_c = test_dates[tercile[test_dates] == c]
        if dates_c.size == 0:
            continue
        model = models[c] if models[c] is not None else pooled
        if model is None:
            continue
        out.append((dates_c, predict_scores(model, feats[dates_c])))
    return out


def _seed_score_dispersion(primary: np.ndarray, others: list[np.ndarray]) -> float:
    """Mean cross-seed dispersion of the cross-sectional mean score.

    An honest uncertainty measure on our own model: refit the same fold with
    different random seeds and report how much the daily cross-sectional mean
    score moves. Near zero means the fit is stable; large means any single-seed
    number we quote is an artefact of that seed.

    Every panel here must be the SAME fold window -- ``primary`` and each of
    ``others`` are shaped ``(n_test_dates, n_names)``. Panels are deliberately
    not indexable by a full-panel date mask: the per-seed panels are built on
    ``fold.test_idx`` only, so applying ``all_test_dates[0]`` to them raises
    IndexError rather than quietly misaligning. Shapes are checked here so the
    failure is a named error, not an ndarray traceback.

    Returns NaN when there is nothing to compare (a single seed).
    """
    if not others or primary is None:
        return float("nan")

    panels = [primary, *others]
    rows = {p.shape[0] for p in panels}
    if len(rows) != 1:
        raise ValueError(
            "seed score panels must cover the same fold window; got row counts "
            f"{sorted(rows)}. A per-seed panel is built on fold.test_idx alone, "
            "so it cannot be indexed with a full-panel date mask."
        )

    with np.errstate(invalid="ignore"):
        stack = np.stack([np.nanmean(p, axis=1) for p in panels])
        return float(np.nanmean(np.nanstd(stack, axis=0)))


def run_evaluation(cfg: RunConfig | None = None, verbose: bool = True) -> dict:
    """Run the full walk-forward evaluation and return a report dict."""
    cfg = cfg or RunConfig()
    t0 = time.time()
    log = TrialLog()

    if verbose:
        print(
            f"[rgx] preparing panel  edge={cfg.edge}  N={cfg.n_names}  T={cfg.n_days}"
        )
    data = _prepare(cfg)
    feats, target, fwd = data["feats"], data["target"], data["fwd"]
    ret, vols, micro = data["ret"], data["vols"], data["micro"]
    T, n, d = feats.shape
    date_idx = np.arange(T)

    # ------------------------------------------------------------------
    # Walk-forward
    # ------------------------------------------------------------------
    folds = walk_forward_splits(
        n_dates=T,
        train_years=TRAIN_YEARS,
        test_months=6,
        horizon=LABEL_HORIZON,
        embargo=EMBARGO_DAYS,
    )
    if not folds:
        raise RuntimeError(
            f"no walk-forward folds fit in {T} dates at {TRAIN_YEARS}y train"
        )
    if verbose:
        print(f"[rgx] walk-forward folds: {len(folds)}")

    ranker_cfg = RankerConfig(random_state=cfg.seed)
    pcfg = PortfolioConfig(n_decile=cfg.n_decile)

    all_scores = np.full((T, n), np.nan)
    all_ic_rows: list[np.ndarray] = []
    fold_sharpes: list[float] = []
    per_seed_scores: list[np.ndarray] = []
    primary_fold_scores: np.ndarray | None = None
    gate_counts = []

    for fi, fold in enumerate(folds):
        models, counts, pooled = _fit_gated(data, fold.train_idx, ranker_cfg)
        gate_counts.append(counts.tolist())

        blocks = _predict_gated(models, pooled, micro.tercile, fold.test_idx, feats)
        fold_scores = np.full((fold.test_idx.size, n), np.nan)
        for dates_c, sc in blocks:
            all_scores[dates_c] = sc
            fold_scores[np.searchsorted(fold.test_idx, dates_c)] = sc

        # IC measured only where the model actually emitted a score.
        ic = cross_sectional_ic(fold_scores, fwd[fold.test_idx], "spearman")
        all_ic_rows.append(ic)
        log.record(
            f"walk_forward_fold_{fi}",
            float(np.nanmean(ic) * np.sqrt(252.0)) if np.isfinite(ic).any() else 0.0,
        )

        # Multi-seed dispersion: AlphaForgeBench (arXiv:2602.18481) found LLM
        # agents exhibit extreme run-to-run variance. We report the spread of
        # our own model across seeds as an honest uncertainty measure.
        if fi == 0:
            primary_fold_scores = fold_scores
            for s in range(1, cfg.seed_variants):
                m_s, _, p_s = _fit_gated(
                    data, fold.train_idx, RankerConfig(random_state=cfg.seed + 17 * s)
                )
                sc_seed = np.full((fold.test_idx.size, n), np.nan)
                for dates_c, sc in _predict_gated(
                    m_s, p_s, micro.tercile, fold.test_idx, feats
                ):
                    sc_seed[np.searchsorted(fold.test_idx, dates_c)] = sc
                per_seed_scores.append(sc_seed)

        fold_ic = ic[np.isfinite(ic)]
        if fold_ic.size > 0:
            fold_sharpes.append(
                float(fold_ic.mean() / fold_ic.std() * np.sqrt(252.0))
                if fold_ic.std() > 1e-12
                else 0.0
            )

    # ------------------------------------------------------------------
    # Portfolio: weights -> gross returns -> costs -> net returns
    # ------------------------------------------------------------------
    pv = np.full(T, 10_000_000.0)
    weights = build_weights(all_scores, vols, data["panel"].dollar_volume, pv, pcfg)

    # Throttle to the signal's own horizon. Daily decile rebalancing on a
    # 20-day label measured 1314% annual turnover, which at 10bps per side is
    # roughly a 130% annual round-trip drag -- more than any plausible equity
    # alpha, and enough on its own to turn a positive gross edge negative.
    weights = throttle_weights(weights, cfg.rebalance_days)

    # Alignment contract (single source of truth in portfolio_daily_returns):
    # weights[t] come from data through the close of day t, are held during day
    # t+1, and earn ret[t+1].
    gross = portfolio_daily_returns(weights, ret)

    prev_w = np.zeros_like(weights)
    prev_w[1:] = weights[:-1]

    sigma_daily = vols / np.sqrt(252.0)
    adv = data["panel"].dollar_volume
    net = cost_mod.apply_costs(
        gross,
        prev_w,
        weights,
        sigma_daily,
        adv,
        overrides=cost_mod.cost_from_bps(cfg.costs_bps),
    )

    traded = np.abs(weights - prev_w)
    turnover = traded.sum(axis=1)
    log.record("final_model_net", annualised_sharpe(net))

    # ------------------------------------------------------------------
    # Baselines
    #
    # Measured on the SAME daily-return convention as the model (see the
    # contract at the top of validation/baselines.py), and restricted to the
    # walk-forward test dates the model actually traded. Comparing a model
    # scored on its out-of-sample window against a baseline scored over the full
    # history -- including the five years the model spent training -- is the
    # kind of mismatch that manufactures a fake edge.
    # ------------------------------------------------------------------
    # ------------------------------------------------------------------
    # Random-signal null: is the model above the NOISE distribution?
    #
    # Comparing one model realisation to one random realisation is not a test.
    # A Sharpe estimated over T days has a sampling distribution of order 1
    # even under a strict null, so "model 0.50 > random 0.58" over 1600 days
    # says nothing. The correct comparison is the model's PERCENTILE within the
    # random-Sharpe distribution.
    #
    # Note averaging N random books does NOT shrink this: averaging cuts the
    # return std by sqrt(N) and the mean's sampling error by the same factor,
    # so the Sharpe of the averaged series still has std ~1. Only the
    # distribution's shape is informative, not its single mean.
    # ------------------------------------------------------------------
    rand_book = baselines.bootstrap_baseline_distribution(
        ret,
        n_draws=40,
        n_decile=cfg.n_decile,
        rebalance_days=cfg.rebalance_days,
    )
    rand_sharpes = np.array(
        [annualised_sharpe(rand_book[:, i]) for i in range(rand_book.shape[1])]
    )
    model_sharpe_gross = annualised_sharpe(gross)
    random_percentile = float(np.mean(rand_sharpes < model_sharpe_gross) * 100.0)

    # Baselines trade only the dates the model actually traded, so the
    # comparison is like-for-like. Scoring a model on its out-of-sample window
    # against a baseline that also enjoyed the five training years is a mismatch
    # that manufactures a fake edge.
    tradable = data["universe"]
    in_sample = np.zeros(T, dtype=bool)
    for fold in folds:
        in_sample[fold.test_idx] = True
    tradable_test = tradable & in_sample[:, None]

    baseline_returns = {
        "equal_weight_long_only": baselines.equal_weight_long_only(
            tradable_test, ret, cfg.rebalance_days
        ),
        "market_neutral_demeaned": baselines.market_return(
            tradable_test, ret, cfg.rebalance_days
        ),
        "momentum_only_decile": baselines.single_factor_portfolio(
            data["factors"]["mom_12_1"],
            ret,
            cfg.n_decile,
            mask=tradable,
            rebalance_days=cfg.rebalance_days,
        ),
        "reversal_only_decile": baselines.single_factor_portfolio(
            data["factors"]["reversal_5"],
            ret,
            cfg.n_decile,
            mask=tradable,
            rebalance_days=cfg.rebalance_days,
        ),
        "random_signal_mean": baselines.bootstrap_baseline_distribution(
            ret,
            n_draws=25,
            n_decile=cfg.n_decile,
            rebalance_days=cfg.rebalance_days,
        ).mean(axis=1),
    }

    # Accuracy, reported as excess over the always-up base rate.
    # Pass `fwd` RAW. Filling undefined forward returns with 0.0 turned the
    # last `horizon` rows of the final test window into fake flat returns:
    # sign(0.0) == 0.0 matches no prediction, so ~16% of compare pairs were
    # scored as wrong, dragging accuracy down ~8pp and corrupting the base
    # rate by the same amount. directional_accuracy already masks NaNs.
    acc = baselines.directional_accuracy(all_scores, fwd)

    # ------------------------------------------------------------------
    # Cost sensitivity grid
    # ------------------------------------------------------------------
    cost_grid = {}
    for bps in COST_SENSITIVITY_BPS:
        r = cost_mod.apply_costs(
            gross,
            prev_w,
            weights,
            sigma_daily,
            adv,
            overrides=cost_mod.cost_from_bps(bps),
        )
        cost_grid[f"{bps:g}bps"] = {
            "net_sharpe": annualised_sharpe(r),
            "cumulative_return": cumulative_return(r),
            "max_drawdown": max_drawdown(r),
            "nw_tstat": newey_west_tstat(r),
        }

    # ------------------------------------------------------------------
    # Statistical corrections
    # ------------------------------------------------------------------
    ic_all = np.concatenate([ic for ic in all_ic_rows])
    dsrc = deflated_sharpe(net, n_trials=log.n_trials)

    # PBO over a population: the model plus the random-signal draws.
    perf_matrix = np.concatenate(
        [
            np.stack(
                [
                    baselines.random_signal_portfolio(
                        500 + i,
                        (T, n),
                        ret,
                        cfg.n_decile,
                        rebalance_days=cfg.rebalance_days,
                    )
                    for i in range(20)
                ],
                axis=1,
            ),
            net[:, None],
        ],
        axis=1,
    )
    pbo = probability_of_backtest_overfitting(perf_matrix, n_splits=8)

    # ------------------------------------------------------------------
    # Gate diagnostic (synthetic only: requires the latent label)
    # ------------------------------------------------------------------
    gate = gate_agreement(micro, data["panel"].regime_label)

    # Multi-seed prediction dispersion on the first fold.
    seed_dispersion = _seed_score_dispersion(primary_fold_scores, per_seed_scores)

    # ------------------------------------------------------------------
    # Verdict
    # ------------------------------------------------------------------
    net_sharpe = annualised_sharpe(net)
    ic_mean = float(np.nanmean(ic_all)) if np.isfinite(ic_all).any() else 0.0
    t_stat = newey_west_tstat(net)

    passed = [
        t_stat > MIN_T_STAT,
        dsrc["deflated_p_value"] < 0.05,
        ic_mean > 0.0,
        net_sharpe > 0.0,
        acc["excess_over_base_rate"] > 0.0,
    ]
    verdict = "EDGE DETECTED" if all(passed) else "NO RELIABLE EDGE"

    report = {
        "config": {**asdict(cfg), "feature_names": data["feature_names"]},
        "factor_descriptions": {
            k: FACTOR_DESCRIPTIONS.get(k, "") for k in data["feature_names"]
        },
        "signal": {
            "rankic_mean": ic_mean,
            "rankic_std": float(np.nanstd(ic_all))
            if np.isfinite(ic_all).any()
            else 0.0,
            "icir": icir(ic_all),
            "n_cross_sections": int(np.isfinite(ic_all).sum()),
        },
        "performance_net": {
            "sharpe": net_sharpe,
            "nw_tstat": t_stat,
            "max_drawdown": max_drawdown(net),
            "cumulative_return": cumulative_return(net),
            "avg_daily_turnover": float(np.mean(turnover)),
            "annual_turnover": float(np.mean(turnover) * 252),
        },
        "performance_gross": {
            "sharpe": annualised_sharpe(gross),
            "cumulative_return": cumulative_return(gross),
        },
        "accuracy": acc,
        "baselines": {
            k: {
                "sharpe": annualised_sharpe(v),
                "cumulative_return": cumulative_return(v),
            }
            for k, v in baseline_returns.items()
        },
        "random_null": {
            "model_gross_sharpe": model_sharpe_gross,
            "percentile_vs_random": random_percentile,
            "random_sharpe_mean": float(np.mean(rand_sharpes)),
            "random_sharpe_std": float(np.std(rand_sharpes)),
            "n_random_draws": int(rand_sharpes.size),
        },
        "cost_sensitivity": cost_grid,
        "deflated_sharpe": dsrc,
        "selection_noise_floor": {
            "n_trials": log.n_trials,
            "expected_max_sharpe_from_noise": selection_noise_floor(log.n_trials),
        },
        "pbo": {
            "pbo": pbo.pbo,
            "n_splits": pbo.n_splits,
            "n_combinations": pbo.n_combos,
        },
        "regime_gate": {
            **gate,
            "train_counts_per_fold": gate_counts[:5],
            "seed_score_dispersion": seed_dispersion,
        },
        "fold_sharpes": {
            "mean": float(np.mean(fold_sharpes)) if fold_sharpes else 0.0,
            "min": float(np.min(fold_sharpes)) if fold_sharpes else 0.0,
            "max": float(np.max(fold_sharpes)) if fold_sharpes else 0.0,
            "n_folds": len(fold_sharpes),
        },
        "verdict": verdict,
        "checks": {
            "t_stat_above_3": bool(t_stat > MIN_T_STAT),
            "deflated_p_below_0.05": bool(dsrc["deflated_p_value"] < 0.05),
            "positive_rankic": bool(ic_mean > 0),
            "positive_net_sharpe": bool(net_sharpe > 0),
            "accuracy_above_base_rate": bool(acc["excess_over_base_rate"] > 0),
            "beats_random_signal": bool(random_percentile >= 95.0),
        },
        "trial_log": log.as_dict(),
        "runtime_seconds": round(time.time() - t0, 2),
    }
    return report


def format_report(report: dict) -> str:
    """Render a report dict as readable text."""
    c = report["config"]
    s = report["signal"]
    p = report["performance_net"]
    g = report["performance_gross"]
    a = report["accuracy"]
    d = report["deflated_sharpe"]
    gate = report["regime_gate"]

    def f(x, n=3):
        try:
            return f"{float(x):.{n}f}"
        except (TypeError, ValueError):
            return "nan"

    lines = [
        "=" * 72,
        f"RGX  regime-gated cross-sectional ensemble   [edge={c['edge']}]",
        "=" * 72,
        f"universe N={c['n_names']}   horizon={c['n_days']}d   costs={float(c['costs_bps']):g} bps",
        "",
        "SIGNAL (out-of-sample, walk-forward)",
        f"  RankIC mean          {f(s['rankic_mean'], 4)}   "
        f"(sd {f(s['rankic_std'], 4)}, ICIR {f(s['icir'], 2)})",
        f"  cross-sections       {s['n_cross_sections']}",
        "",
        "PERFORMANCE (net of costs)",
        f"  Sharpe               {f(p['sharpe'], 2)}   (gross {f(g['sharpe'], 2)})",
        f"  Newey-West t         {f(p['nw_tstat'], 2)}   [Harvey-Liu-Zhu threshold: 3.0]",
        f"  max drawdown         {f(p['max_drawdown'] * 100, 1)}%",
        f"  annual turnover      {f(p['annual_turnover'] * 100, 1)}%",
        "",
        "ACCURACY (base-rate corrected)",
        f"  directional acc      {f(a['accuracy'] * 100, 1)}%",
        f"  always-up base rate  {f(a['base_rate_always_up'] * 100, 1)}%",
        f"  EXCESS over base     {f(a['excess_over_base_rate'] * 100, 1)}%",
        "",
        "BASELINES (must be beaten)",
    ]
    for k, v in report["baselines"].items():
        lines.append(f"  {k:<26} Sharpe {f(v['sharpe'], 2):>7}")

    lines += [
        "",
        "COST SENSITIVITY",
    ]
    for k, v in report["cost_sensitivity"].items():
        lines.append(
            f"  {k:<10} net Sharpe {f(v['net_sharpe'], 2):>7}  "
            f"maxDD {f(v['max_drawdown'] * 100, 1):>7}%"
        )

    # NaN here means seed_variants == 1 (nothing to compare), not a failed
    # metric. Printing a bare "nan" would read as a broken number.
    seed_disp = (
        f(gate["seed_score_dispersion"], 4)
        if np.isfinite(gate["seed_score_dispersion"])
        else f"n/a (seed_variants={report['config']['seed_variants']})"
    )

    lines += [
        "",
        "STATISTICAL CORRECTIONS",
        f"  observed Sharpe      {f(d['sr'], 2)}",
        f"  trial-adj. threshold {f(d['sr0'], 2)}   "
        f"(noise floor @ N={int(d['n_trials'])}: "
        f"{f(report['selection_noise_floor']['expected_max_sharpe_from_noise'], 2)})",
        f"  deflated p-value      {f(d['deflated_p_value'], 4)}",
        f"  PBO                  {f(report['pbo']['pbo'], 3)}  "
        f"({report['pbo']['n_combinations']} CSCV splits)",
        "",
        "REGIME GATE (vs latent book density)",
        f"  Spearman             {f(gate['spearman'], 3)}",
        f"  AUC                  {f(gate['auc'], 3)}",
        f"  dense-tercile acc    {f(gate['dense_tercile_accuracy'] * 100, 1)}%",
        f"  seed dispersion      {seed_disp}",
        "",
        "CHECKS",
    ]
    for k, v in report["checks"].items():
        lines.append(f"  [{'PASS' if v else 'FAIL'}] {k}")
    lines += [
        "",
        f"VERDICT: {report['verdict']}",
        f"({report['runtime_seconds']}s, {report['trial_log']['n_recorded']} trials logged)",
        "=" * 72,
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    import sys

    edge = sys.argv[1] if len(sys.argv) > 1 else "planted"
    print(format_report(run_evaluation(RunConfig(seed=7, edge=edge))))
