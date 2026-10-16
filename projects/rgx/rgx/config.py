"""Frozen configuration for the RGX research harness.

Every constant that affects a reported number lives here so that results are
reproducible and so that a reader can see the whole assumption set in one place.

Reference: arXiv:2603.20319 (implementation risk in backtesting) argues that
backtest engines, not just strategies, are a first-order source of error. The
response is to keep the execution assumptions explicit, centralised, and
sensitivity-tested.
"""

from __future__ import annotations

from dataclasses import dataclass, field

# --------------------------------------------------------------------------
# Universe
# --------------------------------------------------------------------------
# Point-in-time universe bounds. Names outside the PIT market-cap band at a
# given date must be excluded *as of that date*, never using end-of-sample data.
# See Gençay arXiv:2608.27734 -- leakage must be prevented architecturally.
MIN_MARKET_CAP = 2.0e9
MAX_MARKET_CAP = 200.0e9

# Index membership floor for tradability (ADV proxy handled separately).
MIN_DOLLAR_VOLUME = 5.0e6

# --------------------------------------------------------------------------
# Signal / label horizon
# --------------------------------------------------------------------------
FORWARD_RETURN_DAYS = 20
LABEL_HORIZON = 20

# Long-term and short-term windows for the price/volume factor family.
MOM_LONG = 252
MOM_SKIP = 21  # 12-1 momentum: skip the most recent month to avoid short-term reversal
MOM_SHORT = 21
REVERSAL_SHORT = 5
IDIOVOL_WINDOW = 60
AMIHUD_WINDOW = 20
VOL_TARGET_WINDOW = 60

# --------------------------------------------------------------------------
# Portfolio construction
# --------------------------------------------------------------------------
DECILE_CUT = 0.10  # long top 10%, short bottom 10%
TARGET_ANNUAL_VOL = 0.12
KELLY_FRACTION = 0.25  # quarter-Kelly; Maclean/Thorp/Ziemba
MAX_ADV_PARTICIPATION = 0.02  # never take more than 2% of a day's dollar volume
GROSS_LEVERAGE = 1.0
TRADING_DAYS = 252

# Cost-aware rebalance: only trade when the expected edge exceeds a friction
# threshold. AlphaOpsBench arXiv:2609.31390 showed costs alter subsequent price
# paths rather than acting as a pure ex-post deduction.
MIN_EDGE_TO_TRADE_BPS = 2.0

# --------------------------------------------------------------------------
# Execution cost model (Alperovic & Petajisto 2005 style decomposition)
# --------------------------------------------------------------------------
# All terms expressed as fractions of traded notional.
COMMISSION = 0.0005  # 0.5 bp per side
EFFECTIVE_SPREAD = 0.0008  # 0.8 bp quoted effective spread; you pay half
FEE_PER_BPS = 0.0  # venue fees folded into COMMISSION

# Square-root market impact: dP = ALPHA * sigma_daily * sqrt(Q / ADV)
IMPACT_ALPHA = 0.30
TEMPORARY_IMPACT_SHARE = 0.5
PERMANENT_IMPACT_SHARE = 0.20

# --------------------------------------------------------------------------
# Validation
# --------------------------------------------------------------------------
# Harvey, Liu & Zhu (RFS 2016): "A factor needs a clear, much higher hurdle,
# with t-statistic greater than 3.0." We use 3.0, not the conventional 2.0.
MIN_T_STAT = 3.0

# Selection-noise floor. Best in-sample Sharpe from a zero-edge process after N
# configurations ~= sqrt(2 ln N). N=100 -> ~3.0. Any IS Sharpe below this is
# inside its own search's noise.
SELECTION_NOISE_FLOOR_N = 100

# Walk-forward defaults.
TRAIN_YEARS = 5
TEST_MONTHS = 6
EMBARGO_DAYS = 10  # purge gap; must exceed the label horizon in practice

# Cost sensitivity grid (one-way, in basis points of notional). Includes the
# 100 bp stress level used by Kargarzadeh et al. arXiv:2608.12283.
COST_SENSITIVITY_BPS = (2.0, 5.0, 10.0, 25.0, 50.0, 100.0)


# --------------------------------------------------------------------------
# Synthetic market drift
# --------------------------------------------------------------------------
# MUST stay 0.0. This is not cosmetic -- it was 0.0002 and it silently put a
# perfectly rankable edge into BOTH arms.
#
# The generator gives each name a heterogeneous, time-invariant beta, so any
# non-zero drift produces a distinct expected return per name,
# E[r_20d] = FORWARD_RETURN_DAYS * MARKET_DRIFT * beta_i. Nothing in the factor
# set or the model can avoid finding that; it is not the signal under test.
# Measured on this generator, ranking names by beta alone scored IC +0.0175
# (t = +5.86) against realised forward returns with the old drift, versus
# -0.0032 (t = -1.21) at zero drift. The null arm reported RankIC 0.02-0.06
# with 4/4 seeds positive purely because of this.
#
# Beta still loads on the zero-drift market shock, so return correlation and
# volatility stay realistic; there is simply no per-name expected return left
# to rank. Set this non-zero only to demonstrate that the null control detects
# a planted cross-sectional drift -- see tests/test_null_control.py.
MARKET_DRIFT = 0.0


@dataclass(frozen=True)
class RunConfig:
    """A single evaluation run. Serialised alongside results for auditability."""

    seed: int
    n_names: int = 800
    n_days: int = 2510  # ~10 years
    edge: str = "planted"  # "planted" | "null"
    costs_bps: float = 10.0
    rebalance_days: int = 5
    n_decile: float = DECILE_CUT
    seed_variants: int = 3
    feature_families: tuple[str, ...] = field(
        default_factory=lambda: ("price_volume", "regime")
    )
