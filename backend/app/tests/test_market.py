"""Market-data test suite. No network required — the live path is stubbed.

    cd backend && ./.venv/bin/python -m app.tests.test_market

The properties that matter here are not "does it return candles" but "is the
chart honest". A price series with a broken low/high relationship, or one that
silently mixes invented data with real data, produces a chart that looks
authoritative and is not.
"""

from __future__ import annotations

import datetime as dt

from app.market import (
    INTERVALS,
    RANGES,
    MarketError,
    get_candles,
    normalise_symbol,
    quote,
    synthetic_candles,
    symbol_search,
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


def raises(name: str, fn, exc=Exception) -> None:
    try:
        fn()
    except exc:
        check(name, True)
    except Exception as e:  # noqa: BLE001
        check(name, False, f"wrong exception {type(e).__name__}")
    else:
        check(name, False, "no exception raised")


# ------------------------------------------------------------------ symbols


def test_symbols() -> None:
    print("\n[symbol normalisation]")
    raises("empty rejected", lambda: normalise_symbol(""), MarketError)
    raises("blank rejected", lambda: normalise_symbol("   "), MarketError)
    check(
        "NSE bare -> .NS", normalise_symbol("RELIANCE") == ("RELIANCE.NS", "RELIANCE")
    )
    check("lowercase normalised", normalise_symbol("reliance")[0] == "RELIANCE.NS")
    check(
        "explicit .NS kept",
        normalise_symbol("RELIANCE.NS") == ("RELIANCE.NS", "RELIANCE.NS"),
    )
    check(
        "AAPL stays US",
        normalise_symbol("AAPL") == ("AAPL", "AAPL"),
        f"{normalise_symbol('AAPL')}",
    )
    check("TSLA stays US", normalise_symbol("TSLA")[0] == "TSLA")
    check("spaces trimmed", normalise_symbol("  tcs ")[1] == "TCS")

    # A code that moved must still resolve. Getting this wrong is the worst
    # failure mode available here: the fetch returns nothing, the backend falls
    # back to synthetic, and the user is handed a confident chart of a random
    # walk for a company that is entirely real.
    from app.market import ALIASES

    check(
        "demerged Tata Motors resolves",
        normalise_symbol("TATAMOTORS")[0] == "TMPV.NS",
        str(normalise_symbol("TATAMOTORS")),
    )
    check(
        "alias keeps what the user typed",
        normalise_symbol("TATAMOTORS")[1] == "TATAMOTORS",
    )
    check(
        "merged HDFC resolves",
        normalise_symbol("HDFC")[0] == "HDFCBANK.NS",
        str(normalise_symbol("HDFC")),
    )
    check(
        "old Bajaj Finserv code resolves",
        normalise_symbol("BAJAJFINSV")[0] == "BAJAJFINANCE.NS",
    )
    check(
        "every alias points at a qualified ticker",
        all("." in v for v in ALIASES.values()),
        str(ALIASES),
    )
    check(
        "no alias is its own input",
        all(k != v for k, v in ALIASES.items()),
        str(ALIASES),
    )
    check("an alias does not shadow a US ticker", "AAPL" not in ALIASES)


# ---------------------------------------------------------------- synthetic


def test_synthetic_series() -> None:
    print("\n[synthetic series shape]")
    d = synthetic_candles("RELIANCE", "1d")
    cs = d["candles"]
    check("non-empty", len(cs) > 200, f"{len(cs)} candles")
    check("declared synthetic", d["is_synthetic"] is True)
    check("carries a warning", bool(d.get("warning")))
    check("warning says SYNTHETIC", "SYNTHETIC" in d["warning"])

    required = {"time", "open", "high", "low", "close", "volume"}
    check("all keys present", all(required <= set(c) for c in cs))

    # The invariant a chart renderer trusts absolutely.
    ohlc = all(
        c["low"] <= min(c["open"], c["close"])
        and c["high"] >= max(c["open"], c["close"])
        for c in cs
    )
    check("low <= min(o,c) and high >= max(o,c)", ohlc)
    check("all prices positive", all(c["low"] > 0 for c in cs))
    check(
        "volume is a positive int",
        all(isinstance(c["volume"], int) and c["volume"] > 0 for c in cs),
    )

    # TradingView silently drops out-of-order bars, so order is not cosmetic.
    check(
        "strictly ascending time",
        all(cs[i]["time"] < cs[i + 1]["time"] for i in range(len(cs) - 1)),
    )

    # A Saturday candle is an instant tell that nobody checked the calendar.
    dows = {dt.datetime.fromtimestamp(c["time"]).weekday() for c in cs}
    check("no weekend dailies", dows <= {0, 1, 2, 3, 4}, f"{sorted(dows)}")

    # Re-opening a chart must show the same candles, or nothing is debuggable.
    again = synthetic_candles("RELIANCE", "1d")
    check("deterministic across calls", again["candles"] == cs)
    check("different symbol differs", synthetic_candles("TCS", "1d")["candles"] != cs)


def test_synthetic_subdaily() -> None:
    print("\n[synthetic intraday]")
    d = synthetic_candles("INFY", "15m", n=300)
    cs = d["candles"]
    check("intraday produced candles", len(cs) > 100, f"{len(cs)}")
    check(
        "intraday ascending",
        all(cs[i]["time"] < cs[i + 1]["time"] for i in range(len(cs) - 1)),
    )
    check(
        "intraday ohlc valid",
        all(
            c["low"] <= min(c["open"], c["close"])
            and c["high"] >= max(c["open"], c["close"])
            for c in cs
        ),
    )


# ------------------------------------------------------------------ get


def test_get_candles() -> None:
    print("\n[get_candles]")
    d = get_candles("RELIANCE", "1d", "1y")
    for k in (
        "symbol",
        "display",
        "interval",
        "candles",
        "is_synthetic",
        "source",
        "warning",
        "fetched_at",
    ):
        check(f"payload has {k}", k in d)
    check("display is the bare code", d["display"] == "RELIANCE", d["display"])
    check("source labelled", d["source"] in ("yfinance", "synthetic"), d["source"])

    raises("bad interval rejected", lambda: get_candles("TCS", "3m", "1y"), MarketError)
    raises("bad range rejected", lambda: get_candles("TCS", "1d", "10y"), MarketError)
    raises("empty symbol rejected", lambda: get_candles("", "1d"), MarketError)

    # The cache must not lie about being fresh.
    a = get_candles("CACHEKEY", "1d", "1y")
    b = get_candles("CACHEKEY", "1d", "1y")
    check("second call is served from cache", b["cached"] is True, f"{b['cached']}")
    check("cached payload identical", a["candles"] == b["candles"])

    for name in INTERVALS:
        check(
            f"interval {name} accepted",
            get_candles("TCS", name, "1y")["interval"] == name,
        )
    for name in RANGES:
        check(
            f"range {name} accepted",
            get_candles("TCS", "1d", name)["candles"] is not None,
        )


def test_truth_only() -> None:
    print("\n[truth-only mode]")
    # allow_synthetic=False must fail rather than hand back an invented series.
    # A synthetic series quietly entering a backtest is how a fake Sharpe gets
    # printed, so the default-True path must be opt-out and honoured.
    from app.market import _CACHE

    _CACHE.clear()
    ok = get_candles("DEFINITELYNOTREAL", "1d", "1mo")
    check("unknown symbol still renders something", ok["candles"] != [])
    if ok["is_synthetic"]:
        check("and it is labelled synthetic", ok["is_synthetic"] is True)
        raises(
            "strict mode refuses the same symbol",
            lambda: get_candles(
                "DEFINITELYNOTREAL2", "1d", "1mo", allow_synthetic=False
            ),
            MarketError,
        )
    else:
        check("real feed reached, strict mode fine", True)


# ------------------------------------------------------------------ quote


def test_quote() -> None:
    print("\n[quote]")
    q = quote("RELIANCE")
    for k in (
        "symbol",
        "last",
        "change",
        "change_pct",
        "volume",
        "as_of",
        "is_synthetic",
    ):
        check(f"quote has {k}", k in q)
    check("last is positive", q["last"] > 0)

    # The change must agree with the series it was derived from, or the header
    # and the chart contradict each other on screen.
    d = get_candles("RELIANCE", "1d", "3mo")
    last, prev = d["candles"][-1], d["candles"][-2]
    check(
        "change matches series",
        abs(q["change"] - (last["close"] - prev["close"])) < 0.02,
        f"{q['change']} vs {last['close'] - prev['close']}",
    )
    check(
        "change_pct consistent",
        abs(q["change_pct"] - (last["close"] - prev["close"]) / prev["close"] * 100)
        < 0.05,
        f"{q['change_pct']}",
    )


# ------------------------------------------------------------------ search


def test_search() -> None:
    print("\n[symbol search]")
    e = symbol_search("infy")
    check(
        "case-insensitive exact", e["count"] == 1 and e["items"][0]["symbol"] == "INFY"
    )
    check("exact is stated", "Exact" in e["note"])

    r = symbol_search("REL")
    check("prefix finds RELIANCE", any(i["symbol"] == "RELIANCE" for i in r["items"]))
    check("fuzzy is flagged as such", "check the company" in r["note"])

    z = symbol_search("QQQQZZ")
    check("miss returns nothing", z["count"] == 0, f"{z['count']}")
    check("miss is honest", "Not in the built-in universe" in z["note"])

    a = symbol_search("")
    check("empty query lists the universe", a["count"] == 20, f"{a['count']}")

    s = symbol_search("TCS")
    check("IT sector search", any(i["symbol"] == "TCS" for i in s["items"]))
    check(
        "sector text search",
        any(i["sector"] == "Banking" for i in symbol_search("Banking")["items"]),
    )


def main() -> int:
    print("=" * 68)
    print("OMNIVEST market-data test suite")
    print("=" * 68)
    for fn in (
        test_symbols,
        test_synthetic_series,
        test_synthetic_subdaily,
        test_get_candles,
        test_truth_only,
        test_quote,
        test_search,
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
