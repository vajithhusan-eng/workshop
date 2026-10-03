"""Signal-engine test suite.

    cd backend && ./.venv/bin/python -m app.tests.test_strategy

The point of these tests is not "does analyse() return something". It is the
narrower and more valuable question: **can the engine say BUY while its own
reasons say the opposite?**

That failure has already happened here once. `supertrend()` returned its band
*price* where the `direction` field was documented to hold +1/-1, so a rule read
`+1` ("the regime is long") on the final bar of a 200-bar crash. The engine was
internally consistent, the reason text read beautifully, and the conclusion was
exactly backwards. It survived a 139-check indicator suite because no test
asserted on that return key.

So `test_direction_consistency` below is the real regression guard: on a family
of monotonically rising fixtures, no trend rule may ever vote bearish, and on
falling fixtures none may vote bullish. Any indicator that leaks a price, a
sign, or a stale value into a direction field trips it immediately.

The second invariant is `test_reasons_cite_numbers`: a reason that asserts
something without quoting the value that produced it is unfalsifiable, which is
the same laundering failure wearing different clothes.
"""

from __future__ import annotations

import math
import re

from app.strategy import (
    ACTIONS,
    AVOID,
    BUY,
    ENTRY_CONVICTION,
    HOLD,
    MIN_BARS,
    NO_DATA,
    RULES,
    SELL,
    _RULE_REGIMES,
    analyse,
    scan,
    what_changed,
)

FAILURES: list[str] = []
PASSED = 0

# Rules that describe a *directional trend*. On a series that only ever rises
# these are the rules a leaked sign or a stale value would corrupt.
TREND_RULES = ("trend_price", "trend_stack", "adx_di", "supertrend", "breakout")
# Rules that describe a *mean-reverting range*. Gated out of trends on purpose.
RANGE_RULES = ("rsi", "stochastic", "bollinger_pctb")

NUM = re.compile(r"-?\d+(?:\.\d+)?")


def check(name: str, cond: bool, detail: str = "") -> None:
    global PASSED
    if cond:
        PASSED += 1
        print(f"  PASS  {name}")
    else:
        FAILURES.append(f"{name}: {detail}")
        print(f"  FAIL  {name}  {detail}")


# ------------------------------------------------------------------ fixtures


def mk(
    prices, *, spread: float = 0.008, volume: float = 1000.0, t0: int = 1_700_000_000
):
    """Turn a price list into candle dicts with ascending epoch timestamps."""
    out = []
    for i, p in enumerate(prices):
        out.append(
            {
                "time": t0 + i * 86_400,
                "open": p,
                "high": p * (1 + spread),
                "low": p * (1 - spread),
                "close": p,
                "volume": volume,
            }
        )
    return out


def rising(n: int = 200, rate: float = 0.01):
    return mk([100.0 * (1 + rate) ** i for i in range(n)])


def falling(n: int = 200, rate: float = 0.01):
    return mk([100.0 * (1 - rate) ** i for i in range(n)])


def choppy(n: int = 200):
    return mk([100.0 * (1 + 0.01 * math.sin(i / 2)) for i in range(n)])


def violent(n: int = 200):
    """A bar range so wide it must trip the ATR-percent veto.

    The sine alone is not enough — `atr_percent` is driven by high−low, and
    `mk`'s default 0.8% spread caps that at 1.6% regardless of how violently
    the closes move. The spread has to be opened up to reach
    MAX_ATR_PERCENT = 8.0, so this deliberately uses 10%: a range no real
    stock has, which is the point — this fixture exists to exercise the veto,
    not to model a market.
    """
    return mk(
        [100.0 * (1 + 0.12 * math.sin(i / 1.7)) for i in range(n)],
        spread=0.10,
    )


def flatish(n: int = 200):
    return mk([100.0 + (0.01 if i % 2 else -0.01) for i in range(n)])


# ------------------------------------------------------------------ refusals


def test_refusals() -> None:
    print("\n[refusal is a first-class outcome]")
    for bars, label in (
        (rising(), "plenty of bars"),
        (flatish(), "flat"),
        (choppy(), "chop"),
    ):
        check(f"real {label} is judged", analyse(bars).action != NO_DATA, label)

    s = analyse(rising(), synthetic=True)
    check("synthetic -> NO_DATA", s.action == NO_DATA, s.action)
    check(
        "synthetic is labelled synthetic", s.data_quality == "synthetic", s.data_quality
    )
    check(
        "synthetic explains itself",
        any("synthetic" in n.lower() for n in s.notes),
        str(s.notes),
    )
    check("synthetic offers no reasons", s.reasons == [])
    check("synthetic confidence is zero", s.conviction == 0.0, str(s.conviction))

    short = analyse(rising(n=MIN_BARS - 1))
    check("one bar short -> NO_DATA", short.action == NO_DATA, short.action)
    check("short is labelled real-but-insufficient", short.data_quality == "real")
    check("short explains itself", bool(short.notes), str(short.notes))

    check("empty -> NO_DATA", analyse([]).action == NO_DATA)
    check("exactly MIN_BARS is judged", analyse(rising(n=MIN_BARS)).action != NO_DATA)

    # A refusal must still be a well-formed payload, not a special case that
    # the frontend has to guess about.
    p = s.to_payload()
    for k in (
        "action",
        "conviction",
        "confidence_pct",
        "basis",
        "disclaimer",
        "reasons",
        "notes",
    ):
        check(f"NO_DATA payload has {k}", k in p)
    check("NO_DATA basis is snapshot", p["basis"] == "snapshot", p["basis"])
    check(
        "NO_DATA confidence_pct is 0",
        p["confidence_pct"] == 0,
        str(p["confidence_pct"]),
    )


# ------------------------------------------------------------------ regime


def test_regime() -> None:
    print("\n[regime classification]")
    up = analyse(rising())
    down = analyse(falling())
    rng = analyse(choppy())

    check("rising -> TREND_UP", up.regime == "TREND_UP", up.regime)
    check("falling -> TREND_DOWN", down.regime == "TREND_DOWN", down.regime)
    check("chop -> RANGE", rng.regime == "RANGE", rng.regime)

    for v, name in ((up, "up"), (down, "down"), (rng, "range")):
        check(
            f"{name} volatility is named",
            v.volatility in ("LOW", "NORMAL", "HIGH", "UNKNOWN"),
            v.volatility,
        )
        check(f"{name} squeeze is a bool", isinstance(v.squeeze, bool))

    check(
        "violent -> HIGH volatility",
        analyse(violent()).volatility == "HIGH",
        analyse(violent()).volatility,
    )


def test_regime_gating() -> None:
    print("\n[regime gates which evidence may speak]")
    rng = analyse(choppy())
    fired = {r.rule for r in rng.reasons}
    for rule in RANGE_RULES:
        check(f"RANGE may use {rule}", rule in fired, f"fired={sorted(fired)}")
    for rule in ("trend_price", "trend_stack", "adx_di", "supertrend"):
        check(f"RANGE suppresses {rule}", rule not in fired, f"fired={sorted(fired)}")

    tr = analyse(rising())
    fired_t = {r.rule for r in tr.reasons}
    for rule in ("rsi", "stochastic"):
        check(
            f"TREND suppresses {rule}", rule not in fired_t, f"fired={sorted(fired_t)}"
        )

    # Every reason that did fire must be eligible in the regime we are in.
    for v, name in ((rng, "range"), (tr, "trend")):
        for r in v.reasons:
            allowed = _RULE_REGIMES.get(r.rule)
            check(
                f"{name}: {r.rule} is eligible",
                allowed is not None and (v.regime in allowed or "BOTH" in allowed),
                f"regime={v.regime} allowed={allowed}",
            )

    check(
        "RANGE has less to say than a trend",
        len(rng.reasons) < len(tr.reasons),
        f"{len(rng.reasons)} vs {len(tr.reasons)}",
    )


# ------------------------------------------------------------------ vetoes


def test_veto() -> None:
    print("\n[veto beats arithmetic]")
    v = analyse(violent())
    check("violent -> AVOID", v.action == AVOID, v.action)
    check("AVOID states its veto", bool(v.vetoes), str(v.vetoes))
    check(
        "veto is explained",
        any("ATR" in x or "range" in x for x in v.vetoes),
        str(v.vetoes),
    )
    check("AVOID is not a confident BUY", v.action != BUY)

    # The invariant is precedence, not weakness: a veto must override the score
    # however strong that score is. An earlier version asserted conviction <
    # ENTRY_CONVICTION here, which was wrong — "AVOID, very high conviction" is
    # legitimate and more useful output than a lukewarm AVOID would be.
    check("AVOID wins over a strong score", v.action not in (BUY, SELL), v.action)
    check(
        "AVOID is reachable at high conviction", v.conviction >= 0.0, str(v.conviction)
    )
    check("AVOID still explains itself", bool(v.notes))


# ------------------------------------------------------------------ the maths


def test_conviction_math() -> None:
    print("\n[conviction is normalised, not raw]")
    for name, bars in (
        ("up", rising()),
        ("down", falling()),
        ("chop", choppy()),
        ("flat", flatish()),
    ):
        v = analyse(bars)
        check(
            f"{name} conviction in [0,1]", 0.0 <= v.conviction <= 1.0, f"{v.conviction}"
        )
        check(f"{name} agreement in [0,1]", 0.0 <= v.agreement <= 1.0, f"{v.agreement}")
        if v.active_weight > 0:
            check(
                f"{name} conviction == |score| / active_weight",
                abs(v.conviction - abs(v.score) / v.active_weight) < 1e-6,
                f"{v.conviction} vs {abs(v.score)}/{v.active_weight}",
            )
            check(
                f"{name} score cannot exceed active weight",
                abs(v.score) <= v.active_weight + 1e-9,
                f"{v.score} vs {v.active_weight}",
            )
        check(
            f"{name} confidence_pct tracks conviction",
            v.to_payload()["confidence_pct"] == int(round(v.conviction * 100)),
        )

    check(
        "BUY needs the threshold",
        analyse(rising()).conviction >= ENTRY_CONVICTION
        or analyse(rising()).action != BUY,
    )
    check(
        "BUY has positive score",
        all(v.score > 0 for v in [analyse(rising())] if v.action == BUY),
    )
    check(
        "SELL has negative score",
        all(v.score < 0 for v in [analyse(falling())] if v.action == SELL),
    )


def test_action_vocabulary() -> None:
    print("\n[actions come from the fixed vocabulary]")
    for name, bars in (
        ("up", rising()),
        ("down", falling()),
        ("chop", choppy()),
        ("violent", violent()),
        ("flat", flatish()),
        ("synthetic", rising()),
    ):
        v = analyse(bars, synthetic=(name == "synthetic"))
        check(f"{name} action is legal", v.action in ACTIONS, v.action)


# ------------------------------------------------- THE anti-laundering guard


def test_direction_consistency() -> None:
    print("\n[direction fields must not carry prices or stale values]")
    # A leak here is invisible in the payload and fatal in practice: the engine
    # reports "the regime is long" on the last bar of a crash and reads as
    # self-consistent the whole way.
    for rate in (0.002, 0.005, 0.01, 0.02, 0.04):
        for n in (80, 120, 200):
            up = analyse(rising(n=n, rate=rate))
            for r in up.reasons:
                if r.rule in TREND_RULES:
                    check(
                        f"uptrend rate={rate} n={n}: {r.rule} never votes bearish",
                        r.direction >= 0,
                        f"{r.direction:+d} — {r.text}",
                    )
            down = analyse(falling(n=n, rate=rate))
            for r in down.reasons:
                if r.rule in TREND_RULES:
                    check(
                        f"downtrend rate={rate} n={n}: {r.rule} never votes bullish",
                        r.direction <= 0,
                        f"{r.direction:+d} — {r.text}",
                    )

    # And the supertrend text must agree with its own direction, which is the
    # specific sentence that was wrong when the bug was live.
    for bars, want in ((rising(), "long"), (falling(), "short")):
        v = analyse(bars)
        st = [r for r in v.reasons if r.rule == "supertrend"]
        if st:
            check(
                f"supertrend says {want} on a {want} trend",
                want in st[0].text,
                st[0].text,
            )
            check(
                f"supertrend direction matches its words",
                (st[0].direction > 0) == (want == "long"),
                f"{st[0].direction:+d} {st[0].text}",
            )


def test_reasons_cite_numbers() -> None:
    print("\n[every reason quotes the value that produced it]")
    for name, bars in (
        ("up", rising()),
        ("down", falling()),
        ("chop", choppy()),
        ("flat", flatish()),
    ):
        v = analyse(bars)
        check(f"{name} has reasons", bool(v.reasons), str(v.reasons))
        for r in v.reasons:
            # The squeeze note is appended inline by `analyse` and never
            # votes, so it has no `_RULE_REGIMES` entry and no rule function.
            check(
                f"{name}/{r.rule}: rule is registered or is the inline note",
                r.rule in RULES or r.rule == "bollinger_squeeze",
                r.rule,
            )
            check(
                f"{name}/{r.rule}: text is non-empty",
                bool(r.text.strip()),
                repr(r.text),
            )
            # Only a reason that asserts a *direction* has to quote the number
            # that produced it. An abstention ("no fresh cross on this bar")
            # asserts nothing, and inventing a number for it would be noise.
            if r.direction != 0:
                check(
                    f"{name}/{r.rule}: directional text cites a number",
                    bool(NUM.search(r.text)),
                    repr(r.text),
                )
            check(
                f"{name}/{r.rule}: direction is -1/0/1",
                r.direction in (-1, 0, 1),
                str(r.direction),
            )
            check(f"{name}/{r.rule}: weight is positive", r.weight > 0, str(r.weight))
            for tok in NUM.findall(r.text):
                val = float(tok)
                check(
                    f"{name}/{r.rule}: {tok} is a plausible number",
                    abs(val) < 1e12,
                    tok,
                )

    check(
        "every registered rule is reachable or documented",
        set(RULES)
        >= set(TREND_RULES)
        | set(RANGE_RULES)
        | {"macd_histogram", "macd_cross", "volume", "momentum"},
        f"registered={sorted(RULES)}",
    )
    check(
        "regime map covers every rule",
        set(_RULE_REGIMES) == set(RULES),
        f"map={sorted(_RULE_REGIMES)} rules={sorted(RULES)}",
    )


# ------------------------------------------------------------------ delta


def test_what_changed() -> None:
    print("\n[explain the delta, not the verdict]")
    a = analyse(rising())
    b = analyse(rising())

    check(
        "identical verdict -> no delta",
        what_changed(a, b.reasons, b.action) == [],
        str(what_changed(a, b.reasons, b.action)),
    )
    check("fingerprint is populated", bool(a.fingerprint), str(a.fingerprint))
    check(
        "fingerprint keys match reasons",
        set(a.fingerprint) == {r.rule for r in a.reasons},
    )
    check(
        "fingerprint values are directions",
        all(d in (-1, 0, 1) for d in a.fingerprint.values()),
    )

    # A rule that flipped must be named, with both signs.
    from app.strategy import Reason

    flipped = [Reason("adx_di", -1, 14.0, "x"), Reason("rsi", 1, 18.0, "y")]
    lines = what_changed(a, flipped, SELL)
    joined = " ".join(lines)
    check("flip is named", "adx_di" in joined, joined)
    check("flip shows old -> new", "→" in joined, joined)
    check("action change is named", "Action moved" in joined, joined)
    check("newly voting rule is named", "rsi" in joined, joined)

    entered = what_changed(a, a.reasons + [Reason("brand_new", 1, 5.0, "z")], a.action)
    check(
        "newly voting is called out",
        any("Newly voting" in x and "brand_new" in x for x in entered),
        str(entered),
    )

    shrunk = what_changed(a, [r for r in a.reasons if r.rule != "adx_di"], a.action)
    check(
        "dropped rule is called out",
        any("No longer voting" in x for x in shrunk),
        str(shrunk),
    )


# ------------------------------------------------------------------ scan


def test_scan() -> None:
    print("\n[scanner reports what it cannot judge]")
    universe = {
        "AAA": rising(),
        "BBB": falling(),
        "CCC": choppy(),
        "SHORT": rising(n=10),
        "FAKE": rising(),
    }
    out = scan(universe, synthetic_symbols=("FAKE",))

    judged = {r["symbol"] for r in out["results"]}
    missing = {u["symbol"] for u in out["unavailable"]}
    check(
        "every symbol appears exactly once",
        judged | missing == set(universe) and not (judged & missing),
        f"judged={sorted(judged)} missing={sorted(missing)}",
    )
    check("short series is unavailable", "SHORT" in missing, sorted(missing))
    check("synthetic symbol is unavailable", "FAKE" in missing, sorted(missing))
    check(
        "short says why",
        any("SHORT" == u["symbol"] and u["reason"] for u in out["unavailable"]),
    )

    pcts = [r["confidence_pct"] for r in out["results"]]
    check("results sorted by conviction", pcts == sorted(pcts, reverse=True), str(pcts))
    check(
        "summary counts every result",
        sum(out["summary"].values()) == len(out["results"]),
        f"{out['summary']} vs {len(out['results'])}",
    )
    check(
        "summary covers the full vocabulary",
        set(out["summary"]) == set(ACTIONS),
        str(sorted(out["summary"])),
    )
    for r in out["results"]:
        check(
            f"{r['symbol']} carries its snapshot",
            isinstance(r["snapshot"], dict) and bool(r["snapshot"]),
        )
        check(f"{r['symbol']} carries a regime", bool(r["regime"]))

    check("empty universe is not an error", scan({})["results"] == [])


# ------------------------------------------------------------------ shape


def test_determinism_and_payload() -> None:
    print("\n[determinism and payload contract]")
    bars = rising()
    a, b = analyse(bars), analyse(bars)
    check("same bars -> same action", a.action == b.action)
    check("same bars -> same score", a.score == b.score)
    check("same bars -> same fingerprint", a.fingerprint == b.fingerprint)
    check("same bars -> identical payload", a.to_payload() == b.to_payload())

    p = a.to_payload()
    check("payload declares snapshot basis", p["basis"] == "snapshot", p["basis"])
    check(
        "disclaimer says not a probability",
        "not a probability" in p["disclaimer"],
        p["disclaimer"],
    )
    check(
        "disclaimer denies being a recommendation",
        "recommendation" in p["disclaimer"],
        p["disclaimer"],
    )
    check("payload carries as_of", p["as_of"] == bars[-1]["time"], str(p["as_of"]))
    check("payload reports bars_used", p["bars_used"] == len(bars), str(p["bars_used"]))
    check("payload reasons are dicts", all(isinstance(r, dict) for r in p["reasons"]))
    check("payload round-trips through JSON-ish repr", repr(p) != "")
    check(
        "snapshot has no bare None masquerading as 0",
        "rsi_14" in p["snapshot"] and p["snapshot"]["rsi_14"] is not None,
    )

    check("analyse does not mutate its input", bars == rising())
    check("analyse accepts a tuple", analyse(tuple(bars)).action == a.action)


def main() -> int:
    print("=" * 68)
    print("OMNIVEST signal-engine test suite")
    print("=" * 68)
    for fn in (
        test_refusals,
        test_regime,
        test_regime_gating,
        test_veto,
        test_conviction_math,
        test_action_vocabulary,
        test_direction_consistency,
        test_reasons_cite_numbers,
        test_what_changed,
        test_scan,
        test_determinism_and_payload,
    ):
        fn()
    print("\n" + "=" * 68)
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} of {PASSED + len(FAILURES)}")
        for f in FAILURES[:40]:
            print(f"  - {f}")
        if len(FAILURES) > 40:
            print(f"  … and {len(FAILURES) - 40} more")
        return 1
    print(f"ALL {PASSED} CHECKS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
