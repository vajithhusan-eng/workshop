"""Layer 2: the microstructure regime gate.

This is the component that distinguishes this design, and it exists because of
a specific 2026 result.

Kurth, Eisler, Rej & Bouchaud, "Is Trend Still Your Friend? A Microstructural
Account of the Demise of Short-Term Trend-Following" (arXiv:2607.01550) studied
~100 liquid futures from 1995-2025. Systematic trend following had been
profitable for at least two centuries. From roughly 2009, short-term trends
stopped delivering. The authors rejected capacity, electronification and
CTA-vs-order-flow explanations on grounds of timing, magnitude or cross-sectional
heterogeneity.

The one variable that survived: **volatility-normalised tick size**. Post-2008
trend PnL collapsed on small-tick contracts across all signal horizons while
remaining essentially intact on large-tick ones. The mechanism is a
self-fulfilling feedback loop: trend signals produce directional trades whose
market impact reinforces the move. Post-crisis, HFT-dominated market making
withdraws liquidity in front of predictable directional flow, which breaks the
loop on sparse books and preserves it on dense ones.

Two consequences that shape this module:

  1. A **calendar-based** regime classifier physically cannot see this. It
     looks at dates, not books, so it will happily re-learn a dead signal every
     few years.
  2. The loop's profitability is a function of **book microstructure, not model
     skill**. Much of what transformers are credited with discovering in
     2010-2024 OHLCV may be this impact loop. A model trained on 2005-2015 is
     partly learning an artifact that no longer pays.

So the gate keys on book-density proxies computed from the panel itself. It is
**unsupervised**: in real trading the latent "dense vs sparse book" state is not
observable, so we route by terciles of an observable microstructure score and
train a separate ranker per tercile. Nothing here requires a regime label.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from ..config import MIN_DOLLAR_VOLUME

# Weights for the book-density score. Higher score = denser book = trend
# follow-through more likely to be reinforced by impact.
#
# `spread_proxy` is DELIBERATELY EXCLUDED (weight 0.0). It was included at
# -0.40 originally, on the reasonable theory that tighter quotes imply a denser
# book. Measured against latent density it correlates at only -0.04, because
# (high - low) / close is dominated by realised volatility, not quoting spread.
# It added noise and diluted the score. Depth proxies carry the signal alone.
#
# The lesson generalises: a plausible-sounding feature is not a working
# feature. Measure each one against ground truth before trusting it.
_DENSITY_WEIGHTS = {
    "neg_spread": 0.00,  # measured uninformative -- see note above
    "log_depth": +0.60,  # high dollar volume -> dense book
    "tradeable_frac": +0.40,  # many names clearing the liquidity floor
}


@dataclass
class MicrostructureFeatures:
    """Date-level observables. None of these require a label."""

    dates: np.ndarray
    spread_proxy: np.ndarray  # (T,) mean (high-low)/close
    log_depth: np.ndarray  # (T,) log median dollar volume
    tradeable_frac: np.ndarray  # (T,) fraction of names above liquidity floor
    density_score: np.ndarray  # (T,) higher = denser book
    tercile: np.ndarray  # (T,) 0 = sparse, 1 = mid, 2 = dense


def compute_microstructure_features(panel) -> MicrostructureFeatures:
    """Compute observable, date-level book-density proxies.

    Args:
        panel: SyntheticPanel (or equivalent) with high/low/close/dollar_volume.

    Returns:
        MicrostructureFeatures with a z-scored density score and tercile labels.
    """
    high = np.asarray(panel.high, dtype=float)
    low = np.asarray(panel.low, dtype=float)
    close = np.asarray(panel.close, dtype=float)
    dv = np.asarray(panel.dollar_volume, dtype=float)

    T = close.shape[0]
    rel_range = (high - low) / np.maximum(close, 1e-9)

    spread_proxy = np.nanmean(rel_range, axis=1)
    with np.errstate(invalid="ignore"):
        median_dv = np.nanmedian(dv, axis=1)
    log_depth = np.log(np.maximum(median_dv, 1.0))
    tradeable_frac = np.mean(dv >= MIN_DOLLAR_VOLUME, axis=1)

    # Robust standardisation: outlier dates must not dominate the score.
    def z(x: np.ndarray) -> np.ndarray:
        med = np.nanmedian(x)
        mad = np.nanmedian(np.abs(x - med))
        scale = 1.4826 * mad
        if not np.isfinite(scale) or scale < 1e-12:
            sd = np.nanstd(x)
            scale = sd if np.isfinite(sd) and sd > 1e-12 else 1.0
        return (x - med) / scale

    density_score = (
        _DENSITY_WEIGHTS["neg_spread"] * z(spread_proxy)
        + _DENSITY_WEIGHTS["log_depth"] * z(log_depth)
        + _DENSITY_WEIGHTS["tradeable_frac"] * z(tradeable_frac)
    )

    tercile = np.full(T, 1, dtype=int)
    lo, hi = np.nanpercentile(density_score, [33.333, 66.667])
    tercile[density_score < lo] = 0
    tercile[density_score > hi] = 2

    return MicrostructureFeatures(
        dates=np.asarray(panel.dates)[:T],
        spread_proxy=spread_proxy,
        log_depth=log_depth,
        tradeable_frac=tradeable_frac,
        density_score=density_score,
        tercile=tercile,
    )


def gate_agreement(mf: MicrostructureFeatures, latent_dense: np.ndarray) -> dict:
    """Diagnostic: does the observable score track the latent book state?

    Only meaningful on synthetic data where the latent label exists. In real
    data this is the single most important number to watch as a live diagnostic:
    if the score stops discriminating, the gate has lost its anchor and the
    routing is arbitrary.

    Args:
        mf: features from `compute_microstructure_features`.
        latent_dense: (T,) 0/1 latent dense-book indicator.

    Returns:
        Correlation between score and latent label, plus AUC of ranking dates
        by score against the label, plus accuracy of the dense-tercile call.
    """
    from scipy import stats as _stats

    lab = np.asarray(latent_dense, dtype=float)
    score = mf.density_score
    mask = np.isfinite(score) & np.isfinite(lab)
    score, lab = score[mask], lab[mask]

    if score.size < 20 or np.std(score) < 1e-12 or np.all(lab == lab[0]):
        return {
            "pearson": float("nan"),
            "spearman": float("nan"),
            "auc": float("nan"),
            "dense_tercile_accuracy": float("nan"),
            "n": int(score.size),
        }

    pear = float(np.corrcoef(score, lab)[0, 1])
    spear = float(_stats.spearmanr(score, lab).statistic)

    # AUC of score -> dense label, via Mann-Whitney U.
    n1 = float(np.sum(lab == 1))
    n0 = float(np.sum(lab == 0))
    if n0 > 0 and n1 > 0:
        ranks = _stats.rankdata(score)
        u = np.sum(ranks[lab == 1]) - n1 * (n1 + 1) / 2.0
        auc = float(u / (n0 * n1))
    else:
        auc = float("nan")

    dense_tercile = mf.tercile[mask] == 2
    acc = float(np.mean(dense_tercile == (lab == 1))) if mask.sum() else float("nan")

    return {
        "pearson": pear,
        "spearman": spear,
        "auc": auc,
        "dense_tercile_accuracy": acc,
        "n": int(score.size),
    }
