"""Gradient-boosted ranker (Layer 3).

Deliberately not a transformer. The evidence for that choice:

  - Zeng, Chen, Zhang & Xu, "Are Transformers Effective for Time Series
    Forecasting?" (arXiv:2205.13504): "LTSF-Linear surprisingly outperforms
    existing sophisticated Transformer-based LTSF models in all cases." The
    underdiscussed mechanism is that **self-attention is permutation-invariant**.
    In language, word order is partly recoverable from token identity; in a time
    series, ordering *is* the signal, and patching plus positional encoding is
    an acknowledged lossy compromise. Structural mismatch, not a tuning gap.

  - Wong & Barahona (arXiv:2301.00790) and a 2026 replication on ~300 US large
    caps over 11 years (arXiv:2608.27076) both find no tabular deep-learning
    architecture beating gradient-boosted trees.

  - Arnott, Harvey & Heaton (JFDS 2019) diagnose it precisely: finance is a
    low-n, high-dimensional, non-stationary, adaptive problem, and we are
    feeding it a method chosen for the opposite regime. At ~250 trading days a
    year, a cross-sectional model has ~3,000 labelled observations against
    ~1,200 features. That is ~1,000 parameters per training observation. No
    attention engineering fixes a sample-size problem.

Loss is **LambdaRank**, not MSE. Loss choice dominates pointwise MSE for a
ranking problem (arXiv:2510.14156, CIKM 2025), and what we care about is the
*ordering* of names, not the level of their returns.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np


@dataclass
class RankerConfig:
    n_estimators: int = 300
    learning_rate: float = 0.03
    num_leaves: int = 15
    max_depth: int = 4
    min_child_samples: int = 200
    subsample: float = 0.8
    subsample_freq: int = 1
    colsample_bytree: float = 0.7
    reg_lambda: float = 5.0
    n_jobs: int = 2
    random_state: int = 0


@dataclass
class FittedRanker:
    model: object
    feature_names: list[str] = field(default_factory=list)
    backend: str = "lightgbm"

    def predict(self, X: np.ndarray) -> np.ndarray:
        return np.asarray(self.model.predict(X), dtype=float)


def _flatten(X: np.ndarray, date_idx: np.ndarray) -> tuple[np.ndarray, list[int]]:
    """Flatten (T, n, d) -> (T*n, d), returning group sizes ordered by date.

    LightGBM's ranking objective needs rows contiguous by query group, with
    the query (here: date) presented in the same order as the `group` array.
    """
    T, n, d = X.shape
    flat = X.reshape(T * n, d)
    groups = [n] * T
    return flat, groups


def fit_ranker(
    X: np.ndarray,
    y: np.ndarray,
    date_idx: np.ndarray,
    train_dates: np.ndarray,
    config: RankerConfig | None = None,
    feature_names: list[str] | None = None,
) -> FittedRanker:
    """Fit a LambdaRank model on the dates listed in `train_dates`.

    Args:
        X: (T, n, d) feature tensor, NaN-filled where unavailable.
        y: (T, n) continuous target (forward excess return).
        date_idx: (T,) date index per row of X.
        train_dates: date indices to train on.
        config: hyperparameter set.
        feature_names: for diagnostics.

    Returns:
        FittedRanker with a `.predict` taking a (T, n, d) tensor.
    """
    cfg = config or RankerConfig()
    X = np.asarray(X, dtype=float)
    y = np.asarray(y, dtype=float)

    train_mask = np.isin(date_idx, train_dates)
    Xtr = X[train_mask]
    ytr = y[train_mask]

    # LightGBM ranking has a hard 10,000-row-per-query limit, and ranking
    # labels are only meaningful *within* a query. So: keep one query per date,
    # drop only dates whose label is unobservable, and bin within each group.
    # NaN features are left in place -- LightGBM routes them natively.
    groups = np.isfinite(ytr).sum(axis=1)
    keep_date = groups >= 30
    if keep_date.sum() < 10:
        raise ValueError(
            f"only {int(keep_date.sum())} usable training dates "
            f"(need >=10 with >=30 valid names each). "
            "Check factor warm-up windows and the walk-forward train length."
        )
    Xtr = Xtr[keep_date]
    ytr = ytr[keep_date]
    groups = groups[keep_date]

    valid_rows = np.isfinite(ytr)
    flat_X = Xtr[valid_rows]
    flat_y = ytr[valid_rows]
    labels = _rank_labels_by_group(flat_y, groups, n_bins=20)

    if flat_X.shape[0] < 500:
        raise ValueError(f"insufficient clean training rows: {flat_X.shape[0]}")

    try:
        from lightgbm import LGBMRanker

        model = LGBMRanker(
            objective="lambdarank",
            metric="ndcg",
            n_estimators=cfg.n_estimators,
            learning_rate=cfg.learning_rate,
            num_leaves=cfg.num_leaves,
            max_depth=cfg.max_depth,
            min_child_samples=cfg.min_child_samples,
            subsample=cfg.subsample,
            subsample_freq=cfg.subsample_freq,
            colsample_bytree=cfg.colsample_bytree,
            reg_lambda=cfg.reg_lambda,
            random_state=cfg.random_state,
            n_jobs=cfg.n_jobs,
            verbose=-1,
        )
        model.fit(flat_X, labels, group=list(groups))
        backend = "lightgbm"
    except Exception:  # pragma: no cover - exercised only if lightgbm missing
        from sklearn.ensemble import HistGradientBoostingRegressor

        model = HistGradientBoostingRegressor(
            max_iter=cfg.n_estimators,
            learning_rate=cfg.learning_rate,
            max_leaf_nodes=cfg.num_leaves,
            min_samples_leaf=cfg.min_child_samples,
            l2_regularization=cfg.reg_lambda,
            random_state=cfg.random_state,
        )
        model.fit(flat_X, flat_y)
        backend = "sklearn"

    return FittedRanker(model=model, feature_names=feature_names or [], backend=backend)


def _rank_labels_by_group(
    y: np.ndarray, groups: np.ndarray, n_bins: int = 20
) -> np.ndarray:
    """Bin each query group's targets into quantile ranks independently.

    Cross-sectional quantile binning does two useful things: it makes the
    ranking loss robust to fat tails, and it makes the target comparable
    across high- and low-volatility regimes. Binning must be per group --
    a label of 7 means "7th quintile *within this date*", which is what
    LambdaRank requires.
    """
    from scipy import stats as _stats

    labels = np.zeros(y.size, dtype=int)
    start = 0
    for g in groups:
        g = int(g)
        if g > 1:
            sub = y[start : start + g]
            ranks = _stats.rankdata(sub)
            binned = ((ranks - 1) / max(g - 1, 1) * n_bins).astype(int)
            labels[start : start + g] = np.clip(binned, 0, None) + 1
        start += g
    return labels


def predict_scores(ranker: FittedRanker, X: np.ndarray) -> np.ndarray:
    """Produce (T, n) cross-sectional scores, NaN where inputs are NaN."""
    X = np.asarray(X, dtype=float)
    T, n, d = X.shape
    flat = X.reshape(T * n, d)

    # LightGBM handles NaN natively, but if a row is entirely NaN it is
    # meaningless. Impute column medians from the training period instead.
    all_nan = ~np.isfinite(flat).any(axis=1)
    if all_nan.any():
        col_median = np.nanmedian(flat, axis=0)
        col_median = np.where(np.isfinite(col_median), col_median, 0.0)
        flat[all_nan] = col_median

    scores = ranker.predict(flat).reshape(T, n)
    scores[all_nan.reshape(T, n)] = np.nan
    return scores
