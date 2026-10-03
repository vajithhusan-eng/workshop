"""Deterministic synthetic panel generator.

This is not a toy. It is the harness's own control experiment, and it is the
only way to check the two things that matter most:

  1. POWER      -- given a real planted signal, does the validator recover it?
  2. SAFETY     -- given zero true edge, does the validator refuse to
                   manufacture one?

A backtest harness that has only ever been shown to be able to find a signal
when one exists has not been tested. Generate ``edge="null"`` and every reported
metric should come back indistinguishable from zero, with a large p-value. If it
does not, the harness has a leak and every future result is worthless.

Grounded in the microstructure finding of Kurth, Eisler, Rej & Bouchaud
(arXiv:2607.01550): trend persistence is a function of *book density*, not
calendar time. The generator therefore makes momentum pay in dense-book regimes
and short-horizon reversal pay in sparse-book regimes, with the regime itself
an unobservable latent state that the model must infer from microstructure
proxies.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from scipy import stats

from ..config import MIN_DOLLAR_VOLUME, MIN_MARKET_CAP


@dataclass
class SyntheticPanel:
    """A point-in-time daily panel with a known ground-truth signal."""

    dates: np.ndarray  # (T,)   business-day index labels
    tickers: np.ndarray  # (n,)
    open: np.ndarray  # (T, n)
    high: np.ndarray
    low: np.ndarray
    close: np.ndarray
    volume: np.ndarray  # (T, n) shares
    dollar_volume: np.ndarray  # (T, n)
    market_cap: np.ndarray  # (T, n) -- needed for point-in-time universe filtering
    true_signal: np.ndarray  # (T, n) expected forward return; 0 in null mode
    book_density: np.ndarray  # (T,)   latent, UNOBSERVABLE regime state in [0,1]
    regime_label: np.ndarray  # (T,)   1 = dense book, 0 = sparse book
    sigma_daily: np.ndarray  # (T, n)

    def __len__(self) -> int:
        return self.close.shape[0]


def generate_panel(
    seed: int = 7,
    n_names: int = 800,
    n_days: int = 2510,
    edge: str = "planted",
) -> SyntheticPanel:
    """Generate a synthetic point-in-time OHLCV panel.

    Args:
        seed: RNG seed. Fixed for reproducibility.
        n_names: cross-sectional universe size. Real research here is
            cross-sectional (300-5000 names); single-series backtests cannot be
            interpreted at all.
        n_days: trading days.
        edge: ``"planted"`` embeds a genuine, regime-dependent signal.
            ``"null"`` has zero exploitable edge by construction.

    Returns:
        A SyntheticPanel. In ``"null"`` mode the ``true_signal`` is identically
        zero, so any positive out-of-sample IC the harness reports is a bug.
    """
    if edge not in {"planted", "null"}:
        raise ValueError(f"edge must be 'planted' or 'null', got {edge!r}")

    rng = np.random.default_rng(seed)
    T, N = n_days, n_names

    # ------------------------------------------------------------------
    # 1. Latent regime: book density.
    #    Persistent, mean-reverting, unobservable. Drives both the realised
    #    microstructure and the sign of the trend payoff.
    # ------------------------------------------------------------------
    density = np.zeros(T)
    d = 0.55
    for t in range(1, T):
        d = 0.985 * d + 0.015 * 0.55 + rng.normal(0, 0.05)
        density[t] = np.clip(d, 0.02, 0.98)
    dense = (density > 0.5).astype(int)
    # Force both regimes to be well represented so the gate is testable.
    dense[: T // 8] = 0
    dense[-T // 8 :] = 0
    density = np.clip(density, 0.02, 0.98)

    # ------------------------------------------------------------------
    # 2. Static security characteristics.
    # ------------------------------------------------------------------
    log_cap = rng.normal(np.log(8e9), 1.0, N)
    shares = np.exp(rng.normal(np.log(3e7), 0.6, N))
    market_cap = np.exp(log_cap)[None, :] * np.ones((T, 1))

    idio_vol = np.exp(rng.normal(np.log(0.018), 0.30, N))
    beta = np.clip(rng.normal(1.0, 0.35, N), 0.2, 2.0)

    # Latent factor exposures. Momentum exposure is heterogeneous by
    # construction so cross-sectional ranking has something to find.
    mom_exposure = stats.norm.rvs(0, 1, N, random_state=rng)
    rev_exposure = stats.norm.rvs(0, 1, N, random_state=rng)

    # ------------------------------------------------------------------
    # 3. Latent factor returns.
    # ------------------------------------------------------------------
    market = rng.normal(0.0002, 0.011, T)

    # Momentum factor: persistent where books are dense, absent where sparse.
    mom_factor = np.zeros(T)
    for t in range(1, T):
        persistence = 0.55 if dense[t] else 0.0
        mom_factor[t] = persistence * mom_factor[t - 1] + rng.normal(0, 0.0022)

    # Short-horizon reversal factor: active where books are sparse.
    rev_factor = np.zeros(T)
    noise = rng.normal(0, 0.0020, T)
    for t in range(1, T):
        weight = 0.0 if dense[t] else 0.45
        rev_factor[t] = -weight * rev_factor[t - 1] + noise[t]

    if edge == "null":
        mom_factor = np.zeros(T)
        rev_factor = np.zeros(T)
        mom_exposure = np.zeros(N)
        rev_exposure = np.zeros(N)

    # Signal-to-noise calibration.
    #
    # This constant IS the control experiment, and it was originally 0.006 --
    # never calibrated. Measured signal/noise was 7.5e-4, roughly 65x below a
    # detectable edge, so the "planted" arm was statistically indistinguishable
    # from the "null" arm (RankIC 0.0019 vs 0.0011). Both returned NO RELIABLE
    # EDGE, which looked like a passing harness but proved nothing: a harness
    # that can never find a signal passes that test trivially.
    #
    # Calibrated by scanning against the ORACLE -- the RankIC of the true signal
    # against realised forward returns. At 6.0 the oracle measures 0.082-0.140
    # across seeds 3/7/11. That is at the strong end of what real published
    # equity factors achieve (Gu/Kelly/Xiu single factors: 0.02-0.05; Sidhu et
    # al. FinBERT on earnings calls: 0.142, unreplicated), so the power test
    # stays demanding: if this harness cannot recover an oracle-0.10 signal, it
    # cannot be trusted on a real one.
    #
    # The null arm is unaffected by this constant -- it zeroes the exposures
    # outright -- and holds at oracle RankIC ~0.006 across every scale tried.
    # That invariance is itself part of the test.
    signal_scale = 6.0
    signal_loading = signal_scale * (
        mom_exposure[None, :] * mom_factor[:, None]
        + 0.6 * rev_exposure[None, :] * rev_factor[:, None]
    )

    # ------------------------------------------------------------------
    # 4. Idiosyncratic returns with fat tails (Student-t, df=5).
    # ------------------------------------------------------------------
    df = 5
    fat_scale = math_sqrt(df / (df - 2.0))
    idio = rng.standard_t(df, (T, N)) * idio_vol[None, :] * fat_scale

    log_ret = beta[None, :] * market[:, None] + signal_loading + idio

    # ------------------------------------------------------------------
    # 5. Microstructure observables tied to the latent density.
    #    This is the information the regime gate is *allowed* to use.
    # ------------------------------------------------------------------
    # Spreads NARROW as books densify (less depth per order, tighter quotes).
    rel_spread = 0.0022 * np.exp(-1.9 * density) * np.exp(rng.normal(0, 0.28, T))
    # Liquidity RISES with book density: a dense book absorbs more flow, so
    # dollar volume and the tradeable fraction both increase. (An earlier
    # version had this inverted, which made the latent density inversely
    # related to every observable depth proxy and caused the regime gate to
    # score -0.31 against the truth -- a good reminder that a diagnostic
    # disagreeing with theory means the world model is wrong, not the gate.)
    base_turnover = np.exp(rng.normal(np.log(0.012), 0.35, T)) * np.exp(
        +1.2 * (density - 0.5)
    )  # (T,)
    volume = np.clip(
        base_turnover[:, None]
        * (idio_vol / idio_vol.mean())[None, :]
        * shares[None, :],
        1e3,
        None,
    )  # (T, N)

    # ------------------------------------------------------------------
    # 6. Price paths.
    # ------------------------------------------------------------------
    start_price = np.exp(rng.normal(np.log(45.0), 0.5, N))
    log_price = np.cumsum(log_ret, axis=0) + np.log(start_price)[None, :]
    close = np.exp(log_price)

    # Intraday range is a function of realised vol and the spread regime.
    range_frac = np.abs(log_ret) + 0.35 * rel_spread[:, None]
    hi_extra = np.abs(rng.normal(0, 0.45, (T, N))) * range_frac
    lo_extra = np.abs(rng.normal(0, 0.45, (T, N))) * range_frac
    high = close * np.exp(hi_extra)
    low = close * np.exp(-lo_extra)
    open_ = close * np.exp(rng.normal(0, 0.25, (T, N)) * range_frac)

    dollar_volume = volume * close
    sigma_daily = np.abs(log_ret) * np.sqrt(252.0)

    dates = np.arange(T)
    tickers = np.array([f"SYN{i:04d}" for i in range(N)])

    # Forward true signal, aligned so that row t is the expected return from
    # t+1 to t+horizon. Row 0 is undefined and set to zero.
    true_signal = np.zeros((T, N))
    true_signal[:-1] = signal_loading[1:]

    return SyntheticPanel(
        dates=dates,
        tickers=tickers,
        open=open_,
        high=high,
        low=low,
        close=close,
        volume=volume,
        dollar_volume=dollar_volume,
        market_cap=market_cap,
        true_signal=true_signal,
        book_density=density,
        regime_label=dense,
        sigma_daily=sigma_daily,
    )


def point_in_time_universe(panel: SyntheticPanel) -> np.ndarray:
    """Boolean (T, n) mask of names tradable *as of* each date.

    Liquidity filter uses only information available on the date itself. This
    is the survivorship/rank-size discipline from Gençay arXiv:2608.27734 -- no
    full-sample universe screening, ever.
    """
    cap_ok = (panel.market_cap >= MIN_MARKET_CAP) & (panel.market_cap <= 200e9)
    liq_ok = panel.dollar_volume >= MIN_DOLLAR_VOLUME
    return cap_ok & liq_ok & np.isfinite(panel.close)


def math_sqrt(x: float) -> float:
    """Local alias so the module reads cleanly without importing math broadly."""
    return float(x) ** 0.5
