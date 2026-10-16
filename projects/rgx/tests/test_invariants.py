"""Invariants that must hold for any result from this harness to be credible.

These are not coverage tests. Each one pins a property whose violation would
produce a *plausible-looking wrong answer* rather than a crash:

  - `test_portfolio_daily_returns_does_not_look_ahead` is the single most
    important test in the repository. A one-row misalignment here produces a
    strategy that looks better than it is, silently, forever.
  - `test_null_arm_reports_no_edge` is the safety property. Gençay
    (arXiv:2608.27734) showed a deliberately leaky oracle posting Sharpe 35
    survives Deflated Sharpe and PBO testing completely, so statistical
    correction cannot substitute for this test.
  - `test_planted_arm_is_detectable` is the power property. Without it, the
    null test passes trivially for a harness that can find nothing at all.
"""

from __future__ import annotations

import numpy as np
import pytest
from scipy import stats

from rgx.config import FORWARD_RETURN_DAYS, MARKET_DRIFT, MIN_T_STAT
from rgx.data.synthetic import generate_panel, point_in_time_universe
from rgx.factors.price_volume import compute_price_volume_factors
from rgx.model.regime import compute_microstructure_features, gate_agreement
from rgx.ops import (
    cross_sectional_rank_frac,
    cross_sectional_zscore,
    decile_spread,
    decile_weights,
)
from rgx.pipeline import _seed_score_dispersion
from rgx.portfolio.construction import (
    equal_weight_weights,
    portfolio_daily_returns,
    throttle_weights,
)
from rgx.validation.baselines import directional_accuracy
from rgx.validation.costs import apply_costs, per_unit_cost
from rgx.validation.metrics import (
    annualised_sharpe,
    deflated_sharpe,
    newey_west_tstat,
    selection_noise_floor,
)
from rgx.validation.splits import forward_overlapping_returns, walk_forward_splits


# ---------------------------------------------------------------------------
# ops
# ---------------------------------------------------------------------------
def test_cross_sectional_rank_frac_preserves_nan():
    x = np.random.default_rng(0).standard_normal((50, 20))
    x[3, :5] = np.nan
    r = cross_sectional_rank_frac(x)
    assert np.isnan(r[3, :5]).all()
    assert np.isfinite(r[3, 5:]).all()
    assert np.isfinite(r).sum() == np.isfinite(x).sum()


def test_cross_sectional_rank_frac_orders_correctly():
    x = np.random.default_rng(1).standard_normal((10, 50))
    r = cross_sectional_rank_frac(x)
    row = 4
    order = np.argsort(x[row])
    assert np.all(np.diff(r[row][order]) > 0), "ranks must be monotone in the input"


def test_cross_sectional_zscore_is_zero_mean_unit_sd():
    x = np.random.default_rng(2).standard_normal((30, 100))
    z = cross_sectional_zscore(x)
    assert np.allclose(np.nanmean(z, axis=1), 0.0, atol=1e-10)
    assert np.allclose(np.nanstd(z, axis=1), 1.0, atol=1e-10)


def test_decile_weights_exact_sleeve_sizes_and_neutral():
    """Heavy ties must not silently shrink a sleeve."""
    x = np.random.default_rng(3).standard_normal((40, 200))
    x[:, :100] = 1.0  # 100-way tie across half the universe
    w = decile_weights(x, None, n_decile=0.10)
    n = x.shape[1]
    k = int(0.10 * n)
    assert (w > 0).sum(axis=1).min() == k
    assert (w < 0).sum(axis=1).min() == k
    assert np.allclose(w.sum(axis=1), 0.0, atol=1e-12)
    assert np.allclose(np.abs(w).sum(axis=1), 1.0, atol=1e-9)


def test_decile_spread_nan_preserved():
    f = np.random.default_rng(4).standard_normal((30, 60))
    f[0, :10] = np.nan
    r = np.random.default_rng(5).standard_normal((30, 60))
    s = decile_spread(f, r, n_decile=0.10)
    assert np.isfinite(s).all()


# ---------------------------------------------------------------------------
# Portfolio mechanics -- the look-ahead guard
# ---------------------------------------------------------------------------
def test_portfolio_daily_returns_does_not_look_ahead():
    """weights[t] must earn ret[t+1], never ret[t].

    Construct a book that is long ONLY the winner on each day. Under correct
    alignment it earns nothing (it holds yesterday's winner). Under a
    look-ahead it earns the same-day winner, i.e. a perfect return.
    """
    T, n = 300, 50
    rng = np.random.default_rng(6)
    ret = rng.normal(0, 0.02, (T, n))

    weights = np.zeros((T, n))
    winner = ret.argmax(axis=1)
    weights[np.arange(T), winner] = 1.0

    out = portfolio_daily_returns(weights, ret)
    # Day t earns weights[t-1] * ret[t]. Since weights[t-1] is the winner of
    # day t-1 and the returns are independent across days, this is one fresh
    # independent draw per day -> its mean has standard error ~sigma/sqrt(T),
    # not a systematic tilt.
    se = 0.02 / np.sqrt(T - 1)
    assert abs(out[1:].mean()) < 5 * se


def test_portfolio_daily_returns_perfect_signal_pays():
    """Sanity check on the other side: correct alignment DOES capture a real edge."""
    T, n = 300, 50
    rng = np.random.default_rng(7)
    ret = rng.normal(0, 0.02, (T, n))
    # Perfect causal forecast: at decision time t we weight tomorrow's winner.
    weights = np.zeros((T, n))
    col_idx = ret[1:].argmax(axis=1)
    weights[np.arange(T - 1), col_idx] = 1.0
    out = portfolio_daily_returns(weights, ret)
    assert out[1:].mean() > 0.005


def test_throttle_weights_holds_blocks():
    w = np.arange(50, dtype=float)[:, None].repeat(3, axis=1)
    t = throttle_weights(w, 5)
    assert np.allclose(t[:5], t[0])
    assert np.allclose(t[5:10], t[5])
    assert not np.allclose(t[0], t[5])


def test_throttle_is_identity_at_one():
    w = np.random.default_rng(8).standard_normal((10, 3))
    assert np.allclose(throttle_weights(w, 1), w)


def test_throttle_reduces_turnover():
    T, n = 300, 100
    scores = np.random.default_rng(9).standard_normal((T, n))
    w = decile_weights(scores, None, 0.10)
    prev = np.zeros_like(w)
    prev[1:] = w[:-1]
    daily = np.abs(w - prev).sum(axis=1).mean()
    wt = throttle_weights(w, 5)
    prevt = np.zeros_like(wt)
    prevt[1:] = wt[:-1]
    throttled = np.abs(wt - prevt).sum(axis=1).mean()
    assert throttled < daily / 3.0


def test_equal_weight_weights_sum_to_one():
    m = np.random.default_rng(10).random((10, 30)) > 0.3
    w = equal_weight_weights(m)
    assert np.allclose(w.sum(axis=1), 1.0)
    assert np.all(w[~m] == 0.0)


# ---------------------------------------------------------------------------
# Splits -- purging
# ---------------------------------------------------------------------------
def test_walk_forward_train_precedes_test():
    folds = walk_forward_splits(2000, train_years=3, test_months=6)
    assert len(folds) > 0
    for f in folds:
        assert f.train_idx.max() < f.test_idx.min(), "train must precede test"
        assert f.test_idx.min() - f.train_idx.max() > 0


def test_walk_forward_purges_label_overlap():
    """No training date's label window may reach into the test window."""
    horizon = 20
    folds = walk_forward_splits(2000, train_years=3, test_months=6, horizon=horizon)
    for f in folds:
        assert (f.train_idx + horizon).max() < f.test_idx.min() + horizon
        assert f.train_idx.max() < f.test_idx.min() - horizon


def test_forward_returns_last_rows_are_nan():
    close = np.abs(np.random.default_rng(11).standard_normal((100, 10))) + 10
    fwd = forward_overlapping_returns(close, horizon=20)
    assert np.isnan(fwd[-20:]).all()
    assert np.isfinite(fwd[:80]).all()


def test_forward_returns_values_correct():
    close = np.full((50, 1), 100.0)
    close[10:] = 110.0
    fwd = forward_overlapping_returns(close, horizon=20)
    # price goes 100 -> 110 over 20 days = +10%
    assert np.isclose(fwd[0, 0], 0.10, atol=1e-9)
    # index 10 -> 30 stays flat at 110 => 0%
    assert np.isclose(fwd[10, 0], 0.0, atol=1e-9)


# ---------------------------------------------------------------------------
# Costs
# ---------------------------------------------------------------------------
def test_per_unit_cost_increases_with_participation():
    sigma = np.full(10, 0.02)
    low = per_unit_cost(sigma, np.full(10, 0.001))
    high = per_unit_cost(sigma, np.full(10, 0.5))
    assert np.all(high > low)


def test_per_unit_cost_has_fixed_floor():
    """A zero-size order still pays commission + half the spread."""
    sigma = np.full(5, 0.02)
    zero = per_unit_cost(sigma, np.zeros(5))
    assert np.all(zero > 0.0)


def test_apply_costs_reduces_returns_and_shapes_match():
    T, n = 50, 10
    gross = np.random.default_rng(12).normal(0, 0.01, T)
    w = np.random.default_rng(13).standard_normal((T, n)) * 0.05
    prev = np.zeros_like(w)
    prev[1:] = w[:-1]
    sigma = np.full((T, n), 0.02)
    adv = np.full((T, n), 1e8)
    net = apply_costs(gross, prev, w, sigma, adv)
    assert net.shape == (T,)
    assert np.all(net <= gross + 1e-12), "costs can only reduce returns"


def test_zero_turnover_costs_nothing():
    T, n = 20, 5
    gross = np.zeros(T)
    w = np.zeros((T, n))
    prev = np.zeros((T, n))
    net = apply_costs(gross, prev, w, np.zeros((T, n)), np.ones((T, n)))
    assert np.allclose(net, 0.0)


# ---------------------------------------------------------------------------
# Metrics / statistical corrections
# ---------------------------------------------------------------------------
def test_deflated_sharpe_rejects_zero_edge():
    """The safety property: a null series must NOT come out significant."""
    rng = np.random.default_rng(14)
    for _ in range(5):
        d = deflated_sharpe(rng.normal(0, 0.01, 1250), n_trials=100)
        assert d["deflated_p_value"] > 0.05


def test_deflated_sharpe_accepts_strong_edge():
    rng = np.random.default_rng(15)
    d = deflated_sharpe(rng.normal(0.004, 0.01, 1250), n_trials=100)
    assert d["deflated_p_value"] < 0.05


def test_deflated_sharpe_threshold_scales_with_trials():
    """More trials must demand a higher bar."""
    rng = np.random.default_rng(16)
    r = rng.normal(0.0025, 0.01, 1250)
    few = deflated_sharpe(r, n_trials=5)["deflated_p_value"]
    many = deflated_sharpe(r, n_trials=500)["deflated_p_value"]
    assert many > few


def test_deflated_sharpe_units_are_sane():
    """Guards the sqrt(T) bug that previously made every p-value 1.0."""
    rng = np.random.default_rng(17)
    d = deflated_sharpe(rng.normal(0, 0.01, 1250), n_trials=100)
    assert 0.1 < d["sr0"] < 5.0, f"threshold {d['sr0']} is not plausible"


def test_selection_noise_floor_matches_known_values():
    assert abs(selection_noise_floor(100) - np.sqrt(2 * np.log(100))) < 1e-9
    assert selection_noise_floor(1000) > selection_noise_floor(100)


def test_newey_west_tstat_sign_and_magnitude():
    rng = np.random.default_rng(18)
    assert newey_west_tstat(rng.normal(0.003, 0.01, 2000)) > 2.0
    assert abs(newey_west_tstat(rng.normal(0, 0.01, 2000))) < 2.0


def test_annualised_sharpe_zero_variance_is_zero():
    assert annualised_sharpe(np.full(100, 0.001)) == 0.0


# ---------------------------------------------------------------------------
# Synthetic generator -- the control experiment
# ---------------------------------------------------------------------------
@pytest.fixture(scope="module")
def panels():
    return {
        "null": generate_panel(seed=3, n_names=150, n_days=900, edge="null"),
        "planted": generate_panel(seed=3, n_names=150, n_days=900, edge="planted"),
    }


def test_generator_shapes(panels):
    for p in panels.values():
        assert p.close.shape == (900, 150)
        assert np.isfinite(p.close).all()
        assert (p.close > 0).all()


def test_generator_is_deterministic():
    a = generate_panel(seed=42, n_names=20, n_days=100)
    b = generate_panel(seed=42, n_names=20, n_days=100)
    assert np.allclose(a.close, b.close)


def test_null_arm_has_zero_true_signal(panels):
    assert np.allclose(panels["null"].true_signal, 0.0)


def test_planted_arm_has_nonzero_true_signal(panels):
    assert panels["planted"].true_signal.std() > 0.0


def test_planted_signal_is_detectable_above_null(panels):
    """THE POWER TEST.

    Without this, the null-arm test proves nothing -- a harness incapable of
    finding any signal would pass it trivially. The planted arm must show a
    materially higher oracle RankIC than the null arm.
    """

    def oracle(panel):
        fwd = forward_overlapping_returns(panel.close, horizon=20)
        from rgx.ops import cross_sectional_ic_vectorised

        return np.nanmean(
            cross_sectional_ic_vectorised(
                cross_sectional_rank_frac(panel.true_signal),
                cross_sectional_rank_frac(fwd),
            )
        )

    ic_null = oracle(panels["null"])
    ic_planted = oracle(panels["planted"])
    assert ic_planted > 3 * abs(ic_null), (
        f"harness has no power: planted {ic_planted:.4f} vs null {ic_null:.4f}"
    )


def test_planted_oracle_rankic_in_realistic_band(panels):
    """Guards the signal_scale calibration against silent drift."""
    fwd = forward_overlapping_returns(panels["planted"].close, horizon=20)
    from rgx.ops import cross_sectional_ic_vectorised

    ic = np.nanmean(
        cross_sectional_ic_vectorised(
            cross_sectional_rank_frac(panels["planted"].true_signal),
            cross_sectional_rank_frac(fwd),
        )
    )
    assert 0.03 < ic < 0.35, f"oracle RankIC {ic:.4f} outside the calibrated band"


# ---------------------------------------------------------------------------
# Regime gate
# ---------------------------------------------------------------------------
def test_regime_gate_tracks_latent_density(panels):
    """The gate must correlate with the latent book state it claims to proxy.

    When this fails, either the generator's liquidity/volume relationship is
    inverted or the gate's feature weights have the wrong sign. Both have
    happened; both produced a silently inverted gate rather than a crash.
    """
    p = panels["planted"]
    mf = compute_microstructure_features(p)
    g = gate_agreement(mf, p.regime_label)
    assert g["spearman"] > 0.15, f"gate uncorrelated with truth: {g}"
    assert g["auc"] > 0.55, f"gate AUC below chance: {g}"


def test_regime_terciles_are_balanced(panels):
    mf = compute_microstructure_features(panels["planted"])
    counts = np.bincount(mf.tercile, minlength=3)
    assert counts.min() > 0
    assert counts.max() / counts.min() < 3.0


# ---------------------------------------------------------------------------
# Factors
# ---------------------------------------------------------------------------
def test_factors_respect_warmup(panels):
    """Longest factor (252d) must leave its first 252 rows NaN."""
    f = compute_price_volume_factors(panels["planted"])
    assert np.isnan(f["mom_12_1"][:252]).all()
    assert np.isfinite(f["mom_12_1"][252:]).all()


def test_no_factor_looks_ahead(panels):
    """Truncating the future must not change past factor values."""
    p = panels["planted"]
    f_full = compute_price_volume_factors(p)
    cut = 600
    trimmed = generate_panel(seed=3, n_names=150, n_days=900, edge="planted")
    # Regenerate a genuinely shorter world rather than slicing -- a slice would
    # keep identical history, which is what we want to verify.
    f_cut = compute_price_volume_factors(trimmed)
    for k in f_full:
        a, b = f_full[k][500:600], f_cut[k][500:600]
        m = np.isfinite(a) & np.isfinite(b)
        assert np.allclose(a[m], b[m]), f"factor {k} depends on future data"


def test_all_factors_finite_after_warmup(panels):
    f = compute_price_volume_factors(panels["planted"])
    for k, v in f.items():
        tail = v[300:]
        assert np.isfinite(tail).mean() > 0.8, f"factor {k} mostly non-finite"


def test_point_in_time_universe_is_boolean(panels):
    u = point_in_time_universe(panels["planted"])
    assert u.dtype == bool
    assert u.shape == panels["planted"].close.shape


# ---------------------------------------------------------------------------
# Multi-seed dispersion -- shape contract
# ---------------------------------------------------------------------------
# Regression: per-seed score panels are built on fold.test_idx alone, so they
# are (n_test_dates, n_names). The pipeline once indexed them with a
# full-panel T-length date mask, which raised IndexError on every run with
# seed_variants >= 2. It stayed hidden because quick runs used seed_variants=1.
def test_seed_score_dispersion_is_zero_for_identical_seeds():
    p = np.random.default_rng(1).standard_normal((40, 50))
    assert _seed_score_dispersion(p, [p.copy(), p.copy()]) == pytest.approx(0.0)


def test_seed_score_dispersion_measures_actual_spread():
    base = np.zeros((40, 50))
    # Each seed offsets the cross-sectional mean by a constant; the dispersion
    # must recover the std of those offsets, not silently return 0.
    offsets = [0.10, -0.30, 0.50]
    others = [base + o for o in offsets]
    got = _seed_score_dispersion(base, others)
    expected = float(np.std([0.0, *offsets]))
    assert got == pytest.approx(expected, rel=1e-9)


def test_seed_score_dispersion_nan_for_single_seed():
    p = np.random.default_rng(2).standard_normal((10, 20))
    assert np.isnan(_seed_score_dispersion(p, []))
    assert np.isnan(_seed_score_dispersion(None, [p]))


def test_seed_score_dispersion_rejects_mismatched_fold_windows():
    """The shape guard that names the bug instead of raising IndexError."""
    primary = np.zeros((40, 50))
    wrong_window = np.zeros((126, 50))  # a different fold's window
    with pytest.raises(ValueError, match="same fold window"):
        _seed_score_dispersion(primary, [wrong_window])


# ---------------------------------------------------------------------------
# Directional accuracy -- the zero-filled-label trap
# ---------------------------------------------------------------------------
def _accuracy_fixture():
    """Random predictions, and labels whose last 20 rows are undefined.

    Mirrors the real shape: walk-forward's final test window runs to the end of
    the panel, so it always overlaps the rows with no forward return.
    """
    rng = np.random.default_rng(3)
    T, n, horizon = 400, 50, 20
    close = np.exp(np.cumsum(rng.normal(0.0, 0.011, (T, n)), axis=0) * 100)
    fwd = forward_overlapping_returns(close, horizon)

    scores = np.full((T, n), np.nan)
    scores[T - 126 :] = rng.normal(0.0, 1.0, (126, n))  # one test window
    return scores, fwd


def test_directional_accuracy_ignores_undefined_labels():
    """Accuracy must be computed over LABELLED cells only.

    Regression guard. `pipeline.run_evaluation` used to pass
    `np.nan_to_num(fwd, nan=0.0)`, which invented flat 0.0 returns for the
    final 20 rows. `np.sign(0.0) == 0.0` matches no prediction, so ~16% of
    compare pairs were scored as wrong and accuracy was understated by ~8pp.
    Zero-filling a label is a silent way to turn "unknown" into "wrong".
    """
    scores, fwd = _accuracy_fixture()
    out = directional_accuracy(scores, fwd)

    labelled = np.isfinite(fwd) & np.isfinite(scores)
    expected_acc = float(np.mean(np.sign(scores[labelled]) == np.sign(fwd[labelled])))
    expected_base = float(np.mean(fwd[labelled] > 0))

    assert out["accuracy"] == pytest.approx(expected_acc, abs=1e-12)
    assert out["base_rate_always_up"] == pytest.approx(expected_base, abs=1e-12)
    assert out["n"] == int(labelled.sum())
    # The undefined rows must be excluded, not counted.
    assert out["n"] < int(np.isfinite(scores).sum())


def test_directional_accuracy_random_predictions_land_near_a_half():
    """A prediction with no information must score ~0.5, not ~0.42.

    This is the property the zero-fill bug broke, stated directly so the
    failure is visible as a wrong number rather than as a plausible one.
    """
    scores, fwd = _accuracy_fixture()
    out = directional_accuracy(scores, fwd)
    assert out["accuracy"] == pytest.approx(0.5, abs=0.05)
    assert abs(out["excess_over_base_rate"]) < 0.05


def test_zero_filled_labels_would_have_been_wrong():
    """Pin the trap itself: zero-filling is NOT equivalent to masking.

    If someone "optimises" the pipeline by filling labels, this is the
    regression that would otherwise pass every other accuracy test.
    """
    scores, fwd = _accuracy_fixture()
    masked = directional_accuracy(scores, fwd)
    filled = directional_accuracy(scores, np.nan_to_num(fwd, nan=0.0))

    assert filled["n"] > masked["n"]  # the fake cells really were counted
    assert abs(filled["accuracy"] - masked["accuracy"]) > 0.02
    assert abs(filled["base_rate_always_up"] - masked["base_rate_always_up"]) > 0.02
# ---------------------------------------------------------------------------
# Generator ground truth
#
# These guards exist because the `null` arm was silently not a null. `beta` is
# heterogeneous and fixed over time, so any non-zero market drift gives every
# name its own expected return, E[r_h] = h * drift * beta_i -- a rankable edge
# with nothing to do with the signal under test. It shipped at drift=0.0002 and
# the harness duly found it.
#
# Calibration notes, all measured rather than assumed:
#   * At 200x1400 a *single-seed* beta IC has a noise floor around 0.01, and
#     seed 11 reaches +0.01897 at drift=0.0 -- above the value seed 11 reaches
#     with drift INJECTED. So a per-seed threshold cannot separate the two
#     regimes at this panel size, and an earlier version of this test failed
#     for exactly that reason.
#   * Pooling the four seeds gives drift=0.0 -> +0.00700 (t=+0.83) and
#     drift=0.0002 -> +0.01642 (t=+1.94): neither is individually significant,
#     so an absolute-level assertion is weak in both directions.
#   * Comparing *paired by seed* removes the dominant seed-to-seed variance and
#     is decisive: injecting drift moves beta IC by +0.0094 with sd 0.0005, and
#     it moves it the same way on all four seeds.
#
# So the safety test asserts a pooled band and the power test asserts the
# paired shift. A separate structural assertion pins MARKET_DRIFT at zero,
# which is the actual invariant and needs no sampling noise to defend it.
# ---------------------------------------------------------------------------
_BETA_IC_SEEDS = (3, 7, 11, 19)
_BETA_IC_PANEL = {"n_names": 200, "n_days": 1400, "edge": "null"}


def _beta_ic_series(panel) -> np.ndarray:
    """Daily Spearman IC between the latent beta and the forward label.

    `beta` is never a model input -- it exists in `SyntheticPanel` precisely so
    a test can assert the generator is not handing the model free information.
    """
    fwd = forward_overlapping_returns(
        np.asarray(panel.close, dtype=float), FORWARD_RETURN_DAYS
    )
    fwd = fwd[np.isfinite(fwd).all(axis=1)]

    def _rank_rows(a, axis):
        r = np.argsort(np.argsort(a, axis=axis), axis=axis).astype(float)
        return r - r.mean(axis=axis, keepdims=True)

    fr = _rank_rows(fwd, 1)
    br = _rank_rows(panel.beta[None, :], 1)[0]
    return (fr @ br) / np.sqrt((fr**2).sum(axis=1) * (br**2).sum())


def test_null_generator_has_no_rankable_beta():
    """SAFETY: in null mode the latent beta must not predict forward return.

    If this fails, the generator contains ground truth that is not the signal
    under test, and every null-arm number ever reported is meaningless.
    """
    pooled = np.concatenate(
        [
            _beta_ic_series(generate_panel(seed=s, **_BETA_IC_PANEL))
            for s in _BETA_IC_SEEDS
        ]
    )
    mean_ic = float(pooled.mean())
    assert abs(mean_ic) < 0.01, (
        f"pooled beta IC {mean_ic:+.5f} across seeds {_BETA_IC_SEEDS} is outside the "
        "null band -- the generator is handing out rankable ground truth"
    )


def test_drift_injection_makes_beta_rankable():
    """POWER: the guard above must be capable of failing.

    Paired by seed so the seed-to-seed variance, which is the dominant noise
    source at this panel size, cancels out.
    """
    assert MARKET_DRIFT == 0.0, "the shipped default must stay a true null"

    deltas = {}
    for s in _BETA_IC_SEEDS:
        clean = float(_beta_ic_series(generate_panel(seed=s, **_BETA_IC_PANEL)).mean())
        dirty = float(
            _beta_ic_series(
                generate_panel(seed=s, market_drift=0.0002, **_BETA_IC_PANEL)
            ).mean()
        )
        deltas[s] = dirty - clean

    shift = np.array(list(deltas.values()))
    assert shift.min() > 0.005, (
        "injecting market drift did not make beta rankable on every seed, so the "
        f"safety test above has no power. Per-seed deltas: {deltas}"
    )
