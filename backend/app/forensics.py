"""Deterministic forensics: DSR-lite, PBO-lite, MinBTL, verdict.
Simplified, explainable versions of Bailey et al. — full CSCV lives in Phase 2.
"""

from __future__ import annotations
import math


def deflated_sharpe(
    sharpe: float, trials: int, skew: float = -0.5, kurt: float = 3.5, n: int = 1000
) -> dict:
    """DSR-lite: expected max Sharpe under null ≈ sqrt(2 ln N) adjusted; DSR ≈ achieved − expected."""
    trials = max(trials, 1)
    expected_max = (
        math.sqrt(2.0 * math.log(trials)) * 0.55
    )  # empirical shrinkage for daily equity
    dsr = sharpe - expected_max * 0.6
    return {
        "expected_max_luck": round(expected_max, 2),
        "dsr_lite": round(dsr, 2),
        "significant": dsr > 0,
        "trials": trials,
    }


def pbo_lite(trials: int, sharpe: float) -> float:
    """Heuristic PBO: more trials + lower sharpe ⇒ higher overfit probability."""
    base = 1.0 - 1.0 / (1.0 + math.exp(-(trials / 12.0 - sharpe)))
    return round(min(0.97, max(0.03, base)), 2)


def min_btl(trials: int, target_sharpe: float = 0.5) -> float:
    """Years needed so best-of-N isn't just noise. Scales with log(trials)."""
    return round(2.0 + 2.5 * math.log(max(trials, 1) + 1), 1)


def autopsy(
    name: str,
    sharpe: float,
    trials: int,
    backtest_excess_bps: int,
    live_excess_bps: int,
) -> dict:
    dsr = deflated_sharpe(sharpe, trials)
    pbo = pbo_lite(trials, sharpe)
    need = min_btl(trials)
    decay = backtest_excess_bps - live_excess_bps
    if not dsr["significant"] or pbo > 0.6:
        verdict = "⚠️ Likely overfit or crowded — do not trust. Expected forward excess near zero."
    elif decay > 200:
        verdict = "⚠️ Real effect, wrong regime or crowded now. Haircut expected excess by half."
    else:
        verdict = (
            "✅ Survives forensics — still demand FDR calibration + crowding check."
        )
    return {
        "technique": name,
        "sharpe": sharpe,
        "trials": trials,
        "backtest_excess_bps": backtest_excess_bps,
        "live_excess_bps": live_excess_bps,
        "decay_bps": decay,
        **dsr,
        "pbo_lite": pbo,
        "min_btl_years": need,
        "verdict": verdict,
    }
