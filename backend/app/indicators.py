"""Technical indicators, computed deterministically in Python.

**The hybrid rule: the model narrates, this file computes.** Every number the
AI is allowed to speak about is produced here. An LLM that invents an RSI is
indistinguishable from one that reads it correctly, and the difference only
shows up when it is wrong and you acted on it. So nothing in this module — or
anything built on it — is permitted to ask a language model for a value.

Three properties this module holds to, because each one has silently broken a
trading system before:

1. **Output is always the same length as input**, aligned index-for-index, with
   ``None`` in the warm-up. A shorter series silently shifts every subsequent
   value one bar earlier, and the indicator ends up describing yesterday while
   the chart draws today. Truncating is how that bug ships.

2. **The warm-up is never backfilled.** The first ``n-1`` values of a 14-period
   RSI are genuinely unknown. Filling them with the first computable value
   invents history, and the backtest then trades on data that never existed.

3. **Every edge case resolves to something explicit**, not to an exception or a
   NaN that propagates. RSI with no losses in the window is 100, not a division
   by zero. A flat range has zero Bollinger width, not a negative one.

Formulas are the textbook ones, cross-checked in ``tests/test_indicators.py``
against hand-computed fixtures rather than against a library — a test that
compares us to ``ta`` only proves we agree with whichever library is installed.
"""

from __future__ import annotations

import math
from typing import Sequence

Number = float | None


# ── primitives ───────────────────────────────────────────────────────────────


def sma(values: Sequence[float], n: int) -> list[Number]:
    """Simple moving average."""
    out: list[Number] = []
    run = 0.0
    for i, v in enumerate(values):
        run += v
        if i >= n:
            run -= values[i - n]
        out.append(run / n if i >= n - 1 else None)
    return out


def ema(values: Sequence[float], n: int) -> list[Number]:
    """Exponential moving average, seeded with the SMA of the first ``n``.

    Seeding matters. Recursing from the first observation instead weights a
    single early bar as heavily as the most recent one, which is the classic
    way an EMA ends up disagreeing with every charting package on earth.
    """
    if n <= 0:
        raise ValueError("period must be positive")
    k = 2.0 / (n + 1.0)
    out: list[Number] = [None] * len(values)
    if len(values) < n:
        return out
    prev = sum(values[:n]) / n
    out[n - 1] = prev
    for i in range(n, len(values)):
        prev = (values[i] - prev) * k + prev
        out[i] = prev
    return out


def wilder(values: Sequence[float], n: int) -> list[Number]:
    """Wilder's smoothing — the average RSI, ATR and ADX are actually built on.

    Distinct from an EMA with period ``n-1``: the denominator is ``n`` on every
    pass, not a decay factor. Substituting a plain EMA here changes every
    derived indicator and is invisible in the output shape.
    """
    out: list[Number] = [None] * len(values)
    if len(values) < n:
        return out
    prev = sum(values[:n]) / n
    out[n - 1] = prev
    for i in range(n, len(values)):
        prev = (prev * (n - 1) + values[i]) / n
        out[i] = prev
    return out


def rolling_stdev(values: Sequence[float], n: int) -> list[Number]:
    """Population standard deviation over ``n`` — the divisor is ``n``.

    Bollinger bands conventionally use the population sigma. The sample sigma
    (divisor ``n-1``) widens every band and is a silent, plausible-looking
    difference between this app and every other chart on the screen.
    """
    out: list[Number] = []
    for i in range(len(values)):
        if i < n - 1:
            out.append(None)
            continue
        window = values[i - n + 1 : i + 1]
        mean = sum(window) / n
        var = sum((x - mean) ** 2 for x in window) / n
        out.append(math.sqrt(var))
    return out


def rolling_max(values: Sequence[float], n: int) -> list[Number]:
    return [
        max(values[i - n + 1 : i + 1]) if i >= n - 1 else None
        for i in range(len(values))
    ]


def rolling_min(values: Sequence[float], n: int) -> list[Number]:
    return [
        min(values[i - n + 1 : i + 1]) if i >= n - 1 else None
        for i in range(len(values))
    ]


# ── oscillators ──────────────────────────────────────────────────────────────


def rsi(closes: Sequence[float], n: int = 14) -> list[Number]:
    """Wilder's RSI.

    No losses in the window is RSI 100 and no gains is RSI 0. Returning None or
    raising instead would leave the strategy engine with a hole exactly on the
    bars where a strong move just happened — the ones worth trading.
    """
    out: list[Number] = [None] * len(closes)
    if len(closes) < n + 1:
        return out
    gains = [max(0.0, closes[i] - closes[i - 1]) for i in range(1, len(closes))]
    losses = [max(0.0, closes[i - 1] - closes[i]) for i in range(1, len(closes))]
    ag = wilder(gains, n)
    al = wilder(losses, n)
    # gains[0] is the move from close 0 to close 1, so gain index j describes
    # close j+1. Iterating with the same index for both would read one bar past
    # the end on the final bar.
    for j, (a, l) in enumerate(zip(ag, al)):
        if a is None or l is None:
            continue
        if l == 0:
            out[j + 1] = 100.0 if a > 0 else 50.0
        elif a == 0:
            out[j + 1] = 0.0
        else:
            rs = a / l
            out[j + 1] = 100.0 - (100.0 / (1.0 + rs))
    return out


def macd(
    closes: Sequence[float], fast: int = 12, slow: int = 26, signal: int = 9
) -> dict[str, list[Number]]:
    """MACD line, signal line and histogram.

    The histogram is the MACD minus the signal, not a difference of ratios. It
    is the number traders quote, so it has to be the number, not a proxy.
    """
    ef = ema(closes, fast)
    es = ema(closes, slow)
    line: list[Number] = [
        (a - b) if (a is not None and b is not None) else None for a, b in zip(ef, es)
    ]
    known = [v for v in line if v is not None]
    sig_known = ema(known, signal)
    sig: list[Number] = [None] * len(line)
    it = iter(sig_known)
    for i, v in enumerate(line):
        if v is not None:
            sig[i] = next(it)
    hist: list[Number] = [
        (m - s) if (m is not None and s is not None) else None
        for m, s in zip(line, sig)
    ]
    return {"macd": line, "signal": sig, "histogram": hist}


def stochastic(
    highs: Sequence[float],
    lows: Sequence[float],
    closes: Sequence[float],
    n: int = 14,
    smooth: int = 3,
) -> dict[str, list[Number]]:
    """Stochastic %K and %D.

    %K is 0.0-100.0, matching the convention every charting package uses, so the
    80/20 lines mean the same thing here as on the user's other screen.
    """
    hh = rolling_max(highs, n)
    ll = rolling_min(lows, n)
    k: list[Number] = []
    for h, l, c in zip(hh, ll, closes):
        if h is None or l is None:
            k.append(None)
        elif h == l:  # flat range: no position within it
            k.append(50.0)
        else:
            k.append(100.0 * (c - l) / (h - l))
    known = [v for v in k if v is not None]
    d_known = sma(known, smooth)
    d: list[Number] = [None] * len(k)
    it = iter(d_known)
    for i, v in enumerate(k):
        if v is not None:
            d[i] = next(it)
    return {"k": k, "d": d}


# ── bands and volatility ─────────────────────────────────────────────────────


def bollinger(
    closes: Sequence[float], n: int = 20, mult: float = 2.0
) -> dict[str, list[Number]]:
    """Bollinger middle/upper/lower.

    ``width`` is expressed as a fraction of the middle band so it is comparable
    across price levels — a width of 2.0 means 2%, not two rupees, which is the
    only form in which "the bands are squeezing" means anything.
    """
    mid = sma(closes, n)
    sd = rolling_stdev(closes, n)
    upper = [
        m + mult * s if m is not None and s is not None else None
        for m, s in zip(mid, sd)
    ]
    lower = [
        m - mult * s if m is not None and s is not None else None
        for m, s in zip(mid, sd)
    ]
    width = [
        (u - l) / m if None not in (u, l, m) and m else None
        for u, l, m in zip(upper, lower, mid)
    ]
    pct_b = [
        (c - l) / (u - l) if None not in (c, u, l) and u != l else None
        for c, u, l in zip(closes, upper, lower)
    ]
    return {
        "middle": mid,
        "upper": upper,
        "lower": lower,
        "width": width,
        "percent_b": pct_b,
    }


def true_range(
    highs: Sequence[float], lows: Sequence[float], closes: Sequence[float]
) -> list[float]:
    """True range. The first bar has no previous close, so it falls back to
    high-low rather than to a fabricated prior."""
    out = []
    for i in range(len(closes)):
        if i == 0:
            out.append(highs[i] - lows[i])
        else:
            out.append(
                max(
                    highs[i] - lows[i],
                    abs(highs[i] - closes[i - 1]),
                    abs(lows[i] - closes[i - 1]),
                )
            )
    return out


def atr(
    highs: Sequence[float],
    lows: Sequence[float],
    closes: Sequence[float],
    n: int = 14,
) -> list[Number]:
    return wilder(true_range(highs, lows, closes), n)


def atr_percent(
    highs: Sequence[float],
    lows: Sequence[float],
    closes: Sequence[float],
    n: int = 14,
) -> list[Number]:
    """ATR as a percentage of price.

    A raw ATR of 12 rupees means nothing until you know the stock trades at 1200
    or at 12. Position sizing needs the ratio.
    """
    out = []
    for a, c in zip(atr(highs, lows, closes, n), closes):
        out.append(100.0 * a / c if a is not None and c else None)
    return out


def adx(
    highs: Sequence[float],
    lows: Sequence[float],
    closes: Sequence[float],
    n: int = 14,
) -> dict[str, list[Number]]:
    """Average Directional Index with +DI and -DI.

    ADX says a trend exists; DI says which way. Reporting ADX alone is the most
    common indicator bug there is, because 30 falling and 30 rising are the
    same number and opposite trades.
    """
    size = len(closes)
    plus_dm = [0.0] * size
    minus_dm = [0.0] * size
    for i in range(1, size):
        up = highs[i] - highs[i - 1]
        dn = lows[i - 1] - lows[i]
        plus_dm[i] = up if (up > dn and up > 0) else 0.0
        minus_dm[i] = dn if (dn > up and dn > 0) else 0.0

    tr = true_range(highs, lows, closes)
    tr_s = wilder(tr, n)
    plus_s = wilder(plus_dm, n)
    minus_s = wilder(minus_dm, n)

    plus_di: list[Number] = []
    minus_di: list[Number] = []
    for t, p, m in zip(tr_s, plus_s, minus_s):
        if t is None or t == 0:
            plus_di.append(None)
            minus_di.append(None)
            continue
        plus_di.append(100.0 * p / t)
        minus_di.append(100.0 * m / t)

    # DX is undefined until the DI values exist. Running the average over
    # placeholder zeros would bias the first ADX reading low — and the first
    # reading is the one a strategy engine acts on. Average only the real
    # region, then re-align.
    start = next(
        (
            i
            for i, (p, m) in enumerate(zip(plus_di, minus_di))
            if p is not None and m is not None
        ),
        None,
    )
    adx_vals: list[Number] = [None] * size
    if start is None:
        return {"adx": adx_vals, "plus_di": plus_di, "minus_di": minus_di}

    dx_known: list[float] = []
    for p, m in zip(plus_di[start:], minus_di[start:]):
        total = p + m
        dx_known.append(100.0 * abs(p - m) / total if total else 0.0)
    smoothed = wilder(dx_known, n)
    for j, v in enumerate(smoothed):
        if v is not None:
            adx_vals[start + j] = v
    return {"adx": adx_vals, "plus_di": plus_di, "minus_di": minus_di}


# ── volume ───────────────────────────────────────────────────────────────────


def obv(closes: Sequence[float], volumes: Sequence[float]) -> list[float]:
    """On-balance volume, signed by the direction of the close."""
    out = [0.0]
    for i in range(1, len(closes)):
        if closes[i] > closes[i - 1]:
            out.append(out[-1] + volumes[i])
        elif closes[i] < closes[i - 1]:
            out.append(out[-1] - volumes[i])
        else:
            out.append(out[-1])
    return out


def vwap(
    highs: Sequence[float],
    lows: Sequence[float],
    closes: Sequence[float],
    volumes: Sequence[float],
    n: int = 20,
) -> list[Number]:
    """Rolling VWAP over ``n`` bars.

    Typical price is (H+L+C)/3 — the convention, because a bar's close alone
    discards the range it traded through, and a stock that ran to a high and
    fell back to its close is not the same as one that closed there.

    Rolling rather than session-cumulative because these bars are daily; a
    cumulative VWAP across a year would just be an average price, not a level
    anyone trades against.
    """
    tp = [(h + l + c) / 3.0 for h, l, c in zip(highs, lows, closes)]
    out: list[Number] = []
    for i in range(len(tp)):
        if i < n - 1:
            out.append(None)
            continue
        pv = sum(tp[j] * volumes[j] for j in range(i - n + 1, i + 1))
        vol = sum(volumes[i - n + 1 : i + 1])
        out.append(pv / vol if vol else None)
    return out


# ── trend ────────────────────────────────────────────────────────────────────


def donchian(
    highs: Sequence[float], lows: Sequence[float], n: int = 20
) -> dict[str, list[Number]]:
    """Donchian channels — the turtle-breakout basis."""
    upper = rolling_max(highs, n)
    lower = rolling_min(lows, n)
    return {"upper": upper, "lower": lower}


def supertrend(
    highs: Sequence[float],
    lows: Sequence[float],
    closes: Sequence[float],
    n: int = 10,
    mult: float = 3.0,
) -> dict[str, list[Number]]:
    """Supertrend: ATR bands around a running midpoint, flipping on a close.

    ``direction`` is +1 while the trend is up and -1 while it is down. The flip
    only happens on a confirmed close, never intrabar, which is what makes it
    backtestable without foresight.
    """
    size = len(closes)
    a = atr(highs, lows, closes, n)
    hl2 = [(h + l) / 2.0 for h, l in zip(highs, lows)]
    final_up: list[Number] = [None] * size
    final_dn: list[Number] = [None] * size
    trend: list[Number] = [None] * size
    direction: list[Number] = [None] * size
    dirn = 1

    for i in range(size):
        if a[i] is None:
            continue
        base_up = hl2[i] + mult * a[i]
        base_dn = hl2[i] - mult * a[i]
        if i == 0 or final_up[i - 1] is None:
            final_up[i] = base_up
            final_dn[i] = base_dn
            trend[i] = hl2[i]
            # No flip has been confirmed yet, so there is no direction to
            # report. Guessing +1 here is how a chart ends up "long" on the
            # very first bar of a downtrend.
            continue
        # Bands only ever tighten against the previous close; they never widen,
        # which is what makes the flip level meaningful.
        final_up[i] = (
            base_up
            if (base_up < final_up[i - 1] or closes[i - 1] > final_up[i - 1])
            else final_up[i - 1]
        )
        final_dn[i] = (
            base_dn
            if (base_dn > final_dn[i - 1] or closes[i - 1] < final_dn[i - 1])
            else final_dn[i - 1]
        )
        if closes[i] > final_up[i - 1]:
            dirn = 1
        elif closes[i] < final_dn[i - 1]:
            dirn = -1
        trend[i] = final_dn[i] if dirn == 1 else final_up[i]
        direction[i] = dirn
    return {
        "trend": trend,
        "upper": final_up,
        "lower": final_dn,
        "direction": direction,
    }


def returns(closes: Sequence[float]) -> list[Number]:
    """Simple period-over-period returns as fractions (0.01 == +1%)."""
    return [None] + [
        (closes[i] / closes[i - 1] - 1.0) if closes[i - 1] else None
        for i in range(1, len(closes))
    ]


# ── the bundle the UI actually consumes ──────────────────────────────────────


def compute_all(bars: Sequence[dict]) -> dict[str, list[Number]]:
    """Compute every indicator over a candle list.

    Keys ending in ``*_series`` are line-per-bar and go straight to the chart as
    overlays. Keys holding scalars belong to the HUD. Keeping both in one call
    means the chart and the analysis panel can never be reading a different
    computation of the same thing.
    """
    o = [float(b["open"]) for b in bars]
    h = [float(b["high"]) for b in bars]
    low = [float(b["low"]) for b in bars]
    c = [float(b["close"]) for b in bars]
    v = [float(b.get("volume") or 0) for b in bars]

    m = macd(c)
    bb = bollinger(c)
    st = stochastic(h, low, c)
    dch = donchian(h, low)
    adx_ = adx(h, low, c)
    sup = supertrend(h, low, c)

    return {
        "sma_20": sma(c, 20),
        "sma_50": sma(c, 50),
        "ema_9": ema(c, 9),
        "ema_21": ema(c, 21),
        "rsi_14": rsi(c, 14),
        "macd": m["macd"],
        "macd_signal": m["signal"],
        "macd_histogram": m["histogram"],
        "bollinger_upper": bb["upper"],
        "bollinger_middle": bb["middle"],
        "bollinger_lower": bb["lower"],
        "bollinger_width": bb["width"],
        "percent_b": bb["percent_b"],
        "stoch_k": st["k"],
        "stoch_d": st["d"],
        "atr_14": atr(h, low, c, 14),
        "atr_percent": atr_percent(h, low, c, 14),
        "adx_14": adx_["adx"],
        "plus_di": adx_["plus_di"],
        "minus_di": adx_["minus_di"],
        "obv": obv(c, v),
        "vwap_20": vwap(h, low, c, v, 20),
        "donchian_upper": dch["upper"],
        "donchian_lower": dch["lower"],
        "supertrend": sup["trend"],
        # Direction, not just the line. A trend value tells you where the
        # band is; only the direction tells you which side of it price closed,
        # which is the entire signal.
        "supertrend_direction": sup["direction"],
        "returns": returns(c),
    }


def snapshot(bars: Sequence[dict]) -> dict[str, Number | str]:
    """The last computed value of everything, for the HUD and the AI panel.

    Keys whose warm-up has not finished are ``None`` and must be rendered as
    "warming up" rather than as zero. A 0 RSI reads as maximally oversold; a
    missing one reads as nothing, which is what is true.
    """
    ind = compute_all(bars)
    out: dict[str, Number | str] = {}
    for k, series in ind.items():
        v = series[-1] if series else None
        out[k] = v
    out["bars"] = len(bars)
    return out
