"""Vectorised row-wise (cross-sectional) array operations.

Everything here operates on (T, n) panels where each row is one date and the
columns are securities. The naive implementation of these is a Python loop over
dates, which dominates runtime: at T=2510 with n=800 a single looped
cross-sectional correlation costs more than the entire model fit.

All functions preserve NaN. NaN means "not observable for this name on this
date" (outside the point-in-time universe, or in a factor warm-up window), and
silently coercing it to a number is exactly the kind of bug that manufactures
a backtest edge that does not exist.
"""

from __future__ import annotations

import numpy as np
import pandas as pd


def finite_mask(x: np.ndarray) -> np.ndarray:
    return np.isfinite(np.asarray(x, dtype=float))


def cross_sectional_rank_frac(x: np.ndarray) -> np.ndarray:
    """Percentile rank of each entry within its row, in (0, 1).

    Ties are broken by column index (stable sort) rather than averaged. This is
    deliberate. Factor panels are heavily tied -- an illiquidity ratio can be
    identical for many names on a date -- and averaging ties can leave a decile
    threshold with *zero* names above it, silently shrinking a sleeve. Ordinal
    tie-breaking guarantees exactly `n_decile * n` names per sleeve, which is
    what the decile machinery downstream assumes.

    NaN entries stay NaN. They are sorted last and then masked back out, so an
    untradable name can never be ranked as if it were the best signal.

    Args:
        x: (T, n) panel.

    Returns:
        (T, n) panel of percentile ranks in (0, 1).
    """
    x = np.asarray(x, dtype=float)
    T, n = x.shape

    finite = np.isfinite(x)
    # NaN -> +inf so it sorts last without disturbing the finite ordering.
    filled = np.where(finite, x, np.inf)

    order = np.argsort(filled, axis=1, kind="stable")
    ranks = np.empty((T, n), dtype=float)
    np.put_along_axis(
        ranks, order, np.broadcast_to(np.arange(n, dtype=float), (T, n)), axis=1
    )

    # Denominator is the per-row count of FINITE names, not the total n. On a
    # row that is partially outside the point-in-time universe, valid names
    # cannot reach the top of the full-n scale (e.g. 50/60 valid caps at
    # 50/61 ~ 0.82), which hollows the top sleeve and yields NaN from the
    # decile machinery. Fraction-of-valid restores "top decile" semantics on
    # exactly the tradable cross-section.
    n_valid = finite.sum(axis=1, keepdims=True).astype(float)
    out = (ranks + 1.0) / (n_valid + 1.0)
    out[~finite] = np.nan
    return out


def cross_sectional_zscore(x: np.ndarray, min_valid: int = 20) -> np.ndarray:
    """Row-wise z-score, NaN-safe.

    Returns NaN rows where fewer than `min_valid` entries are finite, so that
    ill-conditioned cross-sections never produce a spurious score.
    """
    x = np.asarray(x, dtype=float)
    mask = np.isfinite(x)
    counts = mask.sum(axis=1)

    xm = np.where(mask, x, 0.0)
    mean = xm.sum(axis=1) / np.maximum(counts, 1)
    dev = np.where(mask, x - mean[:, None], 0.0)
    var = (dev * dev).sum(axis=1) / np.maximum(counts, 1)
    sd = np.sqrt(var)

    with np.errstate(invalid="ignore", divide="ignore"):
        z = (x - mean[:, None]) / sd[:, None]

    bad = (counts < min_valid) | (sd < 1e-12)
    z[bad] = np.nan
    z[~mask] = np.nan
    return z


def row_masked_mean(x: np.ndarray, sel: np.ndarray) -> np.ndarray:
    """Mean of `x` over entries flagged by boolean `sel`, row-wise, NaN-safe."""
    x = np.asarray(x, dtype=float)
    sel = np.asarray(sel, dtype=bool)
    m = sel & np.isfinite(x)
    counts = m.sum(axis=1)
    total = np.where(m, np.nan_to_num(x), 0.0).sum(axis=1)
    with np.errstate(invalid="ignore", divide="ignore"):
        return np.where(counts > 0, total / np.maximum(counts, 1), np.nan)


def cross_sectional_ic_vectorised(
    predictions: np.ndarray, realised: np.ndarray, min_valid: int = 20
) -> np.ndarray:
    """Row-wise Pearson correlation, fully vectorised.

    For Spearman, pre-rank both panels with `cross_sectional_rank_frac` before
    calling this -- correlation of ranks *is* the Spearman coefficient.
    """
    p = np.asarray(predictions, dtype=float)
    r = np.asarray(realised, dtype=float)
    mask = np.isfinite(p) & np.isfinite(r)
    counts = mask.sum(axis=1)

    pm = np.where(mask, p, 0.0)
    rm = np.where(mask, r, 0.0)
    pmean = pm.sum(axis=1) / np.maximum(counts, 1)
    rmean = rm.sum(axis=1) / np.maximum(counts, 1)

    pc = np.where(mask, p - pmean[:, None], 0.0)
    rc = np.where(mask, r - rmean[:, None], 0.0)

    cov = (pc * rc).sum(axis=1)
    pv = np.sqrt((pc * pc).sum(axis=1))
    rv = np.sqrt((rc * rc).sum(axis=1))

    with np.errstate(invalid="ignore", divide="ignore"):
        ic = cov / np.maximum(pv * rv, 1e-15)

    bad = (counts < min_valid) | (pv < 1e-12) | (rv < 1e-12)
    ic[bad] = np.nan
    return ic


def decile_spread(
    factor: np.ndarray,
    forward_returns: np.ndarray,
    n_decile: float = 0.10,
    top: bool = True,
    bottom: bool = True,
) -> np.ndarray:
    """Vectorised long-top / short-bottom decile spread.

    Equivalent to ranking each date cross-sectionally, taking the top and
    bottom `n_decile` by name, and averaging forward returns within each sleeve.
    Fully vectorised over dates.

    Args:
        factor: (T, n) signal.
        forward_returns: (T, n) realised forward returns.
        n_decile: fraction of names per sleeve.
        top: include the long sleeve.
        bottom: include the short sleeve.

    Returns:
        (T,) sleeve-spread return series, NaN where the cross-section is too thin.
    """
    frac = cross_sectional_rank_frac(factor)
    # Ordinal tie-breaking means percentiles are 1/(n+1) .. n/(n+1), so the
    # thresholds below select exactly floor(n_decile * n) names per sleeve
    # whenever the cross-section is at least that large.
    t_hi = 1.0 - n_decile
    t_lo = n_decile

    out = np.zeros(frac.shape[0])
    terms, signs = [], []
    if top:
        terms.append(frac >= t_hi)
        signs.append(+1.0)
    if bottom:
        terms.append(frac <= t_lo)
        signs.append(-1.0)

    vals = []
    for sel, s in zip(terms, signs):
        vals.append(s * row_masked_mean(forward_returns, sel))

    if len(vals) == 2:
        out = 0.5 * (vals[0] + vals[1])
    elif len(vals) == 1:
        out = vals[0]

    thin = np.isfinite(frac).sum(axis=1) < 40
    out[thin] = np.nan
    return out


def trailing_apply(x: np.ndarray, window: int, how: str) -> np.ndarray:
    """Trailing-window reduction over the time axis of a (T, n) panel.

    Args:
        x: (T, n) panel.
        window: trailing window length in rows.
        how: any pandas rolling aggregation -- "mean", "max", "std", "sum".

    Returns:
        (T, n) panel; the first `window - 1` rows are NaN, matching the
        pandas default `min_periods=window`.
    """
    roll = getattr(
        pd.DataFrame(np.asarray(x, dtype=float)).rolling(window, min_periods=window),
        how,
    )()
    return roll.to_numpy()


def decile_weights(
    scores: np.ndarray,
    vols: np.ndarray | None = None,
    n_decile: float = 0.10,
) -> np.ndarray:
    """Vectorised dollar-neutral decile weights, optionally inverse-vol scaled.

    Args:
        scores: (T, n) signal. NaN entries are untradable and get weight 0.
        vols: (T, n) annualised volatility for inverse-vol sizing within sleeves.
        n_decile: fraction of names per sleeve.

    Returns:
        (T, n) weights, dollar-neutral per row, gross exposure ~1 before
        volatility scaling.
    """
    frac = cross_sectional_rank_frac(scores)
    lo, hi = 0.0, 1.0
    long_sel = frac >= (hi - n_decile * (hi - lo))
    short_sel = frac <= (lo + n_decile * (hi - lo))

    w = np.where(long_sel, 1.0, 0.0) - np.where(short_sel, 1.0, 0.0)
    w[~np.isfinite(scores)] = 0.0

    if vols is not None:
        with np.errstate(invalid="ignore", divide="ignore"):
            iv = 1.0 / np.maximum(vols, 1e-4)
        iv[~np.isfinite(iv)] = 0.0
        w = w * iv

    gross = np.abs(w).sum(axis=1, keepdims=True)
    with np.errstate(invalid="ignore", divide="ignore"):
        w = np.where(gross > 1e-12, w / np.maximum(gross, 1e-12), 0.0)

    # Dollar neutrality.
    w = w - w.mean(axis=1, keepdims=True)
    return w
