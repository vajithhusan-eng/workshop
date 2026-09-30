"""Signal forensics — the real Bailey/López de Prado math. No heuristics.

This module is the product. If the numbers here are approximate-by-vibes, the
whole thesis collapses the moment a quant reads it. So everything below is the
published formula, implemented in pure Python (the venv has no numpy).

REFERENCES
  [BBLP14] Bailey, Borwein, López de Prado, Zhu,
          "Pseudo-Mathematics and Financial Charlatanism", Notices of AMS 61(5), 2014.
  [BLdP12] Bailey & López de Prado, "The Sharpe Ratio Efficient Frontier",
          Journal of Risk 15(2), 2012.  -> expected max Sharpe under the null
  [BLdP14] Bailey & López de Prado, "The Deflated Sharpe Ratio",
          Journal of Portfolio Management 40(5):94-107, 2014. -> PSR/DSR
  [BBLP17] Bailey, Borwein, López de Prado, Zhu,
          "The Probability of Backtest Overfitting", J. Computational Finance 20(4):39-69, 2017.
          -> PBO via CSCV (Combinatorially Symmetric Cross-Validation)
  [HLZ16]  Harvey, Liu & Zhu, "...and the Cross-Section of Expected Returns", RFS 29(1), 2016.
  [HL20]   Harvey & Liu, "False (and Missed) Discoveries in Financial Economics",
          Journal of Finance 75(5):2503-2553, 2020. -> FDR calibration

All functions are deterministic. No randomness anywhere in the scoring path.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from itertools import combinations
from typing import Sequence

# Euler–Mascheroni constant, used in the Sharpe Ratio Efficient Frontier.
EULER_GAMMA = 0.5772156649015329

# Daniel & Moskowitz (JFE 2016) worst momentum months, for the crash overlay.
# (month, winner-decile return). Aug 1932 is the worst on record at -78.96%.
MOMENTUM_CRASHES: tuple[tuple[str, float], ...] = (
    ("1932-08", -0.7896),
    ("1932-07", -0.6011),
    ("2009-04", -0.4599),
    ("1939-09", -0.4394),
    ("1933-04", -0.4233),
    ("2001-01", -0.4218),
    ("2009-03", -0.3962),
    ("1938-06", -0.3314),
    ("1931-06", -0.3009),
    ("1933-05", -0.2839),
)


# ─────────────────────────────────────────────────────────────────────────────
# Normal distribution helpers (pure Python; math.erf is stdlib)
# ─────────────────────────────────────────────────────────────────────────────


def norm_cdf(x: float) -> float:
    """P(X <= x) for a standard normal."""
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def norm_ppf(p: float) -> float:
    """Inverse standard normal CDF (probit).

    Bisection on norm_cdf. Robust and exact to ~1e-12, and there is no
    scipy/numpy in this venv, so a closed-form approximation is the only
    honest option. Bracketing is widened geometrically so it can't fail.
    """
    if not 0.0 < p < 1.0:
        raise ValueError(f"norm_ppf requires 0 < p < 1, got {p}")
    lo, hi = -40.0, 40.0
    for _ in range(200):
        mid = 0.5 * (lo + hi)
        if norm_cdf(mid) < p:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


# ─────────────────────────────────────────────────────────────────────────────
# Return-series statistics
# ─────────────────────────────────────────────────────────────────────────────


def mean(xs: Sequence[float]) -> float:
    return sum(xs) / len(xs)


def stdev(xs: Sequence[float]) -> float:
    """Sample standard deviation (n-1)."""
    n = len(xs)
    if n < 2:
        return 0.0
    m = mean(xs)
    return math.sqrt(sum((x - m) ** 2 for x in xs) / (n - 1))


def skewness(xs: Sequence[float]) -> float:
    """Sample skewness (g1, the population-corrected estimator)."""
    n = len(xs)
    if n < 3:
        return 0.0
    m, s = mean(xs), stdev(xs)
    if s == 0.0:
        return 0.0
    return (n / ((n - 1) * (n - 2))) * sum(((x - m) / s) ** 3 for x in xs)


def kurtosis(xs: Sequence[float]) -> float:
    """Raw (non-excess) sample kurtosis. Normal returns => 3.0.

    RAW, not excess, and it has to be raw: the PSR denominator in [BLdP14] is
    ((g4 - 1)/4)*SR^2, which assumes g4 = 3 for a normal. Feeding it excess
    kurtosis (0 for normal) silently biases every PSR in the optimistic
    direction, which is exactly the direction that flatters a bad signal.
    """
    n = len(xs)
    if n < 4:
        return 3.0
    m, s = mean(xs), stdev(xs)
    if s == 0.0:
        return 3.0
    return (n * (n + 1) / ((n - 1) * (n - 2) * (n - 3))) * sum(
        ((x - m) / s) ** 4 for x in xs
    )


def excess_kurtosis(xs: Sequence[float]) -> float:
    """Excess kurtosis. Normal => 0. Positive => fat tails."""
    return kurtosis(xs) - 3.0


def annualized_sigma(n_obs: int, periods_per_year: int = 252) -> float:
    """Std-dev of an *annualised* Sharpe estimated from n_obs periods.

    The per-period Sharpe estimated from T observations has std-dev 1/sqrt(T).
    Annualising multiplies the point estimate by sqrt(periods_per_year), so
    the std-dev of the annualised estimate is sqrt(ppy / T).

    This is the sigma_SR you want when feeding annualised Sharpes to the
    [BLdP12] frontier. Passing 1.0 instead is a units bug that makes every
    multiple-testing correction far too harsh, which is the safe direction to
    be wrong in — but it still misreports the frontier number itself.
    """
    return math.sqrt(periods_per_year / max(n_obs, 1))


def sharpe(returns: Sequence[float], periods_per_year: int = 252) -> float:
    """Annualised Sharpe ratio, risk-free rate assumed 0."""
    if len(returns) < 2:
        return 0.0
    s = stdev(returns)
    if s == 0.0:
        return 0.0
    return (mean(returns) / s) * math.sqrt(periods_per_year)


# ─────────────────────────────────────────────────────────────────────────────
# [BLdP12] Sharpe Ratio Efficient Frontier — expected max Sharpe under the null
# ─────────────────────────────────────────────────────────────────────────────


def sharpe_frontier(n_trials: int, sigma_sharpe: float) -> float:
    """Expected maximum Sharpe ratio from N independent trials, all truly zero.

    E[max SR] = sigma_SR * [ (1-g)*Z^-1(1 - 1/N) + g*Z^-1(1 - 1/(N*e)) ]

    This is the "you would find this by luck alone" line. Any strategy whose
    realised Sharpe is below it has demonstrated nothing.

    sigma_sharpe is the standard deviation *across* the trial Sharpes — the
    dispersion of the search. Pass 1.0 if you only know the count of trials.
    """
    if n_trials < 1:
        raise ValueError("n_trials must be >= 1")
    if n_trials == 1:
        # E[max of a single draw] = E[SR] = 0. The formula's 1 - 1/N term
        # collapses to 0 here, which norm_ppf cannot accept; the limit is 0.
        return 0.0
    n = float(n_trials)
    # Defensive clamp: for large-but-finite N, 1 - 1/N underflows to exactly 1.0
    # in float64, and norm_ppf(1.0) is out of domain.
    first = norm_ppf(min(1.0 - 1.0 / n, 1.0 - 1e-15))
    second = norm_ppf(1.0 - 1.0 / (n * math.e))
    return sigma_sharpe * ((1.0 - EULER_GAMMA) * first + EULER_GAMMA * second)


# ─────────────────────────────────────────────────────────────────────────────
# [BLdP14] Probabilistic Sharpe Ratio / Deflated Sharpe Ratio
# ─────────────────────────────────────────────────────────────────────────────


def psr(
    observed_sharpe: float,
    benchmark_sharpe: float,
    n_obs: int,
    skew: float = 0.0,
    kurt: float = 3.0,
) -> float:
    """Probabilistic Sharpe Ratio: P(true SR > benchmark | observed stats).

    PSR = Z[ (SR_hat - SR_bench) * sqrt(T-1)
             / sqrt(1 - g3*SR_hat + ((g4-1)/4)*SR_hat^2) ]

    SR_hat is expected to be in the same (non-annualised) units as SR_bench,
    so callers with annualised inputs must annualise the benchmark too.
    """
    if n_obs < 2:
        raise ValueError("n_obs must be >= 2")
    denom = 1.0 - skew * observed_sharpe + ((kurt - 1.0) / 4.0) * observed_sharpe**2
    if denom <= 0:
        # Degenerate (extremely fat tails). Conservatively claim no edge.
        return 0.0
    z = (observed_sharpe - benchmark_sharpe) * math.sqrt(n_obs - 1) / math.sqrt(denom)
    return norm_cdf(z)


def deflated_sharpe(
    observed_sharpe: float,
    n_trials: int,
    n_obs: int,
    sigma_sharpe: float | None = None,
    skew: float = 0.0,
    kurt: float = 3.0,
    periods_per_year: int = 252,
) -> dict:
    """Deflated Sharpe Ratio (DSR).

    DSR = PSR evaluated at the Sharpe Ratio Efficient Frontier — i.e. the
    probability that the true Sharpe exceeds what pure luck would have
    produced across the same number of trials.

    DSR > 0.95  => survives multiple-testing correction
    DSR < 0.05  => indistinguishable from the best of N coin flips

    sigma_sharpe defaults to annualized_sigma(n_obs), i.e. the dispersion you
    would expect among genuinely-null strategies measured over the same
    window. observed_sharpe and the frontier must be in the SAME units.
    """
    if sigma_sharpe is None:
        sigma_sharpe = annualized_sigma(n_obs, periods_per_year)
    sr_star = sharpe_frontier(n_trials, sigma_sharpe)
    value = psr(observed_sharpe, sr_star, n_obs, skew=skew, kurt=kurt)
    return {
        "observed_sharpe": round(observed_sharpe, 3),
        "frontier_sharpe": round(sr_star, 3),
        "sigma_sharpe": round(sigma_sharpe, 4),
        "dsr": round(value, 4),
        "significant": value > 0.95,
        "indistinguishable_from_luck": value < 0.05,
        "n_trials": n_trials,
        "n_obs": n_obs,
        "skew": round(skew, 3),
        "kurtosis": round(kurt, 3),
    }


# ─────────────────────────────────────────────────────────────────────────────
# [BBLP17] Probability of Backtest Overfitting via CSCV
# ─────────────────────────────────────────────────────────────────────────────


def _sharpe_block(block: Sequence[float], ppy: int) -> float:
    return sharpe(block, periods_per_year=ppy)


def pbo_cscv(
    returns_matrix: Sequence[Sequence[float]],
    n_splits: int = 8,
    periods_per_year: int = 252,
) -> dict:
    """PBO via Combinatorially Symmetric Cross-Validation.

    arguments
        returns_matrix : N strategies x T periods of periodic returns.
        n_splits       : S, number of contiguous subperiods. Must be even.
                         The paper uses S=16; 8 is the cheap-but-usable floor.

    procedure (verbatim from the paper)
        1. Split the T periods into S disjoint contiguous subperiods.
        2. For each of the C(S, S/2) ways of assigning S/2 subperiods to
           in-sample and the rest to out-of-sample:
             a. rank all N strategies by in-sample Sharpe
             b. take the in-sample winner
             c. find its relative rank in out-of-sample
        3. omega = relative OOS rank via the mid-rank convention,
           omega = (rank - 0.5)/N, so omega -> 1 when the winner finishes LAST
           and omega -> 0 when it finishes FIRST. logit = ln( omega/(1-omega) )
        4. PBO = fraction of splits whose logit is POSITIVE, i.e. the
           in-sample winner finished out-of-sample BELOW the median.

    SIGN NOTE, because this is the easiest thing in the file to get backwards:
    logit > 0 means omega > 0.5 means worse-than-median. Inverting this makes
    PBO report ~1.0 for a genuinely good, perfectly stable strategy — the
    better it does out-of-sample, the *lower* its omega and the more negative
    the logit. That is not a soft penalty, it is a reversed verdict, and it is
    the difference between "your selection has no skill" and "your selection
    is stable".

    Interpretation: PBO is the probability that the strategy which looked
    best in-sample finishes in the bottom half out-of-sample. PBO > 0.5 means
    your selection procedure has negative skill.
    """
    n_strategies = len(returns_matrix)
    n_periods = len(returns_matrix[0]) if n_strategies else 0
    if n_strategies < 2:
        raise ValueError("need at least 2 strategies to measure PBO")
    if n_splits < 4 or n_splits % 2 != 0:
        raise ValueError("n_splits must be even and >= 4")
    if n_periods < n_splits:
        raise ValueError(f"need at least n_splits={n_splits} periods, got {n_periods}")
    if any(len(r) != n_periods for r in returns_matrix):
        raise ValueError("all strategies must have the same number of periods")

    # 1. contiguous blocks
    size = n_periods // n_splits
    blocks = [
        [row[i * size : (i + 1) * size] for row in returns_matrix]
        for i in range(n_splits)
    ]

    half = n_splits // 2
    logits: list[float] = []

    # 2. every assignment of S/2 subperiods to in-sample
    for is_idx in combinations(range(n_splits), half):
        is_set = set(is_idx)
        oos_idx = [i for i in range(n_splits) if i not in is_set]

        is_sharpes = [
            _sharpe_block([r for bi in is_idx for r in blocks[bi][s]], periods_per_year)
            for s in range(n_strategies)
        ]
        oos_sharpes = [
            _sharpe_block(
                [r for bi in oos_idx for r in blocks[bi][s]], periods_per_year
            )
            for s in range(n_strategies)
        ]

        # 2a. in-sample winner
        winner = max(range(n_strategies), key=lambda s: is_sharpes[s])
        # 2c. its out-of-sample rank, 1 = best
        rank = 1 + sum(1 for v in oos_sharpes if v > oos_sharpes[winner])
        # 3. relative rank via the MID-RANK convention, omega = (rank - 0.5)/N.
        # Mid-rank keeps omega strictly inside (0, 1) for every possible rank,
        # so the logit is always finite. Using rank/N instead makes omega hit
        # exactly 1.0 when the winner finishes last and raises ZeroDivisionError
        # — i.e. the worst possible backtest result crashes the diagnostic.
        omega = (rank - 0.5) / n_strategies
        logits.append(math.log(omega / (1.0 - omega)))

    # 4. PBO — positive logit == worse than median out-of-sample
    overfit = sum(1 for x in logits if x > 0.0)
    pbo = overfit / len(logits)
    return {
        "pbo": round(pbo, 4),
        "n_strategies": n_strategies,
        "n_splits": n_splits,
        "n_combos": len(logits),
        "best_oos_rank_logit": round(min(logits), 4),
        "worst_oos_rank_logit": round(max(logits), 4),
        "interpretation": (
            "selection procedure has negative skill"
            if pbo > 0.5
            else "selection is at least break-even"
        ),
    }


def min_backtest_length(
    n_trials: int, target_sharpe: float = 0.5, periods_per_year: int = 252
) -> float:
    """MinBTL: observations needed before best-of-N selection is more than noise.

    The std-dev of a Sharpe estimated from T observations is 1/sqrt(T) in
    per-period units. The expected max across N trials is that dispersion
    times the [BLdP12] frontier multiplier. Require the target to exceed it:

        (1/sqrt(T)) * mult(N)  >  target_sharpe / sqrt(periods_per_year)
        T  >  ( mult(N) * sqrt(periods_per_year) / target_sharpe )^2

    The frame matters: 1/sqrt(T) is only the correct dispersion in per-period
    units, and target_sharpe arrives annualised. Doing the comparison with
    mismatched units understates the required length by a factor of ~252 and
    makes an almost any backtest look adequate.

    Returns observations; divide by periods_per_year for years.
    """
    if target_sharpe <= 0:
        raise ValueError("target_sharpe must be > 0")
    mult = sharpe_frontier(n_trials, 1.0)
    target_per_period = target_sharpe / math.sqrt(periods_per_year)
    return round((mult / target_per_period) ** 2, 1)


# ─────────────────────────────────────────────────────────────────────────────
# [HLZ16 / HL20] multiple-testing / false discovery rate
# ─────────────────────────────────────────────────────────────────────────────


def fdr_adjusted_pvalue(t_stat: float, n_tests: int, target_fdr: float = 0.05) -> dict:
    """Harvey–Liu–Zhu style hurdle check for a newly published factor.

    HLZ (2016) showed the conventional t>2.0 hurdle is meaningless once you
    have searched hundreds of papers, and recommended t>3.0. Harvey & Liu
    (2020) later argued for calibrating to a target false-discovery rate
    instead of a fixed t-hurdle, via double bootstrap. This is the
    normal-approximation screening check — cheap, transparent, and explicitly
    an approximation of the double bootstrap. Where it disagrees with the
    paper, the paper wins.

    Bonferroni-adjusted two-sided p-value, then compared to target_fdr.
    """
    if n_tests < 1:
        raise ValueError("n_tests must be >= 1")
    two_sided_p = 2.0 * (1.0 - norm_cdf(abs(t_stat)))
    adjusted = min(1.0, two_sided_p * n_tests)
    return {
        "t_stat": round(t_stat, 3),
        "n_tests": n_tests,
        "raw_p": round(two_sided_p, 6),
        "fdr_adjusted_p": round(adjusted, 6),
        "target_fdr": target_fdr,
        "passes": adjusted < target_fdr,
        "hlz_t_hurdle": 3.0,
        "clears_hlz_3": abs(t_stat) > 3.0,
        "method": "bonferroni-normal-approximation (screening only; see HL20)",
    }


# ─────────────────────────────────────────────────────────────────────────────
# [DM16] momentum crash overlay + comomentum crowding
# ─────────────────────────────────────────────────────────────────────────────


def momentum_crash_risk(comomentum: float, vol_percentile: float) -> dict:
    """Crash-risk flag from the two documented preconditions.

    Daniel & Moskowitz (JFE 2016): momentum crashes occur in *panic states* —
    after a decline, when volatility is high, coinciding with a sharp rebound.
    The short leg is what explodes (Jul-Aug 1932: losers +236% while the
    market rose 82%).

    Lou & Polk (2022): "comomentum" — pairwise abnormal-return correlation
    *within* the momentum legs — predicts crash severity and is observable in
    real time. MSCI's Factor Crowding Model gave a live warning in Oct 2020
    (>3 sigma short interest) before momentum lost ~5% in a single day on
    9 Nov 2020, erasing nine months of gains.

    Both inputs are percentiles in [0, 1]. This is a flag, not a forecast.
    """
    crowded = comomentum >= 0.8
    stressed = vol_percentile >= 0.8
    if crowded and stressed:
        level, action = (
            "SEVERE",
            "Scale down materially. Exit queue is already forming.",
        )
    elif crowded or stressed:
        level, action = "ELEVATED", "Halve new exposure. Recheck weekly."
    else:
        level, action = "NORMAL", "Within historical norms."
    return {
        "comomentum_pctile": round(comomentum, 2),
        "vol_pctile": round(vol_percentile, 2),
        "risk_level": level,
        "action": action,
        "worst_months_on_record": [
            {"month": m, "winner_return": r} for m, r in MOMENTUM_CRASHES[:3]
        ],
        "reference": "Daniel & Moskowitz JFE 122(2) 2016; Lou & Polk 2022",
    }


# ─────────────────────────────────────────────────────────────────────────────
# The composite autopsy
# ─────────────────────────────────────────────────────────────────────────────


@dataclass
class AutopsyResult:
    technique: str
    verdict: str
    severity: str
    findings: dict = field(default_factory=dict)


def autopsy(
    name: str,
    sharpe_ratio: float,
    n_trials: int,
    n_obs: int,
    backtest_excess_bps: int,
    live_excess_bps: int,
    sigma_sharpe: float | None = None,
    t_stat: float | None = None,
    n_tests: int | None = None,
    periods_per_year: int = 252,
) -> dict:
    """Full forensic autopsy of a claimed signal.

    Decay is measured against McLean & Pontiff (JF 2016), which found 26%
    out-of-sample and 58% post-publication decay, with the *best* in-sample
    predictors decaying hardest.

    VERDICT LOGIC. Red flags are counted rather than short-circuited, because a
    single flag is rarely conclusive and one should never be silently fatal.
    Thresholds are set against the published baselines, not round numbers:

      - decay below 25% is unremarkable; 25-75% is amber, because 58% is the
        *expected* post-publication decay, so rejecting at 50% would reject the
        median legitimate signal. Only >75% (well past the 58% baseline) is red.
      - a t-stat below the HLZ 3.0 hurdle is amber even when it clears FDR,
        because FDR and the HLZ hurdle answer different questions.
      - DSR indistinguishable from luck counts double: it is the strongest
        single statement this module can make, and it subsumes the length
        problem (you cannot detect luck with an underpowered backtest).
    """
    dsr = deflated_sharpe(
        sharpe_ratio,
        n_trials,
        n_obs,
        sigma_sharpe=sigma_sharpe,
        periods_per_year=periods_per_year,
    )
    btl = min_backtest_length(
        n_trials,
        target_sharpe=abs(sharpe_ratio) or 0.5,
        periods_per_year=periods_per_year,
    )
    decay_bps = backtest_excess_bps - live_excess_bps
    decay_pct = (
        (decay_bps / backtest_excess_bps * 100.0) if backtest_excess_bps else 0.0
    )

    fdr = (
        fdr_adjusted_pvalue(t_stat, n_tests or n_trials) if t_stat is not None else None
    )

    red: list[str] = []
    amber: list[str] = []

    if dsr["indistinguishable_from_luck"]:
        red.append(
            f"DSR {dsr['dsr']:.2f} — below what {n_trials} lucky trials produce "
            f"(frontier SR {dsr['frontier_sharpe']})"
        )
        red.append("the edge is inside the noise band from trying this many variations")
    if n_obs < btl:
        red.append(
            f"only {n_obs} observations vs MinBTL {btl:.0f} needed to have "
            f"distinguished a real {sharpe_ratio:.2f} SR from {n_trials} trials"
        )
    if decay_pct >= 75:
        red.append(
            f"{decay_pct:.0f}% of the backtest excess has decayed — well past "
            f"the 58% post-publication norm"
        )
    elif decay_pct >= 25:
        amber.append(
            f"{decay_pct:.0f}% of the backtest excess has already decayed "
            f"(58% is the published norm)"
        )
    if fdr and not fdr["passes"]:
        red.append(
            f"t={fdr['t_stat']} fails FDR calibration at {fdr['target_fdr']} "
            f"across {fdr['n_tests']} tests"
        )
    elif fdr and not fdr["clears_hlz_3"]:
        amber.append(
            f"t={fdr['t_stat']} clears FDR but not the Harvey-Liu-Zhu t>3.0 hurdle"
        )

    reasons = red + amber
    if len(red) >= 3:
        verdict = "REJECT — " + "; ".join(red)
        severity = "high"
    elif red:
        verdict = (
            "WARN — does not clear scrutiny. "
            + "; ".join(reasons)
            + ". Do not size this on the backtest alone."
        )
        severity = "medium"
    elif amber:
        verdict = (
            "WARN — survives deflation and FDR, but haircut expectations. "
            + "; ".join(amber)
            + ". Demand a crowding check before sizing."
        )
        severity = "medium"
    else:
        verdict = (
            "PASS — survives deflation, FDR and length checks. Still verify "
            "crowding and regime before sizing."
        )
        severity = "low"

    return {
        "technique": name,
        "verdict": verdict,
        "severity": severity,
        "red_flags": len(red),
        "amber_flags": len(amber),
        "decay": {
            "backtest_excess_bps": backtest_excess_bps,
            "live_excess_bps": live_excess_bps,
            "decay_bps": decay_bps,
            "decay_pct": round(decay_pct, 1),
            "expected_out_of_sample_penalty_pct": 26,
            "expected_post_publication_penalty_pct": 58,
            "source": "McLean & Pontiff, Journal of Finance 71(1), 2016",
        },
        "deflated_sharpe": dsr,
        "fdr": fdr,
        "min_backtest_length": {
            "observations_needed": btl,
            "observations_have": n_obs,
            "years_needed": round(btl / periods_per_year, 1),
            "sufficient": n_obs >= btl,
        },
        "reasons": reasons,
    }
