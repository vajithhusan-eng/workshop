"""End-to-end safety tests for the whole evaluation pipeline.

`test_invariants.py` checks component contracts -- look-ahead, NaN handling,
embargoes, cost monotonicity, DSR units, generator ground truth. It never calls
`run_evaluation`. This file does.

Each test below asserts something that was **measured**, not assumed. Several
assertions that a naive reading of this project would want are deliberately
absent, and the reason is recorded in `STATE.md`:

  * There is no "null RankIC must be ~0" assertion. It cannot be honest here.
    On the fixed generator the null arm measures RankIC of +0.029/+0.055/+0.034/
    +0.007 across seeds at 200x1400. That signal is real in the data -- the
    six volatility-sensitive factors individually carry +0.025..+0.040 rank IC
    on the null panel with 4/4 consistent seed signs, while random-score
    controls sit at ~0. So the null panel contains genuine cross-sectional
    structure and the model is right to find some of it.
  * There is no "planted RankIC must clear X" or "planted must beat null by 5x"
    assertion. Both were measured and both fail: planted averages +0.0235
    against null's +0.0312 at 200x1400, i.e. the contrast is *inverted* at this
    panel size. The harness does not currently demonstrate power end-to-end.
    That is a recorded limitation, not a passing test.
  * `beats_random_signal` is not asserted False. With only 40 random draws the
    null arm's gross Sharpe reaches the 100th percentile on some seeds, because
    the same variance-scaling structure lifts Sharpe without lifting the
    statistical case.

What IS asserted is the invariant the pipeline actually guarantees: across all
16 sweep runs (both arms, two panel sizes, four seeds) the verdict was
`NO RELIABLE EDGE`, the t-statistic never cleared 3.0 (max observed 2.48), and
the deflated p-value never cleared 0.05 (min observed ~0.75).

Runtime: a full walk-forward run needs TRAIN_YEARS*252 + TEST_MONTHS*21 +
EMBARGO_DAYS ~ 1400 dates, so each arm costs real CPU on LightGBM. These tests
are marked `slow` and skipped unless RGX_SLOW=1:

    RGX_SLOW=1 pytest tests/test_null_control.py -v

Any pipeline change to `ops.py`, the label construction, or the weight/return
alignment in `portfolio/construction.py` MUST be re-checked against these. The
fast suite will not catch a leak introduced there.
"""

from __future__ import annotations

import os

import numpy as np
import pytest

from rgx.config import RunConfig
from rgx.data.synthetic import generate_panel
from rgx.pipeline import run_evaluation
from rgx.validation.metrics import cross_sectional_ic
from rgx.validation.splits import forward_overlapping_returns

pytestmark = [
    pytest.mark.slow,
    pytest.mark.skipif(
        os.environ.get("RGX_SLOW") != "1",
        reason="full walk-forward run; set RGX_SLOW=1 to exercise the null control",
    ),
]

# Smallest panel that still fits one walk-forward fold under TRAIN_YEARS=5,
# TEST_MONTHS=6, EMBARGO_DAYS=10. seed_variants=1 keeps the run affordable; the
# multi-seed path is covered separately and cheaply in test_invariants.py.
SMALL = dict(seed=3, n_names=200, n_days=1400, seed_variants=1)

# Lowest oracle RankIC measured on planted panels across seeds 3/7/11/19 with
# the pipeline's own spearman metric at 200x1400 (range +0.079..+0.103). The
# null arm's worst observed reading is +0.0547, so this separates "found
# nothing" from "found everything there is to find" without pretending the
# null reading is zero.
ORACLE_RANKIC_FLOOR = 0.05


@pytest.fixture(scope="module")
def null_report() -> dict:
    return run_evaluation(RunConfig(edge="null", **SMALL), verbose=False)


@pytest.fixture(scope="module")
def planted_report() -> dict:
    return run_evaluation(RunConfig(edge="planted", **SMALL), verbose=False)


# ---------------------------------------------------------------------------
# Safety: no designed edge exists, so nothing may be declared
# ---------------------------------------------------------------------------
def test_null_arm_reports_no_edge(null_report: dict) -> None:
    """The project's central invariant.

    Requiring every load-bearing gate to reject independently is the point: a
    single loosened gate is exactly how a leak announces itself.
    """
    assert null_report["verdict"] == "NO RELIABLE EDGE"

    checks = null_report["checks"]
    assert checks["t_stat_above_3"] is False, (
        "null arm cleared the t>3 hurdle with nw_t="
        f"{null_report['performance_net']['nw_tstat']:.2f} -- possible leak"
    )
    assert checks["deflated_p_below_0.05"] is False, (
        "null arm cleared the deflated-p hurdle with p="
        f"{null_report['deflated_sharpe']['deflated_p_value']:.4f} -- possible leak"
    )


def test_planted_arm_also_declines_no_edge(planted_report: dict) -> None:
    """The planted arm currently fails to clear the hurdles too.

    Recorded as a test rather than hidden: the harness extracts roughly a fifth
    of the planted oracle signal, so at this panel size it does not clear
    MIN_T_STAT=3.0 or a deflated p below 0.05. If this assertion ever starts
    failing, that is good news and the thresholds below should be revisited.
    """
    assert planted_report["verdict"] == "NO RELIABLE EDGE"
    assert planted_report["checks"]["t_stat_above_3"] is False
    assert planted_report["checks"]["deflated_p_below_0.05"] is False


def test_null_reading_is_far_below_the_oracle(null_report: dict) -> None:
    """What the null control can honestly assert.

    Not "the null RankIC is zero" -- it is not, and pretending otherwise is
    the error this project exists to avoid. But the null arm's reading must sit
    far below the best signal available on the same generator, or "found
    nothing" would be indistinguishable from "found everything".
    """
    rankic = null_report["signal"]["rankic_mean"]
    assert abs(rankic) < ORACLE_RANKIC_FLOOR, (
        f"null RankIC {rankic:+.4f} is within {ORACLE_RANKIC_FLOOR} of the "
        "planted oracle floor -- the null arm is extracting a real edge"
    )


# ---------------------------------------------------------------------------
# Power: the generator really does contain findable structure
# ---------------------------------------------------------------------------
@pytest.mark.parametrize("seed", [3, 7, 11])
def test_planted_generator_holds_a_rankable_signal(seed: int) -> None:
    """POWER, at the generator level: an edge exists and is measurable.

    This is the counterweight to the safety tests above -- a generator with no
    signal would pass them trivially while being worthless. Measured with the
    pipeline's own canonical RankIC (`cross_sectional_ic`, spearman) on
    planted panels at 200x1400, the oracle reading is +0.079..+0.103 across
    seeds 3/7/11/19, and this is cheap (no LightGBM), unlike the end-to-end
    recovery test, which is not yet established -- see the module docstring
    and STATE.md.
    """
    panel = generate_panel(seed=seed, n_names=200, n_days=1400, edge="planted")
    fwd = forward_overlapping_returns(np.asarray(panel.close, float), 20)
    # The last FORWARD_RETURN_DAYS rows of fwd are NaN (label not yet
    # observable). Take the mask BEFORE filtering, so it stays valid for the
    # full (T, n) true_signal panel too; recomputing it after slicing would
    # yield a shorter mask and an IndexError against the 1400-row signal.
    finite = np.isfinite(fwd).all(axis=1)
    pred = np.asarray(panel.true_signal, float)[finite]
    tgt = fwd[finite]

    ics = cross_sectional_ic(pred, tgt, method="spearman")
    mean_ic = float(np.nanmean(ics))

    assert np.isfinite(mean_ic)
    assert mean_ic > ORACLE_RANKIC_FLOOR, (
        f"seed {seed}: planted oracle RankIC {mean_ic:+.4f} is too weak to serve as "
        "a power reference -- the generator's own signal is not detectable"
    )
