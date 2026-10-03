"""Price/volume factor family (Layer 1A).

These are deliberately classical. Gu, Kelly & Xiu, "Empirical Asset Pricing via
Machine Learning" (RFS 2020, ~2520 citations) found that trees and neural nets
disagree most on the same dominant signals: variations on **momentum, liquidity
and volatility**. Newer deep architectures have not displaced them; a 2026 study
of ~300 US large caps over 11 years found no tabular deep-learning architecture
beating gradient-boosted trees.

Implication: the feature set is not where you win. It is the regime gate,
the cost model, and the validation discipline that are worth engineering.

Every factor is computed from information available at the close of date t and
is used to predict the return from t+1 onward. Nothing here looks forward.
"""

from __future__ import annotations

import numpy as np

from ..config import (
    AMIHUD_WINDOW,
    IDIOVOL_WINDOW,
    MOM_LONG,
    MOM_SHORT,
    MOM_SKIP,
    REVERSAL_SHORT,
)


def _rolling_apply(x: np.ndarray, window: int, fn) -> np.ndarray:
    """Deprecated: use `ops.trailing_apply` with a named pandas aggregation.

    Retained only so external callers importing this private helper keep
    working. The looped form dominated runtime at T=2510.
    """
    from ..ops import trailing_apply

    table = {
        np.nanmean: "mean",
        np.nanmax: "max",
        np.nanstd: "std",
        np.nanmin: "min",
    }.get(fn)
    if table is not None:
        return trailing_apply(x, window, table)
    raise ValueError(
        f"_rolling_apply no longer supports arbitrary callables; "
        f"use ops.trailing_apply(x, {window}, '<aggregation>')"
    )


def _log(panel, field: str) -> np.ndarray:
    return np.log(np.maximum(getattr(panel, field), 1e-9))


def compute_price_volume_factors(panel) -> dict[str, np.ndarray]:
    """Compute the Layer 1A factor panel.

    Args:
        panel: a SyntheticPanel or any object exposing the OHLCV fields.

    Returns:
        dict of (T, n) arrays. Leading rows are NaN where the window has not
        filled. Direction is raw -- cross-sectional standardisation happens in
        the pipeline, because these are inputs to a ranker rather than
        stand-alone long/short rules.
    """
    close = np.asarray(panel.close, dtype=float)
    T, n = close.shape
    log_close = np.log(np.maximum(close, 1e-9))
    dollar_volume = np.asarray(panel.dollar_volume, dtype=float)
    log_ret = np.diff(log_close, axis=0, prepend=log_close[:1])

    factors: dict[str, np.ndarray] = {}

    # --- 12-1 momentum: t-252 to t-21, skipping the most recent month. ---
    mom_12_1 = np.full(close.shape, np.nan)
    if close.shape[0] > MOM_LONG:
        # row i gets log_close[i - MOM_SKIP] - log_close[i - MOM_LONG]
        mom_12_1[MOM_LONG:] = (
            log_close[MOM_LONG - MOM_SKIP : T - MOM_SKIP] - log_close[: T - MOM_LONG]
        )
    factors["mom_12_1"] = mom_12_1

    # --- Medium-horizon momentum (21d). ---
    if close.shape[0] > MOM_SHORT:
        factors["mom_21"] = np.full(close.shape, np.nan)
        factors["mom_21"][MOM_SHORT:] = log_close[MOM_SHORT:] - log_close[:-MOM_SHORT]

    # --- Short-horizon reversal (5d), sign-flipped so higher = more expected
    #     return under the sparse-book regime. ---
    if close.shape[0] > REVERSAL_SHORT:
        factors["reversal_5"] = np.full(close.shape, np.nan)
        factors["reversal_5"][REVERSAL_SHORT:] = -(
            log_close[REVERSAL_SHORT:] - log_close[:-REVERSAL_SHORT]
        )

    # --- Amihud illiquidity: |ret| per unit dollar volume. Higher = more
    #     illiquid = higher expected return (size/illiquidity premium), but
    #     also more expensive to trade, which the cost model charges for. ---
    amihud = np.full(close.shape, np.nan)
    valid = dollar_volume > 0
    amihud_num = np.where(
        valid, np.abs(log_ret) / np.maximum(dollar_volume, 1.0), np.nan
    )
    factors["amihud_20"] = _rolling_apply(amihud_num, AMIHUD_WINDOW, np.nanmean)

    # --- Log dollar volume (liquidity). Low liquidity -> higher expected
    #     return; Gu-Kelly-Xiu list liquidity as a dominant signal. ---
    factors["log_dollar_volume"] = np.log(np.maximum(dollar_volume, 1.0))

    # --- Idiosyncratic volatility: residual vol after removing market beta.
    market = np.nanmean(log_ret, axis=1, keepdims=True)
    excess = log_ret - market
    factors["idio_vol_60"] = _rolling_apply(excess, IDIOVOL_WINDOW, np.nanstd)

    # --- 52-week high proximity (George & Hwang). Closer to the high ->
    #     continuation. ---
    if close.shape[0] > MOM_LONG:
        roll_max = _rolling_apply(log_close, MOM_LONG, np.nanmax)
        factors["high_52w"] = log_close - roll_max

    # --- Realised volatility, 20d. Scaling input for the model. ---
    factors["realised_vol_20"] = _rolling_apply(log_ret, 20, np.nanstd) * np.sqrt(252.0)

    # --- Range-based illiquidity proxy: (high-low)/close, 20d mean.
    if hasattr(panel, "high") and hasattr(panel, "low"):
        rng_frac = (
            np.asarray(panel.high, dtype=float) - np.asarray(panel.low, dtype=float)
        ) / np.maximum(close, 1e-9)
        factors["range_20"] = _rolling_apply(rng_frac, 20, np.nanmean)
    else:
        factors["range_20"] = np.full(close.shape, np.nan)

    return factors


FACTOR_DESCRIPTIONS: dict[str, str] = {
    "mom_12_1": "12-1 month momentum (skips most recent month)",
    "mom_21": "1-month momentum",
    "reversal_5": "5-day short-horizon reversal, sign-flipped",
    "amihud_20": "Amihud illiquidity, 20d mean",
    "log_dollar_volume": "log dollar volume (liquidity)",
    "idio_vol_60": "idiosyncratic volatility, 60d",
    "high_52w": "52-week high proximity",
    "realised_vol_20": "annualised realised volatility, 20d",
    "range_20": "mean intraday range, 20d",
}
