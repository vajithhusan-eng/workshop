"""Execution cost model.

Turnover is quoted as fraction of notional traded. Cost is charged on turnover,
never as a flat haircut on returns, and always with a sensitivity grid -- the
finding of arXiv:2603.20319 is that engine-level cost implementation is the
sole source of disagreement between otherwise-identical backtests.

Cost per unit traded (one way), as a fraction of notional:

    c = commission + effective_spread/2 + temporary + permanent

    temporary = IMPACT_ALPHA * TEMPORARY_SHARE * sigma_daily * sqrt(Q / ADV)
    permanent = IMPACT_ALPHA * PERMANENT_SHARE * sigma_daily * sqrt(Q / ADV)

The square-root impact law is the standard empirical regularity (Toru
Kubota / Bouchaud). sigma_daily is the stock's own daily volatility; Q/ADV is
the participation rate.
"""

from __future__ import annotations

import numpy as np

from ..config import (
    COMMISSION,
    EFFECTIVE_SPREAD,
    IMPACT_ALPHA,
    PERMANENT_IMPACT_SHARE,
    TEMPORARY_IMPACT_SHARE,
)


def per_unit_cost(
    sigma_daily: np.ndarray,
    participation: np.ndarray,
    commission: float = COMMISSION,
    effective_spread: float = EFFECTIVE_SPREAD,
    alpha: float = IMPACT_ALPHA,
) -> np.ndarray:
    """Cost per unit of notional traded, vectorised over names.

    Args:
        sigma_daily: (n,) daily volatility estimate per name.
        participation: (n,) Q/ADV for the order, as a fraction.

    Returns:
        (n,) cost fraction. Small-sigma, low-participation orders are
        dominated by the fixed commission + spread floor, which is the correct
        behaviour and the reason low-turnover strategies survive.
    """
    sigma_daily = np.asarray(sigma_daily, dtype=float)
    participation = np.asarray(participation, dtype=float)

    sqrt_part = np.sqrt(np.maximum(participation, 0.0))
    impact = IMPACT_ALPHA * sigma_daily * sqrt_part
    temporary = TEMPORARY_IMPACT_SHARE * impact
    permanent = PERMANENT_IMPACT_SHARE * impact

    return commission + 0.5 * effective_spread + temporary + permanent


def cost_from_bps(cost_bps: float) -> dict[str, float]:
    """Build a cost parameter set from a target one-way cost in basis points.

    Used for the sensitivity grid. The fixed costs are set so that a
    zero-participation order costs approximately the requested total, with the
    remaining budget available to impact at realistic participation rates.
    """
    target = cost_bps * 1e-4
    fixed = COMMISSION + 0.5 * EFFECTIVE_SPREAD
    # Leave 60% of the budget to impact, matching typical large-participation
    # intraday behaviour.
    fixed_share = min(fixed / target, 0.4) if target > fixed else 1.0
    commission = target * fixed_share
    return {
        "commission": commission,
        "effective_spread": max(2.0 * (target * fixed_share - commission), 0.0),
        "alpha": target * 0.6 / max(1e-9, IMPACT_ALPHA),
    }


def apply_costs(
    gross_returns: np.ndarray,
    prev_weights: np.ndarray,
    weights: np.ndarray,
    sigma_daily: np.ndarray,
    adv: np.ndarray,
    overrides: dict[str, float] | None = None,
) -> np.ndarray:
    """Deduct execution costs from a gross return stream.

    Args:
        gross_returns: (T, n) pre-cost daily portfolio returns.
        prev_weights: (T, n) drift-adjusted weights held entering today.
        weights: (T, n) target weights after today's trade.
        sigma_daily: (T, n) daily volatility per name per date.
        adv: (T, n) dollar volume per name per date.
        overrides: optional cost-parameter overrides from `cost_from_bps`.

    Returns:
        (T,) net daily portfolio returns after costs.

    Costs are charged on the traded notional only -- |w_t - w_{t-1}| summed
    across names, grossed by the traded side. This is the standard convention
    and it matters: charging on full notional double-counts a static book.
    """
    overrides = overrides or {}
    commission = overrides.get("commission", COMMISSION)
    spread = overrides.get("effective_spread", EFFECTIVE_SPREAD)
    alpha = overrides.get("alpha", IMPACT_ALPHA)

    traded = np.abs(weights - prev_weights)
    participation = np.divide(
        traded, np.maximum(adv, 1.0), out=np.zeros_like(traded), where=adv > 0
    )

    unit = per_unit_cost(sigma_daily, participation, commission, spread, alpha)
    # Cost is a *portfolio* quantity per day: the traded notional weighted by
    # its unit cost, summed across names. `gross_returns` is already the (T,)
    # portfolio return series, so it must be reduced across names too.
    cost_paid = np.sum(traded * unit, axis=1)

    return np.asarray(gross_returns, dtype=float) - cost_paid
