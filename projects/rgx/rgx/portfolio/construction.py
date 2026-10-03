"""Portfolio construction and sizing (Layer 4).

This layer is where most published "strategies" quietly fail. A signal with a
genuine information coefficient, traded with naive equal-weighting at high
turnover, produces a negative net return after realistic costs. The evidence is
consistent: at >20% annual turnover, realistic costs destroy more than half of
gross alpha, and a strategy needs roughly 6% annualised GROSS Sharpe to net 1.0.

Sizing rules used here, each with its justification:

  DECILE LONG/SHORT, DOLLAR-NEUTRAL
      Removes most market beta so the result reflects stock selection. The 2026
      tabular-DL study found near-zero beta alongside significant CAPM alpha,
      i.e. the alpha was selection, not exposure -- which is the only version
      worth claiming.

  INVERSE-VOLATILITY WEIGHTING (within each sleeve)
      A tractable approximation of risk parity: equal risk contribution rather
      than equal notional. Not a full covariance optimisation, but it removes
      the dominant driver of risk concentration, which is single-name vol.

  VOLATILITY TARGETING
      Scale the whole book to a constant annualised volatility, so the strategy
      takes consistent risk regardless of the regime's natural vol.

  QUARTER-KELLY
      Kelly maximises long-run growth but does NOT minimise drawdown; full Kelly
      produces 50%+ drawdowns even with a genuine edge. Maclean, Thorp & Ziemba
      ("The Kelly Capital Growth Investment Criterion") show fractional Kelly
      reduces volatility more than proportionally reducing expected growth, so
      half-Kelly is a real trade-off rather than a compromise of the theory.
      Concretely: full Kelly implies ~80% probability of a 20% drawdown; half
      Kelly ~50% probability of 50%.

  ADV PARTICIPATION CAP
      Hard cap at 2% of daily dollar volume. This is the single most-violated
      realism constraint in published backtests -- crypto and microcap studies
      routinely assume fills at the closing price regardless of order size.

  COST-AWARE REBALANCE
      Only trade where the score gap exceeds a friction threshold. AlphaOpsBench
      (arXiv:2609.31390) found execution costs *alter subsequent price paths*
      rather than acting only as ex-post deductions, so churn is not neutral.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from ..ops import decile_weights

from ..config import (
    DECILE_CUT,
    GROSS_LEVERAGE,
    KELLY_FRACTION,
    MAX_ADV_PARTICIPATION,
    TARGET_ANNUAL_VOL,
    TRADING_DAYS,
)


@dataclass
class PortfolioConfig:
    n_decile: float = DECILE_CUT
    target_ann_vol: float = TARGET_ANNUAL_VOL
    kelly_fraction: float = KELLY_FRACTION
    max_adv_participation: float = MAX_ADV_PARTICIPATION
    gross_leverage: float = GROSS_LEVERAGE
    dollar_neutral: bool = True
    inverse_vol_weighting: bool = True
    cap_positions: bool = True
    periods: int = TRADING_DAYS


def cross_sectional_zscore(x: np.ndarray) -> np.ndarray:
    """Z-score each row across names. NaN-safe."""
    mu = np.nanmean(x, axis=1, keepdims=True)
    sd = np.nanstd(x, axis=1, keepdims=True)
    sd = np.where(sd < 1e-12, np.nan, sd)
    return (x - mu) / sd


def build_weights(
    scores: np.ndarray,
    vols: np.ndarray,
    dollar_volume: np.ndarray,
    portfolio_value: np.ndarray,
    cfg: PortfolioConfig | None = None,
) -> np.ndarray:
    """Turn (T, n) scores into (T, n) target weights.

    Args:
        scores: (T, n) raw model scores. NaN excluded from the ranking.
        vols: (T, n) annualised volatility per name, for inverse-vol sizing.
        dollar_volume: (T, n) dollar ADV, for the participation cap.
        portfolio_value: (T,) notional to scale against.
        cfg: portfolio settings.

    Returns:
        (T, n) weights summing to ~0 (dollar-neutral) with gross exposure
        controlled. Untradable names get zero.
    """
    cfg = cfg or PortfolioConfig()
    T, n = scores.shape

    # --- Decile selection, inverse-vol sleeve sizing, dollar neutrality. ---
    # Fully vectorised over dates; the looped version dominated runtime.
    w = decile_weights(
        scores, vols if cfg.inverse_vol_weighting else None, cfg.n_decile
    )

    # --- Participation cap, relative to portfolio notional. ---
    if cfg.cap_positions:
        cap = (
            cfg.max_adv_participation
            * portfolio_value[:, None]
            / np.maximum(dollar_volume, 1.0)
        )
        cap[~np.isfinite(cap)] = 0.0
        w = np.clip(w, -cap, cap)
        # Renormalise gross exposure after clipping, unless the book vanished.
        gross = np.abs(w).sum(axis=1, keepdims=True)
        with np.errstate(invalid="ignore", divide="ignore"):
            w = (
                np.where(gross > 1e-12, w / np.maximum(gross, 1e-12), 0.0)
                * cfg.gross_leverage
            )

    # --- Dollar neutrality, reapplied after the cap. ---
    if cfg.dollar_neutral:
        w = w - w.mean(axis=1, keepdims=True)

    return w


def apply_vol_target(
    weights: np.ndarray,
    vols: np.ndarray,
    cfg: PortfolioConfig | None = None,
) -> np.ndarray:
    """Scale each date's book so portfolio vol hits the annualised target.

    Portfolio vol is estimated as the vol-weighted average single-name vol,
    which is the right first-order approximation for a dollar-neutral book with
    modest name correlations and avoids the instability of a full sample
    covariance estimate at this universe size.
    """
    cfg = cfg or PortfolioConfig()
    T, n = weights.shape
    out = np.zeros_like(weights)

    # Dollar-neutral book: long and short risk offset, so portfolio volatility
    # is approximated by twice the vol-weighted average single-name vol. This
    # avoids the estimation instability of a full sample covariance at this
    # universe size while still removing single-name vol as the risk driver.
    port_vol = np.array(
        [
            float(np.mean(np.abs(weights[t]) * np.nan_to_num(vols[t], nan=0.0)) * 2.0)
            for t in range(T)
        ]
    )
    port_vol = np.where(port_vol < 1e-6, np.nan, port_vol)

    scale = np.ones(T)
    med = np.nanmedian(port_vol)
    valid = np.isfinite(port_vol) & (port_vol > 1e-6)
    if valid.any():
        # Normalise to the in-sample median vol, then rescale the whole book so
        # that median maps to the target.
        scale[valid] = (med / port_vol[valid]) * (cfg.target_ann_vol / med)
    scale[~valid] = 1.0
    scale = np.clip(scale, 0.25, 4.0)

    for t in range(T):
        out[t] = weights[t] * scale[t]
    return out


def throttle_weights(weights: np.ndarray, every_n: int = 1) -> np.ndarray:
    """Hold the target book steady between scheduled rebalances.

    Rebalancing a decile book every single day is not what any practitioner
    does, and it is why an unmodified version of this pipeline reported 1314%
    annual turnover -- which at 10bps per side is roughly a 130% annual
    round-trip drag, more than any plausible equity alpha.

    A 20-day forward-return label also does not justify daily trading: the
    score on day t is essentially unchanged from day t+1, so daily
    rebalancing pays costs to reproduce yesterday's book. Matching the
    rebalance frequency to the signal's own horizon is both realistic and
    cheaper, and it is a decision that must be made explicitly because it
    changes the reported result.

    Args:
        weights: (T, n) target weights.
        every_n: rebalance every `every_n` days. 1 = daily (no throttling).

    Returns:
        (T, n) weights held constant within each rebalance block.
    """
    if every_n <= 1:
        return weights
    T = weights.shape[0]
    # Map each date to the most recent scheduled rebalance date.
    anchor = (np.arange(T) // every_n) * every_n
    return weights[anchor]


def portfolio_daily_returns(weights: np.ndarray, ret: np.ndarray) -> np.ndarray:
    """Daily portfolio returns under a fixed alignment convention.

    ALIGNMENT CONTRACT, used identically by the model and by every baseline:

        weights[t] is computed from information available through the close of
        day t. It is therefore HELD during day t+1 and earns ret[t+1].

    Getting this backwards is the single most common look-ahead bug in
    backtesting, and it is invisible in the output -- a strategy that peeks
    simply looks better. This function is the only place the convention is
    encoded, so it cannot drift between the model and its comparators.

    Args:
        weights: (T, n) target weights.
        ret: (T, n) simple daily per-name returns. ret[0] is ignored.

    Returns:
        (T,) daily portfolio returns, un-costed.
    """
    weights = np.asarray(weights, dtype=float)
    ret = np.asarray(ret, dtype=float)
    out = np.zeros(weights.shape[0])
    w = np.nan_to_num(weights[:-1], nan=0.0, posinf=0.0, neginf=0.0)
    r = np.nan_to_num(ret[1:], nan=0.0, posinf=0.0, neginf=0.0)
    out[1:] = np.sum(w * r, axis=1)
    return out


def equal_weight_weights(tradable: np.ndarray) -> np.ndarray:
    """Long-only equal-weight book over whatever is tradable on each date.

    Returns weights summing to 1.0 per row, so this is directly comparable
    to the dollar-neutral model without a rescaling fudge.
    """
    m = np.asarray(tradable, dtype=bool)
    w = m.astype(float)
    counts = m.sum(axis=1, keepdims=True)
    with np.errstate(invalid="ignore", divide="ignore"):
        w = np.where(counts > 0, w / np.maximum(counts, 1), 0.0)
    return w


def kelly_scale(
    win_rate: float,
    avg_win: float,
    avg_loss: float,
    fraction: float = KELLY_FRACTION,
) -> float:
    """Fractional-Kelly exposure scalar from realised trade statistics.

    f* = p/b - q/a  where b is the win/loss ratio. We take `fraction` of it and
    clip, because the estimated edge carries sampling error and full exposure on
    an over-estimated edge is the main way Kelly destroys accounts.
    """
    a = abs(avg_loss)
    b = abs(avg_win)
    if a < 1e-9 or b < 1e-9:
        return 0.0
    p = float(np.clip(win_rate, 0.0, 1.0))
    q = 1.0 - p
    f_star = p / b - q / a
    return float(np.clip(fraction * f_star, 0.0, 2.0))
