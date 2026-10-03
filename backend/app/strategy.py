"""Trading decisions, computed from the indicators and nothing else.

The hybrid AI rule applies with full force here. This module decides. The model
reads the `Verdict` it returns and explains it in words. If the model were
allowed to weigh in on the action, the product would be a horoscope with a
candlestick chart attached, and the whole claim that this app is different from
the AI-stock-tip spam it exists to replace would be false.

Three structural commitments follow from that:

1. **Every action carries its arithmetic.** Each vote is a `Reason` whose text
   names the indicator, the value it read, and the threshold it crossed. A
   verdict nobody can audit is a verdict nobody should trade on, and "the model
   thought it was a good setup" is exactly the failure mode that loses people
   money.

2. **Refusing to answer is a first-class outcome.** `NO_DATA` exists because a
   verdict during an indicator warm-up, on invented prices, or on too few bars
   is not a weak verdict — it is a fabricated one. A missing answer is the
   honest one.

3. **Conviction is normalised against the rules that were eligible to fire.** A
   raw score is not comparable across regimes: in a range, three trend rules
   being wrong means nothing, while in a trend three mean a great deal. Dividing
   by the eligible weight makes the threshold mean the same thing everywhere.

`confidence` is a **conviction score, not a probability.** Nothing here is
calibrated against outcomes, and it should never be printed as "73% likely to
work". For a claim about whether a *strategy* works, use `forensics.psr` and
`forensics.deflated_sharpe` — those are the tested, defensible numbers.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, Optional, Sequence

from .indicators import compute_all, snapshot

# --------------------------------------------------------------------------
# Actions
# --------------------------------------------------------------------------

BUY = "BUY"
SELL = "SELL"
HOLD = "HOLD"
AVOID = "AVOID"
NO_DATA = "NO_DATA"

ACTIONS = (BUY, SELL, HOLD, AVOID, NO_DATA)

# --------------------------------------------------------------------------
# Parameters. Named, not inlined, so a reader can audit the whole decision
# policy from one screen — and so tuning one threshold cannot silently change
# the meaning of another.
# --------------------------------------------------------------------------

#: Bars required before any verdict. SMA50 needs 50 and ATR needs 15; below 60
#: the trend inputs are warm and the verdict would be built on two moving
#: averages that are not there yet.
MIN_BARS = 60

#: ADX at or above this is a trend; below it is a range. Wilder's own reading:
#: below ~20 there is no trend worth the name, 25+ is a real one.
ADX_TREND = 25.0
ADX_RANGE = 20.0

#: Fraction of eligible weight that must agree before the action changes.
#: 0.35 means "more than a third of everything eligible is pointing the same
#: way", which is deliberately harder than any single indicator tipping it.
ENTRY_CONVICTION = 0.35

#: Daily ATR as a percentage of price above which the position cannot be sized
#: honestly. At 8% daily range, a 2%-risk position needs a stop so far away that
#: the size becomes a rounding error — the trade is unownable rather than bad.
MAX_ATR_PERCENT = 8.0

#: Squeeze: Bollinger width at or below this fraction of its own 120-bar mean.
#: Relative to itself, not an absolute number, because a 2% band is wide for a
#: bank and narrow for a small-cap.
SQUEEZE_RATIO = 0.75

#: RSI thresholds.
RSI_OVERSOLD = 30.0
RSI_OVERBOUGHT = 70.0

#: Conviction weights. Arbitrary but declared; they are a statement about how
#: much each family of evidence is trusted, and they are the first thing to
#: argue with when a verdict looks wrong.
W = {
    "rsi": 18.0,
    "macd_histogram": 14.0,
    "macd_cross": 10.0,
    "bollinger_pctb": 12.0,
    # Not a rule: `analyse` appends this inline as a direction-0 note when the
    # bands are compressed, and `_r` looks every weight up here. Kept in `W`
    # because removing it would KeyError the note, but it has no entry in
    # `_RULE_REGIMES` because it never votes.
    "bollinger_squeeze": 6.0,
    "trend_price": 16.0,
    "trend_stack": 12.0,
    "adx_di": 14.0,
    "supertrend": 14.0,
    "stochastic": 10.0,
    "volume": 10.0,
    "breakout": 12.0,
    "momentum": 8.0,
}

TREND_REGIMES = ("TREND_UP", "TREND_DOWN")
RANGE_REGIMES = ("RANGE",)


# --------------------------------------------------------------------------
# Value objects
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class Reason:
    """One rule's vote, with the arithmetic that produced it."""

    rule: str
    direction: int  # +1 bullish, -1 bearish, 0 neutral
    weight: float
    text: str

    def to_payload(self) -> dict:
        return {
            "rule": self.rule,
            "direction": self.direction,
            "weight": self.weight,
            "text": self.text,
        }


@dataclass
class Verdict:
    """The full decision, auditable end to end."""

    action: str
    score: float
    active_weight: float
    conviction: float
    agreement: float
    regime: str
    volatility: str
    squeeze: bool
    reasons: list[Reason] = field(default_factory=list)
    vetoes: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)
    bars_used: int = 0
    as_of: Optional[int] = None
    data_quality: str = "real"
    snapshot: dict = field(default_factory=dict)
    # Which rules pointed which way, so the next call can say what changed
    # rather than reprinting the same verdict with a new timestamp.
    fingerprint: dict[str, int] = field(default_factory=dict)

    def to_payload(self) -> dict:
        return {
            "action": self.action,
            "score": round(self.score, 2),
            "active_weight": round(self.active_weight, 2),
            "conviction": round(self.conviction, 4),
            "agreement": round(self.agreement, 4),
            "confidence_pct": int(round(self.conviction * 100)),
            "regime": self.regime,
            "volatility": self.volatility,
            "squeeze": self.squeeze,
            "reasons": [r.to_payload() for r in self.reasons],
            "vetoes": list(self.vetoes),
            "notes": list(self.notes),
            "bars_used": self.bars_used,
            "as_of": self.as_of,
            "data_quality": self.data_quality,
            "snapshot": self.snapshot,
            "fingerprint": dict(self.fingerprint),
            "basis": "snapshot",
            "disclaimer": (
                "A classification of the state of the last bar, not a timed "
                "instruction and not a price target. Nothing here is a "
                "recommendation to buy or sell any security. The conviction "
                "score is not a probability."
            ),
        }


@dataclass
class _Ctx:
    """Read-only view of the last two bars, so rules can see direction.

    Carries the whole computed panel, not just the snapshot: a rule that wants
    the last twenty returns should not recompute twenty-seven indicator series
    to get them.
    """

    snap: dict
    prev: dict
    series: dict
    bars: Sequence[dict]
    n: int
    last_close: float
    prev_close: float
    last_bar: dict

    def get(self, key: str) -> Optional[float]:
        v = self.snap.get(key)
        return v if isinstance(v, (int, float)) else None

    def delta(self, key: str) -> Optional[float]:
        a = self.get(key)
        b = self.prev.get(key)
        if a is None or not isinstance(b, (int, float)):
            return None
        return a - b


# --------------------------------------------------------------------------
# Regime
# --------------------------------------------------------------------------


def classify_regime(ctx: _Ctx) -> tuple[str, str, bool]:
    """Return (regime, volatility, squeeze).

    Regime first, because it decides which family of evidence is eligible to
    speak at all. Calling a mean-reversion oscillator inside a strong trend, or
    a breakout rule inside a range, is how indicator soup becomes a losing
    system.
    """
    adx = ctx.get("adx_14")
    pdi, mdi = ctx.get("plus_di"), ctx.get("minus_di")

    atr_pct = ctx.get("atr_percent")
    volatility = "UNKNOWN"
    if atr_pct is not None:
        volatility = "HIGH" if atr_pct >= MAX_ATR_PERCENT else "NORMAL"

    width = ctx.get("bollinger_width")
    squeeze = False
    if width is not None:
        known = [w for w in ctx.series["bollinger_width"] if w is not None]
        # Needs its own history before "narrow" means anything relative to
        # itself.
        if len(known) >= 60:
            mean = sum(known[-120:]) / len(known[-120:])
            squeeze = mean > 0 and width <= mean * SQUEEZE_RATIO

    if adx is None or pdi is None or mdi is None:
        return ("UNKNOWN", volatility, squeeze)
    if adx >= ADX_TREND:
        return ("TREND_UP" if pdi >= mdi else "TREND_DOWN", volatility, squeeze)
    if adx <= ADX_RANGE:
        return ("RANGE", volatility, squeeze)
    # Between the two thresholds there is a trend nobody can trade yet.
    return ("EMERGING", volatility, squeeze)


# --------------------------------------------------------------------------
# Rules
#
# Each returns a Reason or None. None means "not applicable here" and is not
# an error: the rule abstains rather than voting zero, so an abstention cannot
# be counted as evidence against a position.
# --------------------------------------------------------------------------

RuleFn = Callable[[_Ctx], Optional[Reason]]


def _r(r, direction: int, text: str) -> Reason:
    return Reason(rule=r, direction=direction, weight=W[r], text=text)


def rule_rsi(ctx: _Ctx) -> Optional[Reason]:
    """Mean reversion on a stretched oscillator. Range only.

    In a trend an RSI of 25 is not cheap, it is the start of a fall, and the
    oscillator keeps saying 25 for weeks. The gating is the entire rule.
    """
    v = ctx.get("rsi_14")
    if v is None:
        return None
    if v <= RSI_OVERSOLD:
        return _r(
            "rsi",
            1,
            f"RSI(14) is {v:.1f}, at or below the {RSI_OVERSOLD:.0f} oversold line.",
        )
    if v >= RSI_OVERBOUGHT:
        return _r(
            "rsi",
            -1,
            f"RSI(14) is {v:.1f}, at or above the {RSI_OVERBOUGHT:.0f} overbought line.",
        )
    return _r("rsi", 0, f"RSI(14) is {v:.1f}, neutral.")


def rule_macd_histogram(ctx: _Ctx) -> Optional[Reason]:
    """Sign, slope, and agreement with the line underneath.

    The histogram's sign alone is a trap. In a sustained decline the MACD line
    sits at -1.15 and the histogram crosses positive the moment the fall
    decelerates — arithmetically bullish, and completely wrong to read as
    "momentum is positive". The histogram measures the *rate of change of a
    line that is itself below zero*, which is a counter-trend twitch, not a
    reversal. So the vote keeps the histogram's sign but takes only half the
    weight when the line disagrees, and says so out loud.
    """
    h = ctx.get("macd_histogram")
    m = ctx.get("macd")
    if h is None:
        return None
    d = ctx.delta("macd_histogram")
    slope = "rising" if (d or 0.0) > 0 else "falling"
    aligned = m is None or (m > 0) == (h > 0)
    caveat = (
        ""
        if aligned
        else (
            f" but the MACD line itself is {m:+.3f}, so this is a counter-trend "
            "twitch rather than a reversal"
        )
    )
    r = _r(
        "macd_histogram",
        1 if h > 0 else (-1 if h < 0 else 0),
        f"MACD histogram is {h:+.3f} and {slope} — momentum is "
        f"{'positive' if h > 0 else 'negative'}{caveat}.",
    )
    if aligned or r.direction == 0:
        return r
    # Halved, not dropped: a decelerating counter-trend move is still evidence.
    return Reason(r.rule, r.direction, r.weight / 2.0, r.text)


def rule_macd_cross(ctx: _Ctx) -> Optional[Reason]:
    """A fresh line/signal cross is information; a cross from three bars ago is history."""
    m, s = ctx.get("macd"), ctx.get("macd_signal")
    if m is None or s is None:
        return None
    pm = ctx.prev.get("macd")
    ps = ctx.prev.get("macd_signal")
    if not isinstance(pm, (int, float)) or not isinstance(ps, (int, float)):
        return None
    was = pm - ps
    now = m - s
    if now > 0 and was <= 0:
        return _r(
            "macd_cross",
            1,
            f"MACD {m:+.3f} crossed above its signal line {s:+.3f} on this bar.",
        )
    if now < 0 and was >= 0:
        return _r(
            "macd_cross",
            -1,
            f"MACD {m:+.3f} crossed below its signal line {s:+.3f} on this bar.",
        )
    return _r("macd_cross", 0, "No fresh MACD/signal cross on this bar.")


def rule_bollinger_pctb(ctx: _Ctx) -> Optional[Reason]:
    """Where the close sits inside the band."""
    pb = ctx.get("percent_b")
    if pb is None:
        return None
    if pb <= 0.0:
        return _r(
            "bollinger_pctb",
            1,
            f"Close is at or below the lower Bollinger band (%B {pb:.2f}).",
        )
    if pb >= 1.0:
        return _r(
            "bollinger_pctb",
            -1,
            f"Close is at or above the upper Bollinger band (%B {pb:.2f}).",
        )
    return _r("bollinger_pctb", 0, f"Close sits inside the bands (%B {pb:.2f}).")


def rule_trend_price(ctx: _Ctx) -> Optional[Reason]:
    """Close against the 50-period average."""
    if ctx.get("sma_50") is None:
        return None
    ma = ctx.get("sma_50")
    gap = (ctx.last_close - ma) / ma * 100 if ma else 0.0
    if ctx.last_close > ma:
        return _r(
            "trend_price",
            1,
            f"Close {ctx.last_close:.2f} is {gap:+.2f}% above SMA(50) {ma:.2f}.",
        )
    return _r(
        "trend_price",
        -1,
        f"Close {ctx.last_close:.2f} is {gap:+.2f}% below SMA(50) {ma:.2f}.",
    )


def rule_trend_stack(ctx: _Ctx) -> Optional[Reason]:
    """Fast above slow, or the reverse. The most watched line cross there is."""
    a, b = ctx.get("sma_20"), ctx.get("sma_50")
    if a is None or b is None or b == 0:
        return None
    if a > b:
        return _r("trend_stack", 1, f"SMA(20) {a:.2f} is above SMA(50) {b:.2f}.")
    return _r("trend_stack", -1, f"SMA(20) {a:.2f} is below SMA(50) {b:.2f}.")


def rule_adx_di(ctx: _Ctx) -> Optional[Reason]:
    """ADX says a trend exists; DI says which way. Both or neither."""
    adx, pdi, mdi = ctx.get("adx_14"), ctx.get("plus_di"), ctx.get("minus_di")
    if adx is None or pdi is None or mdi is None:
        return None
    if adx < ADX_TREND:
        return _r(
            "adx_di",
            0,
            f"ADX {adx:.1f} is below {ADX_TREND:.0f} — there is no trend strong enough to lean on.",
        )
    if pdi > mdi:
        return _r(
            "adx_di",
            1,
            f"ADX {adx:.1f} with +DI {pdi:.1f} above -DI {mdi:.1f} — the trend, if any, is up.",
        )
    return _r(
        "adx_di",
        -1,
        f"ADX {adx:.1f} with -DI {mdi:.1f} above +DI {pdi:.1f} — the trend, if any, is down.",
    )


def rule_supertrend(ctx: _Ctx) -> Optional[Reason]:
    """A confirmed close on the far side of the band."""
    t = ctx.get("supertrend")
    d = ctx.get("supertrend_direction")
    if t is None or d is None:
        return None
    if d > 0:
        return _r(
            "supertrend",
            1,
            f"Close is above the Supertrend band ({t:.2f}); the regime is long.",
        )
    return _r(
        "supertrend",
        -1,
        f"Close is below the Supertrend band ({t:.2f}); the regime is short.",
    )


def rule_stochastic(ctx: _Ctx) -> Optional[Reason]:
    """%K against %D. Range only — see `rule_rsi` for why."""
    k, d = ctx.get("stoch_k"), ctx.get("stoch_d")
    if k is None or d is None:
        return None
    if k > d:
        return _r("stochastic", 1, f"Stochastic %K {k:.1f} is above %D {d:.1f}.")
    return _r("stochastic", -1, f"Stochastic %K {k:.1f} is below %D {d:.1f}.")


def rule_volume(ctx: _Ctx) -> Optional[Reason]:
    """Price and on-balance volume must agree before the move is believed."""
    obv = ctx.get("obv")
    if obv is None or ctx.n < 3:
        return None
    v = ctx.bars[-1].get("volume") or 0
    recent = sum((b.get("volume") or 0) for b in ctx.bars[-21:-1]) / 20.0
    if recent <= 0:
        return None
    ratio = v / recent
    up = ctx.last_close > ctx.prev_close
    if ratio >= 1.5:
        d = 1 if up else -1
        word = "advancing" if up else "declining"
        return _r(
            "volume",
            d,
            f"Volume is {ratio:.2f}x its 20-bar average while price is {word} — participation confirms the move.",
        )
    return _r("volume", 0, f"Volume is {ratio:.2f}x its 20-bar average — unremarkable.")


def rule_breakout(ctx: _Ctx) -> Optional[Reason]:
    """A close outside the 20-bar channel."""
    hi, lo = ctx.get("donchian_upper"), ctx.get("donchian_lower")
    if hi is None or lo is None:
        return None
    if ctx.last_close > hi:
        return _r(
            "breakout",
            1,
            f"Close {ctx.last_close:.2f} is above the 20-bar high {hi:.2f}.",
        )
    if ctx.last_close < lo:
        return _r(
            "breakout",
            -1,
            f"Close {ctx.last_close:.2f} is below the 20-bar low {lo:.2f}.",
        )
    return _r("breakout", 0, "Price is inside the 20-bar channel.")


def rule_momentum(ctx: _Ctx) -> Optional[Reason]:
    """Twenty-bar return, because a regime that is already extended is a risk."""
    ret = ctx.get("returns")
    if ret is None:
        return None
    total = sum(x for x in ctx.series["returns"][-20:] if x is not None)
    pct = total * 100
    if pct > 5:
        return _r(
            "momentum",
            -1,
            f"Up {pct:+.1f}% over 20 bars — extended, and extended moves mean-revert.",
        )
    if pct < -5:
        return _r(
            "momentum",
            1,
            f"Down {pct:+.1f}% over 20 bars — washed out, or falling fast.",
        )
    return _r("momentum", 0, f"20-bar return is {pct:+.1f}% — unremarkable.")


#: Which regimes each rule is eligible to speak in. A trend rule inside a range
#: is not weak evidence, it is irrelevant evidence, and counting it would let a
#: range be overpowered by four moving averages.
_RULE_REGIMES: dict[str, tuple[str, ...]] = {
    "rsi": RANGE_REGIMES,
    "macd_histogram": TREND_REGIMES + RANGE_REGIMES,
    "macd_cross": TREND_REGIMES + RANGE_REGIMES,
    "bollinger_pctb": TREND_REGIMES + RANGE_REGIMES,
    "trend_price": TREND_REGIMES,
    "trend_stack": TREND_REGIMES,
    "adx_di": TREND_REGIMES,
    "supertrend": TREND_REGIMES,
    "stochastic": RANGE_REGIMES,
    "volume": TREND_REGIMES + RANGE_REGIMES,
    "breakout": TREND_REGIMES,
    "momentum": TREND_REGIMES + RANGE_REGIMES,
}

# The regime-agnostic ones always speak, whatever ADX says.
_ELIGIBLE_IN = TREND_REGIMES + RANGE_REGIMES + ("EMERGING",)

RULES: dict[str, RuleFn] = {
    "rsi": rule_rsi,
    "macd_histogram": rule_macd_histogram,
    "macd_cross": rule_macd_cross,
    "bollinger_pctb": rule_bollinger_pctb,
    "trend_price": rule_trend_price,
    "trend_stack": rule_trend_stack,
    "adx_di": rule_adx_di,
    "supertrend": rule_supertrend,
    "stochastic": rule_stochastic,
    "volume": rule_volume,
    "breakout": rule_breakout,
    "momentum": rule_momentum,
}


# --------------------------------------------------------------------------
# The decision
# --------------------------------------------------------------------------


def analyse(
    bars: Sequence[dict],
    *,
    synthetic: bool = False,
    previous: Optional[Verdict] = None,
) -> Verdict:
    """Decide, and say why.

    `synthetic=True` is not a flag about confidence, it is a refusal. No
    pattern in invented prices describes any market, so a signal computed on it
    is a fabrication dressed as an analysis — and this app's entire argument is
    against exactly that. Callers that allow a synthetic fallback must pass the
    provenance through here.
    """
    bars = list(bars)
    n = len(bars)
    as_of = (
        bars[-1].get("time") if bars and isinstance(bars[-1].get("time"), int) else None
    )

    def blank(action: str, note: str) -> Verdict:
        return Verdict(
            action=action,
            score=0.0,
            active_weight=0.0,
            conviction=0.0,
            agreement=0.0,
            regime="UNKNOWN",
            volatility="UNKNOWN",
            squeeze=False,
            notes=[note],
            bars_used=n,
            as_of=as_of,
            data_quality="synthetic" if synthetic else "real",
        )

    if synthetic:
        return blank(
            NO_DATA,
            "These bars are synthetic. No pattern in invented prices "
            "describes any market, so no signal is offered. Connect a "
            "price feed.",
        )
    if n < MIN_BARS:
        return blank(
            NO_DATA,
            f"Only {n} bars supplied. At least {MIN_BARS} are needed "
            "before SMA(50), ATR(14) and ADX(14) are real rather than "
            "warm-up padding.",
        )

    # `snapshot()` recomputes the panel internally, so this is a second full
    # pass. Acceptable at 500 bars, and worth a cache if it ever is not.
    ind = compute_all(bars)
    snap = snapshot(bars)
    last, prev = bars[-1], bars[-2]

    # Second-to-last value per series, for slope and cross detection.
    prev_snap: dict = {}
    for k, series in ind.items():
        if len(series) >= 2 and isinstance(series[-2], (int, float)):
            prev_snap[k] = series[-2]

    ctx = _Ctx(
        snap=snap,
        prev=prev_snap,
        series=ind,
        bars=bars,
        n=n,
        last_close=float(last["close"]),
        prev_close=float(prev["close"]),
        last_bar=last,
    )

    regime, volatility, squeeze = classify_regime(ctx)

    if regime == "UNKNOWN":
        return Verdict(
            action=NO_DATA,
            score=0.0,
            active_weight=0.0,
            conviction=0.0,
            agreement=0.0,
            regime=regime,
            volatility=volatility,
            squeeze=squeeze,
            notes=[
                "ADX and the directional indicators have not warmed up, so "
                "the regime cannot be classified. Without a regime there is "
                "no defensible action."
            ],
            bars_used=n,
            as_of=as_of,
            snapshot=snap,
        )

    reasons: list[Reason] = []
    for name, fn in RULES.items():
        eligible = _RULE_REGIMES.get(name, _ELIGIBLE_IN)
        if regime not in eligible:
            continue  # abstains: not evidence against, just not evidence
        got = fn(ctx)
        if got is not None:
            reasons.append(got)

    if squeeze:
        reasons.append(
            _r(
                "bollinger_squeeze",
                0,
                "Bollinger width is compressed versus its own recent history — "
                "a coil, not a direction.",
            )
        )

    # Active weight is what *could* have spoken, including rules that abstained
    # because their own warm-up finished late. Excluding them would let a rule
    # that returned None count as agreement.
    active_weight = sum(
        W[name] for name in RULES if regime in _RULE_REGIMES.get(name, _ELIGIBLE_IN)
    )
    score = sum(r.weight * r.direction for r in reasons)
    conviction = abs(score) / active_weight if active_weight else 0.0

    votes = [r for r in reasons if r.direction != 0]
    agreeing = sum(1 for r in votes if (r.direction > 0) == (score > 0))
    agreement = agreeing / len(votes) if votes else 0.0

    vetoes: list[str] = []
    if volatility == "HIGH":
        ap = ctx.get("atr_percent") or 0.0
        vetoes.append(
            f"Daily ATR is {ap:.2f}% of price, at or above the "
            f"{MAX_ATR_PERCENT:.0f}% ceiling. At this range a risk-sized stop "
            "sits so far from entry that the position becomes a rounding "
            "error. The trade is not wrong, it is unownable."
        )

    if vetoes:
        action = AVOID
    elif conviction >= ENTRY_CONVICTION and score > 0:
        action = BUY
    elif conviction >= ENTRY_CONVICTION and score < 0:
        action = SELL
    else:
        action = HOLD

    notes = [
        "Conviction is the share of eligible weight pointing one way, not a "
        "probability that this trade works. For a tested claim about a "
        "strategy, run it through the Autopsy tab.",
    ]
    if squeeze:
        notes.append("Squeeze: bands are compressed. Expect expansion, not direction.")
    if previous is not None:
        notes.extend(what_changed(previous, reasons, action))

    return Verdict(
        action=action,
        score=score,
        active_weight=active_weight,
        conviction=conviction,
        agreement=agreement,
        regime=regime,
        volatility=volatility,
        squeeze=squeeze,
        reasons=reasons,
        vetoes=vetoes,
        notes=notes,
        bars_used=n,
        as_of=as_of,
        snapshot=snap,
        fingerprint={r.rule: r.direction for r in reasons},
    )


def what_changed(
    previous: Verdict, reasons: Sequence[Reason], action: str
) -> list[str]:
    """Explain the delta, not the verdict.

    A verdict that only ever states its own conclusion forces the reader to
    diff it against yesterday by hand, which nobody does. Naming the rules that
    flipped is the difference between a dashboard and an explanation.
    """
    old = previous.fingerprint or {}
    new = {r.rule: r.direction for r in reasons}
    out: list[str] = []
    flipped = [
        f"{k}: {old[k]:+d} → {new[k]:+d}"
        for k in sorted(set(old) | set(new))
        if k in old and k in new and old[k] != new[k]
    ]
    entered = [k for k in new if k not in old and new[k] != 0]
    left = [k for k in old if k not in new and old[k] != 0]
    if previous.action != action:
        out.append(f"Action moved {previous.action} → {action}.")
    if flipped:
        out.append("Rules that flipped — " + "; ".join(flipped) + ".")
    if entered:
        out.append("Newly voting — " + ", ".join(sorted(entered)) + ".")
    if left:
        out.append("No longer voting — " + ", ".join(sorted(left)) + ".")
    return out


def scan(
    bars_list: dict[str, Sequence[dict]], *, synthetic_symbols: Sequence[str] = ()
) -> dict:
    """Run the engine across a universe, honestly.

    One `unavailable` entry per symbol that cannot be judged, rather than an
    omitted entry — a scanner that silently drops what it cannot analyse is a
    scanner showing you only the easy names.
    """
    synthetic = set(synthetic_symbols)
    out = {"as_of": None, "results": [], "unavailable": [], "summary": {}}
    for sym, bars in bars_list.items():
        v = analyse(bars, synthetic=sym in synthetic)
        if v.action == NO_DATA:
            out["unavailable"].append(
                {
                    "symbol": sym,
                    "reason": "; ".join(v.notes),
                }
            )
            continue
        if out["as_of"] is None or (v.as_of or 0) > out["as_of"]:
            out["as_of"] = v.as_of
        out["results"].append(
            {
                "symbol": sym,
                "action": v.action,
                "conviction": round(v.conviction, 4),
                "confidence_pct": int(round(v.conviction * 100)),
                "regime": v.regime,
                "last_close": round(float(bars[-1]["close"]), 2) if bars else None,
                "snapshot": v.snapshot,
            }
        )
    out["results"].sort(key=lambda r: -r["confidence_pct"])
    counts = {a: 0 for a in ACTIONS}
    for r in out["results"]:
        counts[r["action"]] += 1
    out["summary"] = counts
    return out
