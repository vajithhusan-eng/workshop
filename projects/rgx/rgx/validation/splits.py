"""Validation splits: walk-forward and purged/embargoed cross-validation.

Two distinct jobs, both required:

  WALK-FORWARD
      The industry standard for realistic trading simulation. Train on a
      trailing window, test on the immediately following period, roll forward.
      Preserves time ordering, which is the property that actually matters for a
      strategy you intend to trade. Arian et al. (2024, Expert Systems with
      Applications) confirm walk-forward remains the industry standard even
      while Combinatorial Purged CV is the better overfitting mitigation.

  COMBINATORIAL PURGED CV (CPCV)
      Produces a *distribution* of out-of-sample performance rather than a
      single number. With N groups there are C(N, k) train/test partitions,
      giving multiple paths through the data and therefore a spread you can
      quote. A single walk-forward number has no error bar; this does.

Both purge. With a 20-day forward-return label, a training sample at time t
consumes information through t+20. Training naively on data that overlaps the
test period leaks the label boundary. Purging removes training samples whose
label window overlaps the test window; the embargo removes a buffer beyond it,
to handle serial dependence in feature construction.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from ..config import EMBARGO_DAYS


@dataclass
class WalkForwardFold:
    train_idx: np.ndarray  # date indices for training
    test_idx: np.ndarray  # date indices for testing


@dataclass
class CPCVFold:
    train_idx: np.ndarray
    test_idx: np.ndarray


def _label_end(t: int, horizon: int) -> int:
    return t + horizon


def walk_forward_splits(
    n_dates: int,
    train_years: int = 5,
    test_months: int = 6,
    horizon: int = 20,
    embargo: int = EMBARGO_DAYS,
    periods: int = 252,
) -> list[WalkForwardFold]:
    """Rolling walk-forward folds with an embargo at the test boundary.

    The embargo gap sits between train and test so that any serial dependence
    in rolling feature construction (a 60-day volatility estimate, say) cannot
    carry information backwards across the boundary.
    """
    train_len = int(train_years * periods)
    test_len = int(test_months / 12 * periods)
    step = test_len

    folds: list[WalkForwardFold] = []
    start = 0
    while True:
        train_end = start + train_len
        test_start = train_end + embargo
        test_end = test_start + test_len
        if test_end > n_dates:
            break
        train_idx = np.arange(start, train_end)
        # Drop the last `horizon` training rows: their labels would reach into
        # the test window even after the embargo.
        train_idx = train_idx[train_idx < train_end - horizon]
        test_idx = np.arange(test_start, test_end)
        if train_idx.size >= horizon * 3 and test_idx.size > 0:
            folds.append(WalkForwardFold(train_idx=train_idx, test_idx=test_idx))
        start += step
    return folds


def purged_kfold_splits(
    n_dates: int,
    n_groups: int = 6,
    horizon: int = 20,
    embargo: int = EMBARGO_DAYS,
) -> list[CPCVFold]:
    """K-fold with purging of label-overlapping samples and an embargo.

    Test folds are held out contiguously. Training samples are dropped when
    their forward label window reaches into the held-out block, plus an
    additional embargo band on either side to absorb serial dependence.
    """
    group_bounds = np.array_split(np.arange(n_dates), n_groups)
    folds: list[CPCVFold] = []

    for gi, bounds in enumerate(group_bounds):
        test_idx = bounds
        test_lo, test_hi = int(test_idx[0]), int(test_idx[-1]) + 1

        train_parts = []
        for gj, other in enumerate(group_bounds):
            if gj == gi:
                continue
            train_parts.append(other)

        train_idx = np.concatenate(train_parts)
        # Purge: drop training rows whose label window [t, t+horizon] overlaps
        # [test_lo - embargo, test_hi + embargo).
        lo = test_lo - embargo
        hi = test_hi + embargo
        keep = (train_idx + horizon < lo) | (train_idx > hi)
        train_idx = train_idx[keep]

        if train_idx.size > 0 and test_idx.size > 0:
            folds.append(CPCVFold(train_idx=train_idx, test_idx=test_idx))
    return folds


def combinatorial_purged_cv(
    n_dates: int,
    n_groups: int = 6,
    k_train: int = 3,
    horizon: int = 20,
    embargo: int = EMBARGO_DAYS,
) -> list[CPCVFold]:
    """Combinatorial Purged Cross-Validation.

    Every subset of `k_train` groups forms a training set, with the complement
    used for testing. Produces C(n_groups, k_train) folds, hence a distribution
    of out-of-sample results rather than a point estimate. This is the
    overfitting mitigation Arian et al. (2024) found superior, and the reason a
    strategy can be reported honestly as "OOS Sharpe 0.4 to 1.1 depending on
    path" instead of a single flattering number.
    """
    from itertools import combinations

    group_bounds = np.array_split(np.arange(n_dates), n_groups)
    folds: list[CPCVFold] = []

    for combo in combinations(range(n_groups), k_train):
        train_idx = np.concatenate([group_bounds[i] for i in combo])
        test_parts = [group_bounds[i] for i in range(n_groups) if i not in combo]
        test_idx = np.concatenate(test_parts)

        test_lo, test_hi = int(test_idx.min()), int(test_idx.max()) + 1
        lo = test_lo - embargo
        hi = test_hi + embargo
        keep = (train_idx + horizon < lo) | (train_idx > hi)
        train_idx = train_idx[keep]

        if train_idx.size > horizon * 2 and test_idx.size > 0:
            folds.append(CPCVFold(train_idx=train_idx, test_idx=test_idx))
    return folds


def forward_overlapping_returns(close: np.ndarray, horizon: int = 20) -> np.ndarray:
    """Forward *overlapping* return: P[t+1..t+h]/P[t] - 1, aligned to row t.

    Returns (T, n) with the last `horizon` rows NaN because their label is not
    yet observable. Overlapping horizons are correct for a 20-day holding
    strategy; the autocorrelation they induce is exactly why the Sharpe
    inference in metrics.py uses Newey-West rather than an iid t-statistic.
    """
    T, n = close.shape
    fwd = np.full((T, n), np.nan)
    if T <= horizon:
        return fwd
    fwd[: T - horizon] = close[horizon:] / close[: T - horizon] - 1.0
    return fwd
