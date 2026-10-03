"""Evaluation metrics and statistical corrections.

Implements:
  - cross-sectional Pearson IC and Spearman RankIC
  - ICIR
  - net Sharpe with autocorrelation-robust inference
  - maximum drawdown
  - Deflated Sharpe Ratio (Bailey & Lopez de Prado, 2014)
  - Probability of Backtest Overfitting via CSCV (Bailey et al., 2016)

The Sharpe inference deliberately does NOT use the naive iid standard error.
Andrew Lo, "The Statistics of Sharpe Ratios" (FAJ 2002) shows that with serial
correlation and non-normality the bias in sample Sharpe is much larger than the
iid formula implies, and its sign depends on the strategy's autocorrelation
structure. We use Newey-West on the return series instead.
"""

from __future__ import annotations

import itertools
import math
from dataclasses import dataclass

import numpy as np
from scipy import stats


# --------------------------------------------------------------------------
# Cross-sectional information coefficients
# --------------------------------------------------------------------------
def cross_sectional_ic(
    predictions: np.ndarray, realised: np.ndarray, method: str = "spearman"
) -> np.ndarray:
    """Per-date information coefficient. Rows with no dispersion return NaN.

    Fully vectorised over dates -- the looped version dominated total runtime.
    """
    from ..ops import cross_sectional_ic_vectorised, cross_sectional_rank_frac

    p = np.asarray(predictions, dtype=float)
    r = np.asarray(realised, dtype=float)
    if method == "spearman":
        p = cross_sectional_rank_frac(p)
        r = cross_sectional_rank_frac(r)
    return cross_sectional_ic_vectorised(p, r)


def icir(ic: np.ndarray) -> float:
    ic = ic[np.isfinite(ic)]
    if ic.size < 2 or np.std(ic) < 1e-12:
        return 0.0
    return float(np.mean(ic) / np.std(ic))


# --------------------------------------------------------------------------
# Returns
# --------------------------------------------------------------------------
def newey_west_tstat(returns: np.ndarray, max_lag: int | None = None) -> float:
    """t-statistic of mean return using Newey-West HAC standard errors.

    Trading strategies have materially autocorrelated daily returns (overlapping
    holding periods). Using the iid t-statistic systematically overstates
    significance.
    """
    r = np.asarray(returns, dtype=float)
    r = r[np.isfinite(r)]
    n = r.size
    if n < 20:
        return 0.0
    max_lag = int(4 * (n / 100.0) ** (2 / 9)) if max_lag is None else max_lag
    max_lag = max(0, min(max_lag, n - 2))

    mu = r.mean()
    e = r - mu
    gamma0 = np.dot(e, e) / n

    long_run = gamma0
    for lag in range(1, max_lag + 1):
        gl = np.dot(e[lag:], e[:-lag]) / n
        long_run += 2.0 * (1.0 - lag / (max_lag + 1.0)) * gl

    var_mean = long_run / n
    if var_mean <= 0:
        return 0.0
    return float(mu / math.sqrt(var_mean))


def annualised_sharpe(returns: np.ndarray, periods: int = 252) -> float:
    r = np.asarray(returns, dtype=float)
    r = r[np.isfinite(r)]
    if r.size < 2 or np.std(r) < 1e-15:
        return 0.0
    return float(np.sqrt(periods) * r.mean() / r.std())


def max_drawdown(returns: np.ndarray) -> float:
    r = np.asarray(returns, dtype=float)
    r = r[np.isfinite(r)]
    if r.size == 0:
        return 0.0
    equity = np.cumprod(1.0 + r)
    peak = np.maximum.accumulate(equity)
    dd = equity / peak - 1.0
    return float(dd.min())


def cumulative_return(returns: np.ndarray) -> float:
    r = np.asarray(returns, dtype=float)
    r = r[np.isfinite(r)]
    if r.size == 0:
        return 0.0
    return float(np.prod(1.0 + r) - 1.0)


# --------------------------------------------------------------------------
# Deflated Sharpe Ratio
# --------------------------------------------------------------------------
def deflated_sharpe(
    returns: np.ndarray,
    n_trials: int,
    periods: int = 252,
) -> dict[str, float]:
    """Deflated Sharpe Ratio: how unusual is this Sharpe given n trials tried?

    The expected maximum Sharpe under the null grows with the number of trials
    as approximately sqrt(2 ln N). A backtest that tried 100 configurations
    needs an observed Sharpe above roughly 3.0 to be interesting at all.

    Returns the deflated p-value, the observed Sharpe, the trial-adjusted
    expected maximum, and the raw p-value without deflation.
    """
    r = np.asarray(returns, dtype=float)
    r = r[np.isfinite(r)]
    n = r.size
    if n < 20:
        return {
            "sr": 0.0,
            "sr0": float("nan"),
            "p_value": 1.0,
            "deflated_p_value": 1.0,
            "n_trials": float(n_trials),
        }

    sd = np.std(r, ddof=1)
    sr = np.sqrt(periods) * np.mean(r) / sd if sd > 0 else 0.0

    skew = float(stats.skew(r))
    kurt = float(stats.kurtosis(r, fisher=False))

    # Lopez de Prado's expected maximum of N standard normals:
    #   E[max_N Z] = (1-g)Z(1-1/N) + gZ(1-1/(N e))
    # This is a STANDARDIZED quantity. Under the null, a Sharpe estimated over T
    # observations has standard error 1/sqrt(T), so the null benchmark for an
    # *observed* Sharpe is E[max_N Z] / sqrt(T). Omitting that 1/sqrt(T) is the
    # classic DSR implementation error: it compares an observed Sharpe against a
    # value ~16x too large in annualised terms and forces deflated_p -> 1.0 for
    # every input, including a genuine strong edge.
    n_trials = max(int(n_trials), 2)
    euler_gamma = 0.5772156649
    sr0_z = (1.0 - euler_gamma) * stats.norm.ppf(
        1.0 - 1.0 / n_trials
    ) + euler_gamma * stats.norm.ppf(1.0 - 1.0 / (n_trials * math.e))

    T = float(r.size)
    sr_daily = math.sqrt(sr**2 / periods)  # annualised Sharpe -> daily units
    sr0_daily = sr0_z / math.sqrt(T)  # null benchmark, daily units

    # DSR = Z[ (SR - SR*) sqrt(T-1) / sqrt(1 - g3 SR + (g4-1)/4 SR^2) ]
    denom = 1.0 - skew * sr_daily + ((kurt - 1.0) / 4.0) * sr_daily**2
    if denom <= 0:
        return {
            "sr": sr,
            "sr0_daily": sr0_daily,
            "sr0": sr0_daily * math.sqrt(periods),
            "p_value": 1.0,
            "deflated_p_value": 1.0,
            "n_trials": float(n_trials),
        }

    test_stat = (sr_daily - sr0_daily) * math.sqrt(T - 1.0) / math.sqrt(denom)
    deflated_p = float(1.0 - stats.norm.cdf(test_stat))
    raw_p = float(1.0 - stats.norm.cdf(sr_daily * math.sqrt(T - 1.0)))

    return {
        "sr": sr,
        "sr0_daily": sr0_daily,
        "sr0": sr0_daily * math.sqrt(periods),  # annualised, for reporting
        "sr0_z": sr0_z,
        "p_value": raw_p,
        "deflated_p_value": deflated_p,
        "n_trials": float(n_trials),
    }


# --------------------------------------------------------------------------
# Probability of Backtest Overfitting (CSCV)
# --------------------------------------------------------------------------
@dataclass
class PBO:
    pbo: float
    n_splits: int
    n_combos: int
    logits: np.ndarray


def probability_of_backtest_overfitting(
    performance_matrix: np.ndarray, n_splits: int = 8
) -> PBO:
    """Combinatorially Symmetric Cross-Validation PBO.

    Args:
        performance_matrix: (T, N) out-of-sample or per-config return series,
            one column per candidate strategy/configuration.
        n_splits: S, the number of contiguous subperiods. Split into S even and
            S/2 odd blocks; every choice of S/2 blocks forms an in-sample set,
            with the complement used out-of-sample.

    Returns:
        PBO = probability that the out-of-sample rank of the best in-sample
        configuration falls in the bottom half. PBO near 0.5 means the
        selection procedure has no skill and in-sample ranking is uninformative
        about out-of-sample ranking.
    """
    T, N = performance_matrix.shape
    if T < n_splits * 2 or N < 2:
        return PBO(pbo=float("nan"), n_splits=0, n_combos=0, logits=np.array([]))

    S = n_splits if n_splits % 2 == 0 else n_splits + 1
    blocks = np.array_split(np.arange(T), S)

    half = S // 2
    logits: list[float] = []
    for combo in itertools.combinations(range(S), half):
        is_idx = np.concatenate([blocks[i] for i in combo])
        oos_idx = np.concatenate([blocks[i] for i in range(S) if i not in combo])
        if len(is_idx) == 0 or len(oos_idx) == 0:
            continue

        is_perf = performance_matrix[is_idx, :].mean(axis=0)
        oos_perf = performance_matrix[oos_idx, :].mean(axis=0)

        # Rank of the in-sample winner, then its out-of-sample rank (logit).
        winner = int(np.argmax(is_perf))
        oos_rank = stats.rankdata(oos_perf)[winner]
        n = len(oos_perf)
        pct = oos_rank / n
        # Log-odds centred on 0.5.
        pct = min(max(pct, 1e-6), 1 - 1e-6)
        logits.append(math.log(pct / (1 - pct)))

    if not logits:
        return PBO(pbo=float("nan"), n_splits=S, n_combos=0, logits=np.array([]))

    logits_arr = np.array(logits)
    pbo = float(np.mean(logits_arr < 0))
    return PBO(pbo=pbo, n_splits=S, n_combos=len(logits_arr), logits=logits_arr)


def selection_noise_floor(n_trials: int, periods: int = 252) -> float:
    """Annualised Sharpe a zero-edge process yields after N trials, over T days.

    IMPORTANT UNITS NOTE, because two estimators of this are commonly conflated:

      E[max_N Z] at N=100 is ~2.53 in STANDARDIZED units. Annualising that
      directly gives ~40, which is not a usable threshold. The observed Sharpe
      over T observations has standard error 1/sqrt(T), so the comparable
      benchmark is E[max_N Z] / sqrt(T) -- small, and appropriately so.

      The crude sqrt(2 ln N) = 3.03 is an asymptotic large-deviation rate, not
      the same estimator. It is the number usually quoted when discussing
      papers that "tried a handful of configurations", and it is the honest
      figure for that purpose -- but it must not be printed beside a DSR
      threshold computed a different way and called the same thing.

    We use the sqrt(2 ln N) form here because it is the industry-facing
    benchmark, and expose the E[max Z] form separately via `sr0_z` in the
    deflated_sharpe return dict. `periods` is accepted for interface symmetry
    and deliberately unused.
    """
    return float(math.sqrt(2.0 * math.log(max(int(n_trials), 2))))


def selection_noise_floor_crude(n_trials: int) -> float:
    """The sqrt(2 ln N) estimator, kept for reference and for comparisons to
    published backtest-overfitting commentary."""
    return float(math.sqrt(2.0 * math.log(max(int(n_trials), 2))))
