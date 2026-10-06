"""OHLCV candles for the chart, with provenance attached.

Two rules govern this module.

1. **Never present invented data as real.** If the network is unavailable or a
   symbol is unknown, we synthesise a deterministic series so the chart still
   renders — but the response carries ``is_synthetic: true`` and the UI is
   required to say so. A chart of invented prices, shown without that label, is
   precisely the failure this product exists to prevent. A missing chart is
   merely annoying; a confident fake one teaches someone to trade on fiction.

2. **The maths happens here, never in the model.** The LLM narrates; Python
   computes. Nothing in this file asks a language model anything.

Symbol handling follows the Indian convention (RELIANCE -> RELIANCE.NS) because
that is where the users are, with US names reachable unprefixed.
"""

from __future__ import annotations

import hashlib
import math
import random
import time
from datetime import datetime, timedelta, timezone

# ---------------------------------------------------------------- intervals

INTERVALS = {
    "1m": ("1m", 1 / 390),  # trading minutes per day, Indian session
    "5m": ("5m", 1 / 78),
    "15m": ("15m", 1 / 26),
    "1h": ("1h", 1 / 6.5),
    "1d": ("1d", 1.0),
    "1wk": ("1wk", 7.0),
}

RANGES = {
    "1mo": "1mo",
    "3mo": "3mo",
    "6mo": "6mo",
    "1y": "1y",
    "2y": "2y",
    "5y": "5y",
    "max": "max",
}

_CACHE: dict[tuple, dict] = {}
_CACHE_TTL = 300  # seconds. A chart redrawn twice in a session, not a feed.

# A deliberately small, hand-checked universe. The search box exists to stop
# typos becoming trades, and that only works if the list is one we have actually
# looked at. Anything not here can still be charted by typing it.
UNIVERSE: dict[str, dict] = {
    "RELIANCE": {
        "symbol": "RELIANCE",
        "name": "Reliance Industries",
        "sector": "Energy",
    },
    "TCS": {"symbol": "TCS", "name": "Tata Consultancy Services", "sector": "IT"},
    "HDFCBANK": {"symbol": "HDFCBANK", "name": "HDFC Bank", "sector": "Banking"},
    "INFY": {"symbol": "INFY", "name": "Infosys", "sector": "IT"},
    "ICICIBANK": {"symbol": "ICICIBANK", "name": "ICICI Bank", "sector": "Banking"},
    "SBIN": {"symbol": "SBIN", "name": "State Bank of India", "sector": "Banking"},
    "BHARTIARTL": {
        "symbol": "BHARTIARTL",
        "name": "Bharti Airtel",
        "sector": "Telecom",
    },
    "ITC": {"symbol": "ITC", "name": "ITC", "sector": "FMCG"},
    "LT": {"symbol": "LT", "name": "Larsen & Toubro", "sector": "Industrials"},
    "AXISBANK": {"symbol": "AXISBANK", "name": "Axis Bank", "sector": "Banking"},
    "KOTAKBANK": {
        "symbol": "KOTAKBANK",
        "name": "Kotak Mahindra Bank",
        "sector": "Banking",
    },
    "HINDUNILVR": {
        "symbol": "HINDUNILVR",
        "name": "Hindustan Unilever",
        "sector": "FMCG",
    },
    "BAJFINANCE": {"symbol": "BAJFINANCE", "name": "Bajaj Finance", "sector": "NBFC"},
    "MARUTI": {"symbol": "MARUTI", "name": "Maruti Suzuki", "sector": "Auto"},
    "TATAMOTORS": {"symbol": "TATAMOTORS", "name": "Tata Motors", "sector": "Auto"},
    "ASIANPAINT": {
        "symbol": "ASIANPAINT",
        "name": "Asian Paints",
        "sector": "Consumer",
    },
    "SUNPHARMA": {
        "symbol": "SUNPHARMA",
        "name": "Sun Pharmaceutical",
        "sector": "Pharma",
    },
    "TITAN": {"symbol": "TITAN", "name": "Titan Company", "sector": "Consumer"},
    "ULTRACEMCO": {
        "symbol": "ULTRACEMCO",
        "name": "UltraTech Cement",
        "sector": "Materials",
    },
    "WIPRO": {"symbol": "WIPRO", "name": "Wipro", "sector": "IT"},
}


class MarketError(RuntimeError):
    """Raised when a symbol cannot be resolved to anything plottable."""


# Bare tickers that are unmistakably US listings. Without this list, `AAPL`
# resolves to `AAPL.NS` — a symbol that does not exist, returning an empty
# series and, on a permissive backend, a plausible-looking wrong chart. Guessing
# NSE is right far more often than not for this audience, so the exception is
# an explicit allow-list rather than a clever heuristic.
US_TICKERS = {
    "AAPL",
    "MSFT",
    "NVDA",
    "GOOGL",
    "GOOG",
    "AMZN",
    "META",
    "TSLA",
    "AVGO",
    "BRK-B",
    "BRK.B",
    "JPM",
    "V",
    "MA",
    "UNH",
    "JNJ",
    "PG",
    "HD",
    "COST",
    "NFLX",
    "AMD",
    "INTC",
    "CRM",
    "ORCL",
    "ADBE",
    "PEP",
    "KO",
    "DIS",
    "XOM",
    "WMT",
    "MRK",
    "PFE",
    "TMO",
    "ABBV",
    "LLY",
    "AVGO",
    "QCOM",
    "TXN",
    "IBM",
}


# Codes that moved and that people still type. Without this, `TATAMOTORS.NS`
# simply does not exist, the fetch returns nothing, and the user gets a chart of
# synthetic data for a company that is entirely real — the worst possible
# failure mode, because it looks like it worked.
ALIASES = {
    # Tata Motors demerged: the old code now names two companies. This resolves
    # to the passenger-vehicle entity, which is what most people typing
    # "TATAMOTORS" mean. The commercial-vehicle side trades as TATAMTRDVR, which
    # yfinance does not carry — so this alias is a judgement call, and the UI
    # must say which entity it landed on rather than pretending the split never
    # happened.
    "TATAMOTORS": "TMPV.NS",
    "TATAMOTOR": "TMPV.NS",
    "HDFC": "HDFCBANK.NS",  # merged into HDFC Bank
    "BAJAJFINSV": "BAJAJFINANCE.NS",
    "YESBANK": "YESBANK.NS",
}


def normalise_symbol(symbol: str) -> tuple[str, str]:
    """Return (yfinance_symbol, display).

    Indian users type bare NSE codes. `RELIANCE` is overwhelmingly meant to be
    `RELIANCE.NS`, so an unrecognised bare code gets the NSE suffix. An explicit
    suffix is respected untouched, and a known US ticker is never suffixed.
    """
    s = (symbol or "").strip().upper()
    if not s:
        raise MarketError("symbol is required")
    if "." in s:  # already qualified: RELIANCE.NS, BRK-B
        return s, s
    if s in US_TICKERS:
        return s, s
    if s in ALIASES:
        return ALIASES[s], s
    return f"{s}.NS", s


def _cache_key(symbol: str, interval: str, rng: str) -> tuple:
    return (symbol, interval, rng)


def _cache_get(key: tuple) -> dict | None:
    hit = _CACHE.get(key)
    if hit and (time.time() - hit["ts"]) < _CACHE_TTL:
        return hit["payload"]
    return None


def _cache_put(key: tuple, payload: dict) -> None:
    _CACHE[key] = {"ts": time.time(), "payload": payload}


# ---------------------------------------------------------------- synthetic


def _seed_for(symbol: str) -> int:
    """Stable across processes — Python's `hash` is salted per interpreter."""
    return int(hashlib.sha256(symbol.encode()).hexdigest()[:12], 16)


def _synthetic_timestamps(interval: str, n: int) -> list[int]:
    """`n` strictly ascending epoch seconds ending at the most recent bar.

    Built from a real trading calendar rather than a constant offset. A Saturday
    candle in an Indian chart, or intraday bars stamped at the same instant, is
    an instant tell that nobody checked — and duplicated timestamps make
    Lightweight Charts silently drop bars rather than draw them.
    """
    now = datetime.now(timezone.utc).replace(second=0, microsecond=0)
    out: list[int] = []

    if interval == "1wk":
        # Anchor to the most recent completed Monday.
        day = now - timedelta(days=now.weekday())
        while len(out) < n:
            out.append(int(day.timestamp()))
            day -= timedelta(days=7)
        return list(reversed(out))

    if interval == "1d":
        day = now
        while len(out) < n:
            if day.weekday() < 5:  # Mon-Fri; Indian markets trade no weekend
                out.append(int(day.timestamp()))
            day -= timedelta(days=1)
        return list(reversed(out))

    # Intraday: 09:15-15:30 IST, 375 minutes. Walk backwards session by session.
    step = {"1m": 1, "5m": 5, "15m": 15, "1h": 60}[interval]
    bars_per_day = 375 // step
    day = now
    while day.weekday() >= 5:  # start from a weekday
        day -= timedelta(days=1)
    # Partial current session first, then full prior sessions.
    elapsed = max(0, (now - day.replace(hour=9, minute=15)).total_seconds() // 60)
    first_session = int(elapsed // step)
    while len(out) < n:
        count = (
            first_session
            if (len(out) == 0 and first_session < bars_per_day)
            else bars_per_day
        )
        for b in range(count, 0, -1):
            out.append(
                int(
                    (
                        day.replace(hour=9, minute=15) + timedelta(minutes=b * step)
                    ).timestamp()
                )
            )
            if len(out) >= n:
                break
        first_session = bars_per_day
        day -= timedelta(days=1)
        while day.weekday() >= 5:
            day -= timedelta(days=1)
    return list(reversed(out))


def synthetic_candles(symbol: str, interval: str = "1d", n: int = 400) -> dict:
    """A deterministic random walk, clearly labelled as fake.

    Deterministic so the tests can assert on it and so that re-opening a chart
    shows the same candles — a synthetic series that reshuffles on every load
    is worse than useless for debugging. Note this is a *plausible* walk, not a
    *market model*: no drift, no volatility clustering, no fat tails. It exists
    to render a chart, never to support a claim.
    """
    rng = random.Random(_seed_for(symbol))
    px = 100.0 + (rng.random() * 900)
    vol = 0.012 if interval in ("1d", "1wk") else 0.0035
    stamps = _synthetic_timestamps(interval, n)
    out = []
    for day in stamps:
        drift = rng.gauss(0.0, vol)
        op = px
        cl = px * (1.0 + drift)
        hi = max(op, cl) * (1.0 + abs(rng.gauss(0, vol * 0.4)))
        lo = min(op, cl) * (1.0 - abs(rng.gauss(0, vol * 0.4)))
        out.append(
            {
                "time": day,
                "open": round(op, 2),
                "high": round(hi, 2),
                "low": round(lo, 2),
                "close": round(cl, 2),
                "volume": int(rng.random() * 2_000_000 + 200_000),
            }
        )
        px = cl
    return {
        "symbol": symbol,
        "interval": interval,
        "candles": out,
        "is_synthetic": True,
        "source": "synthetic",
        "warning": (
            "SYNTHETIC DATA — no price feed was reachable. These candles are a "
            "random walk with no relationship to any real market. Do not draw "
            "any conclusion from this chart."
        ),
        "fetched_at": datetime.now(timezone.utc).isoformat(),
    }


# ---------------------------------------------------------------- live


def _live(symbol: str, interval: str, rng: str) -> dict | None:
    """Try yfinance. Returns None on any failure — never raises to the caller."""
    try:
        import yfinance as yf  # imported lazily: tests must not need the network
    except Exception:
        return None
    try:
        yf_interval, _ = INTERVALS.get(interval, ("1d", 1.0))
        df = yf.Ticker(symbol).history(
            period=RANGES.get(rng, "1y"), interval=yf_interval
        )
        if df is None or len(df) == 0:
            return None
        candles = []
        for idx, row in df.iterrows():
            ts = idx.timestamp() if hasattr(idx, "timestamp") else float(idx)
            o, h, l, c = (
                float(row["Open"]),
                float(row["High"]),
                float(row["Low"]),
                float(row["Close"]),
            )
            v = row.get("Volume")
            candles.append(
                {
                    "time": int(ts),
                    "open": round(o, 2),
                    "high": round(h, 2),
                    "low": round(l, 2),
                    "close": round(c, 2),
                    "volume": int(v) if v == v else 0,  # NaN check without numpy
                }
            )
        candles = [c for c in candles if c["open"] > 0]
        if not candles:
            return None
        candles.sort(key=lambda c: c["time"])
        return {
            "symbol": symbol,
            "interval": interval,
            "candles": candles,
            "is_synthetic": False,
            "source": "yfinance",
            "warning": None,
            "fetched_at": datetime.now(timezone.utc).isoformat(),
        }
    except Exception:
        return None


# ---------------------------------------------------------------- public


def get_candles(
    symbol: str, interval: str = "1d", rng: str = "1y", allow_synthetic: bool = True
) -> dict:
    """Resolve a symbol to a plottable candle series.

    `allow_synthetic` defaults to True so the app degrades to something
    visibly fake rather than to an empty screen. A caller that needs truth —
    a backtest, an autopsy, anything feeding a number — must pass False and
    handle the failure, because a synthetic series silently entering a
    calculation is how a fake Sharpe ratio gets printed.
    """
    if interval not in INTERVALS:
        raise MarketError(
            f"unknown interval {interval!r}; expected one of {sorted(INTERVALS)}"
        )
    if rng not in RANGES:
        raise MarketError(f"unknown range {rng!r}; expected one of {sorted(RANGES)}")

    yf_symbol, display = normalise_symbol(symbol)
    key = _cache_key(yf_symbol, interval, rng)
    if (cached := _cache_get(key)) is not None:
        return {**cached, "display": display, "cached": True}

    payload = _live(yf_symbol, interval, rng)
    if payload is None:
        if not allow_synthetic:
            raise MarketError(f"no price data available for {display}")
        payload = synthetic_candles(display, interval)
    payload["display"] = display
    payload["cached"] = False
    _cache_put(key, payload)
    return payload


def symbol_search(q: str, limit: int = 25) -> dict:
    """Resolve a typed string against a small built-in universe of NSE names.

    Kept local and exact for two reasons. A fuzzy match on a ticker is a
    correctness bug, not a convenience: typing INFY must never be "close
    enough" to a different company. And no free search API is licensed for
    anything a third party might call, so the honest answer is a list we own.
    """
    term = (q or "").strip().upper()
    if not term:
        return {
            "query": "",
            "count": len(UNIVERSE),
            "items": list(UNIVERSE.values())[:limit],
            "note": "Showing the whole built-in universe. Type to filter.",
        }
    exact = UNIVERSE.get(term)
    if exact:
        return {"query": term, "count": 1, "items": [exact], "note": "Exact match."}
    hits = [
        v
        for k, v in UNIVERSE.items()
        if k.startswith(term)
        or term in v["name"].upper()
        or term in v["sector"].upper()
    ]
    return {
        "query": term,
        "count": len(hits),
        "items": hits[:limit],
        "note": (
            "No exact match. These are prefix or text hits — check the company "
            "name before charting it."
            if hits
            else "Not in the built-in universe. You can still chart any symbol "
            "directly; it just won't be name-checked."
        ),
    }


def quote(symbol: str) -> dict:
    """Last close plus a change derived from the series already fetched.

    Deliberately not a separate network call — the chart has the candles, and
    deriving the change from them guarantees the header can never disagree with
    the chart below it.
    """
    d = get_candles(symbol, "1d", "3mo")
    cs = d["candles"]
    if not cs:
        raise MarketError(f"no candles for {d['display']}")
    last, prev = cs[-1], cs[-2] if len(cs) > 1 else cs[-1]
    change = last["close"] - prev["close"]
    return {
        "symbol": d["display"],
        "last": last["close"],
        "change": round(change, 2),
        "change_pct": round(change / prev["close"] * 100, 2) if prev["close"] else 0.0,
        "volume": last["volume"],
        "as_of": last["time"],
        "is_synthetic": d["is_synthetic"],
    }
