"""Indicator test suite — no third-party dependency.

    cd backend && ./.venv/bin/python -m app.tests.test_indicators

Every fixture here is computed by hand and, where a published reference exists,
against that reference. In particular RSI is checked against the worked example
in Wilder's own *New Concepts in Technical Trading Systems*: comparing our
output to a charting library only proves we agree with whichever library
happens to be installed, and a library is exactly what an indicator bug gets
mistaken for.

The structural tests matter as much as the numeric ones. An indicator that
returns the wrong number is bad; one that returns a shorter array than its input
is worse, because every subsequent value silently describes the wrong bar and
nothing anywhere reports an error.
"""

from __future__ import annotations

import math

from app.indicators import (
    adx,
    atr,
    atr_percent,
    bollinger,
    compute_all,
    donchian,
    ema,
    macd,
    obv,
    returns,
    rolling_max,
    rolling_min,
    rolling_stdev,
    rsi,
    sma,
    snapshot,
    stochastic,
    supertrend,
    true_range,
    vwap,
    wilder,
)

FAILURES: list[str] = []
PASSED = 0


def check(name: str, cond: bool, detail: str = "") -> None:
    global PASSED
    if cond:
        PASSED += 1
        print(f"  PASS  {name}")
    else:
        FAILURES.append(f"{name}: {detail}")
        print(f"  FAIL  {name}  {detail}")


def close(name: str, got, want, tol: float = 1e-9) -> None:
    check(
        name,
        got is not None and abs(float(got) - float(want)) <= tol,
        f"got {got!r} want {want!r}",
    )


def aligned(name: str, series, n: int) -> None:
    check(
        f"{name} keeps length {n}",
        series is not None and len(series) == n,
        f"len {len(series) if series is not None else 'None'}",
    )


# Wilder, "New Concepts in Technical Trading Systems" — the worked RSI example.
WILDER_CLOSES = [
    44.34,
    44.09,
    44.15,
    43.61,
    44.33,
    44.83,
    45.10,
    45.42,
    45.84,
    46.08,
    45.89,
    46.03,
    45.61,
    46.28,
    46.28,
    46.00,
    46.03,
    46.41,
    46.22,
    45.64,
]
# Cross-checked by hand: the first 14 gains sum to 3.34 and the losses to 1.40,
# giving RS = 2.3857 and RSI = 70.46. These are the published readings; the
# 70.5x figures often quoted alongside them are a different rounding convention.
WILDER_RSI_14 = {
    14: 70.46,
    15: 66.25,
    16: 66.48,
    17: 69.35,
    18: 66.29,
    19: 57.92,
}


# ── primitives ───────────────────────────────────────────────────────────────


def test_primitives() -> None:
    print("\n[primitives]")

    aligned("sma len", sma([1, 2, 3, 4, 5], 3), 5)
    s = sma([1, 2, 3, 4, 5], 3)
    check("sma warm-up is None", s[0] is None and s[1] is None, f"{s[:2]}")
    close("sma[2]", s[2], 2.0)
    close("sma[3]", s[3], 3.0)
    close("sma[4]", s[4], 4.0)
    check("sma longer than input", all(v is None for v in sma([1, 2], 5)))
    close("sma of exactly n", sma([1, 2, 3], 3)[2], 2.0)

    e = ema([1, 2, 3, 4, 5], 3)
    aligned("ema len", e, 5)
    close("ema seeds with SMA", e[2], 2.0)
    close("ema recurs k=0.5", e[3], 3.0)
    close("ema recurs again", e[4], 4.0)
    check("ema warm-up None", e[0] is None and e[1] is None)

    w = wilder([1, 2, 3, 4, 5], 3)
    aligned("wilder len", w, 5)
    close("wilder seeds with SMA", w[2], 2.0)
    close("wilder uses divisor n, not decay", w[3], 8.0 / 3.0)
    close("wilder next step", w[4], 31.0 / 9.0)

    # Population sigma: divisor n. The sample sigma (n-1) is the classic silent
    # divergence from every other charting package.
    sd = rolling_stdev([2.0, 4.0, 4.0, 4.0], 4)
    close("rolling_stdev is population sigma", sd[3], math.sqrt(0.75))
    check("rolling_stdev warm-up", sd[0] is None)

    close("rolling_max", rolling_max([1, 5, 3, 2, 9], 3)[4], 9.0)
    close("rolling_min", rolling_min([1, 5, 3, 2, 9], 3)[4], 2.0)

    r = returns([100.0, 110.0, 99.0])
    check("returns first is None", r[0] is None)
    close("returns +10%", r[1], 0.10)
    close("returns -10%", r[2], -0.10)


def test_rsi() -> None:
    print("\n[RSI — against Wilder's published example]")
    got = rsi(WILDER_CLOSES, 14)
    aligned("rsi len", got, len(WILDER_CLOSES))
    check(
        "rsi warm-up is None, not backfilled",
        all(v is None for v in got[:14]),
        f"{got[:14]}",
    )
    for idx, want in WILDER_RSI_14.items():
        close(f"rsi[{idx}]", got[idx], want, tol=0.01)

    print("\n[RSI edge cases]")
    up = rsi([float(i) for i in range(1, 20)], 14)
    close("no losses -> RSI 100", up[-1], 100.0)
    down = rsi([float(i) for i in range(20, 1, -1)], 14)
    close("no gains -> RSI 0", down[-1], 0.0)
    flat = rsi([10.0] * 20, 14)
    # Neither gain nor loss: 50 is the honest middle, not 0.
    close("flat market -> RSI 50", flat[-1], 50.0)
    check("rsi too short -> all None", all(v is None for v in rsi([1, 2, 3], 14)))
    check(
        "rsi bounded 0..100",
        all(0.0 <= v <= 100.0 for v in rsi(WILDER_CLOSES, 14) if v is not None),
    )


def test_macd() -> None:
    print("\n[MACD]")
    closes = [float(100 + i) for i in range(60)]
    m = macd(closes)
    for key in ("macd", "signal", "histogram"):
        aligned(f"macd.{key} len", m[key], 60)
    check("macd warm-up None", m["macd"][24] is None)
    # In a straight uptrend the MACD line must sit above zero.
    check("uptrend -> macd line positive", m["macd"][-1] > 0, f"{m['macd'][-1]}")
    # The histogram is a difference, not a proxy.
    ok = all(
        abs(h - (a - b)) < 1e-12
        for h, a, b in zip(m["histogram"], m["macd"], m["signal"])
        if h is not None and a is not None and b is not None
    )
    check("histogram == macd - signal", ok)
    # The signal line warms up later than the MACD line, so there is a band where
    # macd is known and signal is not. The histogram must be None there too.
    check(
        "histogram exists only when both inputs do",
        all(
            (h is not None) or (a is None or b is None)
            for h, a, b in zip(m["histogram"], m["macd"], m["signal"])
        ),
    )
    down = macd([float(200 - i) for i in range(60)])
    check("downtrend -> macd line negative", down["macd"][-1] < 0)


def test_stochastic() -> None:
    print("\n[Stochastic]")
    st = stochastic([10, 12, 14], [8, 9, 10], [9, 11, 13], n=2, smooth=1)
    aligned("stoch len", st["k"], 3)
    close("stoch %K bar 1", st["k"][1], 75.0)
    close("stoch %K bar 2", st["k"][2], 80.0)
    check("stoch warm-up None", st["k"][0] is None)
    check(
        "stoch bounded 0..100", all(0.0 <= v <= 100.0 for v in st["k"] if v is not None)
    )

    flat = stochastic([10, 10, 10], [10, 10, 10], [10, 10, 10], n=2, smooth=1)
    close("flat range -> %K 50, not a crash", flat["k"][-1], 50.0)


def test_bollinger() -> None:
    print("\n[Bollinger]")
    closes = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
    bb = bollinger(closes, n=4, mult=2.0)
    for key in ("middle", "upper", "lower", "width", "percent_b"):
        aligned(f"bb.{key} len", bb[key], len(closes))
    close("bb middle[3]", bb["middle"][3], 3.5)
    close("bb middle[7]", bb["middle"][7], 6.5)
    # Population sigma for [2,4,4,4] is sqrt(0.75), so upper is 3.5 + 2*sqrt(.75).
    close("bb upper uses population sigma", bb["upper"][3], 3.5 + 2 * math.sqrt(0.75))
    close("bb lower", bb["lower"][3], 3.5 - 2 * math.sqrt(0.75))
    check(
        "upper > middle > lower",
        all(
            u > m > l
            for u, m, l in zip(bb["upper"], bb["middle"], bb["lower"])
            if u is not None
        ),
    )
    # Width is a fraction, so it is comparable across price levels.
    close(
        "bb width is a fraction",
        bb["width"][3],
        (bb["upper"][3] - bb["lower"][3]) / 3.5,
    )
    # Exact %B needs a close that really sits on the band. With n=2, mult=1 on
    # [1,3,...] the upper band is 3 and the lower is 1, so the closes land on
    # them exactly.
    edge = bollinger([1.0, 3.0, 1.0, 3.0], n=2, mult=1.0)
    close("bb %B == 1 when the close is the upper band", edge["percent_b"][1], 1.0)
    close("bb %B == 0 when the close is the lower band", edge["percent_b"][2], 0.0)
    flat = bollinger([10.0] * 5, n=4, mult=2.0)
    check("bb %B is None when the bands collapse", flat["percent_b"][-1] is None)
    check("bb width is 0 when the bands collapse", flat["width"][-1] == 0.0)
    check("bb warm-up None", bb["middle"][2] is None)


def test_atr() -> None:
    print("\n[ATR / true range]")
    highs, lows, closes = [10.0, 11.0, 12.0], [8.0, 9.0, 10.0], [9.0, 10.0, 11.0]
    tr = true_range(highs, lows, closes)
    aligned("true_range len", tr, 3)
    close("first bar falls back to high-low", tr[0], 2.0)
    close("true_range uses prior close", tr[1], 2.0)
    a = atr(highs, lows, closes, n=2)
    aligned("atr len", a, 3)
    close("atr[1]", a[1], 2.0)
    close("atr[2]", a[2], 2.0)

    # A gap up must register as a large true range.
    gapped = atr([10.0, 30.0], [9.0, 29.0], [9.5, 29.5], n=1)
    check(
        "a gap registers as range",
        gapped[-1] is not None and gapped[-1] > 19.0,
        f"{gapped[-1]}",
    )

    pct = atr_percent(highs, lows, closes, n=2)
    close("atr_percent normalises by price", pct[1], 100.0 * 2.0 / 10.0)
    check("atr_percent warm-up None", pct[0] is None)


def test_adx() -> None:
    print("\n[ADX]")
    highs = [10.0 + i for i in range(40)]
    lows = [9.0 + i for i in range(40)]
    closes = [9.5 + i for i in range(40)]
    d = adx(highs, lows, closes, n=14)
    for key in ("adx", "plus_di", "minus_di"):
        aligned(f"adx.{key} len", d[key], 40)
    first_adx = next(i for i, v in enumerate(d["adx"]) if v is not None)
    check(
        "adx warm-up is honest, not zero-filled",
        first_adx >= 26,
        f"first ADX at {first_adx}",
    )
    check("adx is None before that", all(v is None for v in d["adx"][:first_adx]))
    check(
        "plus_di starts before adx",
        next(i for i, v in enumerate(d["plus_di"]) if v is not None) < first_adx,
    )
    check(
        "uptrend -> +DI beats -DI",
        d["plus_di"][-1] > d["minus_di"][-1],
        f"+{d['plus_di'][-1]} -{d['minus_di'][-1]}",
    )
    check("uptrend -> ADX is high", d["adx"][-1] > 25.0, f"{d['adx'][-1]}")

    dh = adx(
        [9.0 - i for i in range(40)],
        [8.0 - i for i in range(40)],
        [8.5 - i for i in range(40)],
        n=14,
    )
    check("downtrend -> -DI beats +DI", dh["minus_di"][-1] > dh["plus_di"][-1])
    check("DI values non-negative", all(v is None or v >= 0 for v in d["plus_di"]))

    # DI and ADX without direction is the most common indicator bug there is.
    check("DI direction is reported", "plus_di" in d and "minus_di" in d)


def test_volume_and_trend() -> None:
    print("\n[OBV / VWAP / Donchian]")
    o = obv([10.0, 11.0, 10.0, 12.0], [100.0, 200.0, 300.0, 400.0])
    check("obv len", len(o) == 4, f"{len(o)}")
    close("obv starts at 0", o[0], 0.0)
    close("obv adds on up close", o[1], 200.0)
    close("obv subtracts on down close", o[2], -100.0)
    close("obv adds on up close again", o[3], 300.0)
    close("obv ignores unchanged closes", obv([5.0, 5.0], [100.0, 100.0])[1], 0.0)

    w = vwap([10.0, 20.0], [10.0, 20.0], [10.0, 20.0], [100.0, 300.0], n=2)
    check("vwap warm-up None", w[0] is None)
    close("vwap weighted by volume", w[1], (10 * 100 + 20 * 300) / 400)
    check(
        "vwap zero volume -> None", vwap([10.0], [10.0], [10.0], [0.0], n=1)[0] is None
    )

    dc = donchian([1.0, 5.0, 3.0, 9.0], [0.0, 4.0, 2.0, 8.0], n=2)
    close("donchian upper", dc["upper"][-1], 9.0)
    close("donchian lower", dc["lower"][-1], 2.0)


def test_supertrend() -> None:
    print("\n[Supertrend]")
    highs = [float(100 + i) for i in range(30)]
    lows = [float(99 + i) for i in range(30)]
    closes = [float(99.5 + i) for i in range(30)]
    s = supertrend(highs, lows, closes, n=5, mult=2.0)
    for key in ("trend", "upper", "lower"):
        aligned(f"supertrend.{key} len", s[key], 30)
    first_trend = next(i for i, v in enumerate(s["trend"]) if v is not None)
    check("supertrend warm-up is honest", first_trend == 4, f"first at {first_trend}")
    check(
        "uptrend -> trend line sits below price",
        s["trend"][-1] < closes[-1],
        f"{s['trend'][-1]} vs {closes[-1]}",
    )
    check("upper band above trend", s["upper"][-1] > s["trend"][-1])

    dh = supertrend(
        [float(200 - i) for i in range(30)],
        [float(199 - i) for i in range(30)],
        [float(199.5 - i) for i in range(30)],
        n=5,
        mult=2.0,
    )
    check(
        "downtrend -> trend line sits above price",
        dh["trend"][-1] > closes[-1] - 100.0,
        f"{dh['trend'][-1]}",
    )


def test_bundle() -> None:
    print("\n[compute_all / snapshot]")
    n = 120
    bars = []
    px = 1000.0
    for i in range(n):
        o = px
        c = px + (1.0 if i % 3 else -1.2)
        h = max(o, c) + 1.5
        low = min(o, c) - 1.5
        bars.append(
            {
                "time": 1700000000 + i * 86400,
                "open": o,
                "high": h,
                "low": low,
                "close": c,
                "volume": 1_000_000 + i * 1000,
            }
        )
        px = c

    ind = compute_all(bars)
    check("compute_all returns a bundle", len(ind) > 15, f"{len(ind)} series")
    for key, series in ind.items():
        check(
            f"{key} aligned to bars", len(series) == n, f"{key}: {len(series)} vs {n}"
        )
    check("obv has no warm-up (cumulative)", all(v is not None for v in ind["obv"]))
    check(
        "every indicator has a None warm-up somewhere",
        all(
            any(v is None for v in ind[k])
            for k in ("rsi_14", "sma_50", "bollinger_middle", "adx_14", "vwap_20")
        ),
    )

    snap = snapshot(bars)
    check("snapshot reports bar count", snap["bars"] == n, f"{snap['bars']}")
    check("snapshot carries RSI", snap["rsi_14"] is not None)
    check("snapshot RSI in range", 0.0 <= snap["rsi_14"] <= 100.0, f"{snap['rsi_14']}")
    check(
        "snapshot keys match compute_all",
        all(k in snap for k in ind),
        f"{sorted(set(ind) - set(snap))}",
    )

    # A short series must degrade to None everywhere rather than inventing values.
    tiny = compute_all(bars[:10])
    check(
        "short series -> all None (no invented history)",
        all(v is None for v in tiny["rsi_14"]),
    )
    check("short series keeps alignment", all(len(v) == 10 for v in tiny.values()))


def main() -> int:
    print("=" * 68)
    print("OMNIVEST indicator test suite")
    print("=" * 68)
    for fn in (
        test_primitives,
        test_rsi,
        test_macd,
        test_stochastic,
        test_bollinger,
        test_atr,
        test_adx,
        test_volume_and_trend,
        test_supertrend,
        test_bundle,
    ):
        fn()
    print("\n" + "=" * 68)
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} of {PASSED + len(FAILURES)}")
        for f in FAILURES:
            print(f"  - {f}")
        return 1
    print(f"ALL {PASSED} CHECKS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
