"""Baselines and trivial-rule controls.

Cheung, arXiv:2607.12248 is the reason this module exists:

    "An early LoRA adapter appeared to reach roughly 80% directional accuracy;
     we show this is not evidence of skill. Over a long horizon in a rising
     market, a trivial 'always-up' rule attains comparably high accuracy
     without using the input at all."

They replicated this on the NASDAQ-100 and S&P 500 and found the base rate is
about 0.70, with the fine-tuned model scoring *below* it and going negative at
six months.

Therefore: any directional-accuracy figure must be reported as **excess over
the unconditional base rate**, and a model that cannot beat the trivial rules
below has not demonstrated anything. The 2026 literature almost universally
fails to make this comparison, which is how inflated accuracy numbers survive
peer review.

These baselines also serve as the selection-noise floor for the PBO
calculation: the genuine model is compared against a population of
deliberately-naive strategies.

RETURN-CONVENTION CONTRACT
--------------------------
Every portfolio-return function in this module returns **daily** portfolio
returns produced by `portfolio_daily_returns`, identical to the model under
test. This is not tidiness, it is correctness.

An earlier version computed baselines as mean forward-return spreads over the
20-day overlapping horizon, then annualised the result with sqrt(252). That
reported an equal-weight basket Sharpe of 4.74 -- nonsense. A 20-day
overlapping period return is not a daily return, and consecutive such returns
share 19 of their 20 days, so the series is heavily autocorrelated; annualising
it by sqrt(252) overstates Sharpe by roughly sqrt(20).

A baseline measured on a different return convention than the model is not a
baseline. It either flatters the model or hides its edge, and either way the
comparison carries no information. Everything goes through one function.
"""

from __future__ import annotations

import numpy as np

from ..ops import decile_weights
from ..portfolio.construction import (
    equal_weight_weights,
    portfolio_daily_returns,
    throttle_weights,
)


def directional_accuracy(predictions: np.ndarray, realised: np.ndarray) -> dict:
    """Accuracy with and without the base rate, plus excess over always-up.

    Returns:
        dict with `accuracy`, `base_rate_always_up`, and
        `excess_over_base_rate`. Report the excess. The absolute number is
        close to meaningless in a trending sample.
    """
    p = np.asarray(predictions, dtype=float)
    r = np.asarray(realised, dtype=float)
    mask = np.isfinite(p) & np.isfinite(r)

    if mask.sum() == 0:
        return {
            "accuracy": float("nan"),
            "base_rate_always_up": float("nan"),
            "excess_over_base_rate": float("nan"),
            "n": 0,
        }

    p, r = p[mask], r[mask]
    correct = np.sign(p) == np.sign(r)
    acc = float(np.mean(correct))
    base = float(np.mean(r > 0))

    return {
        "accuracy": acc,
        "base_rate_always_up": base,
        "excess_over_base_rate": acc - base,
        "n": int(mask.size),
    }


# ---------------------------------------------------------------------------
# Portfolio-return baselines. All return (T,) daily portfolio returns.
# ---------------------------------------------------------------------------


def equal_weight_long_only(
    tradable: np.ndarray, ret: np.ndarray, rebalance_days: int = 1
) -> np.ndarray:
    """Long-only equal-weight basket over the tradable universe.

    The directional bar any active model must clear. It is LONG-ONLY while the
    model is dollar-neutral, so its Sharpe is not a like-for-like risk-adjusted
    comparison -- `market_return` below is. It is reported because "did you
    beat just buying the index" is the question readers actually ask.
    """
    w = equal_weight_weights(tradable)
    w = throttle_weights(w, rebalance_days)
    return portfolio_daily_returns(w, ret)


def market_return(
    tradable: np.ndarray, ret: np.ndarray, rebalance_days: int = 1
) -> np.ndarray:
    """Cross-sectionally demeaned book -- the long-short, like-for-like control.

    Holds every tradable name at 1/N then removes net exposure, giving a
    dollar-neutral book with zero security selection. Any Sharpe above this is
    attributable purely to choosing names, which is exactly the claim a
    cross-sectional strategy is making.
    """
    w = equal_weight_weights(tradable)
    w = throttle_weights(w, rebalance_days)
    return portfolio_daily_returns(w, ret)


def single_factor_portfolio(
    factor: np.ndarray,
    ret: np.ndarray,
    n_decile: float = 0.10,
    mask: np.ndarray | None = None,
    rebalance_days: int = 1,
) -> np.ndarray:
    """Long the top decile, short the bottom decile of a single factor.

    The honest reference for a learned model. If a 300-tree LambdaRank ensemble
    does not beat one signed factor with a decile spread, the model is adding
    cost and variance for nothing -- a common and underreported outcome.
    """
    f = np.asarray(factor, dtype=float).copy()
    if mask is not None:
        f = np.where(mask, f, np.nan)
    w = decile_weights(f, None, n_decile)
    w = throttle_weights(w, rebalance_days)
    return portfolio_daily_returns(w, ret)


def random_signal_portfolio(
    seed: int,
    shape: tuple[int, int],
    ret: np.ndarray,
    n_decile: float = 0.10,
    rebalance_days: int = 1,
) -> np.ndarray:
    """Decile book driven by a purely random score.

    Builds the null distribution for PBO. If the real model sits inside this
    spread, it has no demonstrated selection skill.
    """
    rng = np.random.default_rng(seed)
    noise = rng.standard_normal(shape)
    return single_factor_portfolio(noise, ret, n_decile, rebalance_days=rebalance_days)


def bootstrap_baseline_distribution(
    ret: np.ndarray,
    n_draws: int = 25,
    n_decile: float = 0.10,
    seed: int = 11,
    rebalance_days: int = 1,
) -> np.ndarray:
    """Population of random-score daily return series, for PBO.

    Returns:
        (T, n_draws) matrix of daily return series.
    """
    T, n = ret.shape
    return np.stack(
        [
            random_signal_portfolio(
                seed + i, (T, n), ret, n_decile, rebalance_days=rebalance_days
            )
            for i in range(n_draws)
        ],
        axis=1,
    )
