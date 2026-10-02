"""Execution-forensics test suite. No pytest dependency.

    cd backend && ./.venv/bin/python -m app.tests.test_execution

The properties asserted here are the ones that decide whether a user can trust
the number. Two of them exist specifically to catch the failure mode that would
be most damaging: an unmeasured order quietly counted as a cheap one.
"""

from __future__ import annotations

import math

from app.execution import (
    IMPATIENCE_CEILING_BPS,
    VERDICT_AGGRESSIVE,
    VERDICT_NEUTRAL,
    VERDICT_PASSIVE,
    audit_orders,
    classify_order,
    passive_countermodel,
)

FAILURES: list[str] = []
PASSED = 0


def check(name: str, condition: bool, detail: str = "") -> None:
    global PASSED
    if condition:
        PASSED += 1
        print(f"  PASS  {name}")
    else:
        FAILURES.append(f"{name}: {detail}")
        print(f"  FAIL  {name}  {detail}")


def close(a: float, b: float, tol: float = 1e-6) -> bool:
    return abs(a - b) <= tol


def buy(fill, **kw):
    d = {
        "symbol": "TEST",
        "side": "buy",
        "order_type": "limit",
        "fill_price": fill,
        "reference_price": 100.0,
    }
    d.update(kw)
    return d


# ── classification ──────────────────────────────────────────────────────────


def test_classify() -> None:
    print("\n[order classification]")

    # --- market order is unconditionally aggressive --------------------
    m = classify_order(
        {
            "symbol": "A",
            "side": "buy",
            "order_type": "market",
            "fill_price": 100.5,
            "reference_price": 100.0,
        }
    )
    check("market order => AGGRESSIVE", m.verdict == VERDICT_AGGRESSIVE, m.verdict)
    check("market order => score 1.0", close(m.score, 1.0), f"{m.score}")
    check("market order cost = 50bps", close(m.cost_bps, 50.0, 1e-4), f"{m.cost_bps}")

    # --- filled at the anchor is patient ------------------------------
    p = classify_order(buy(100.0))
    check("fill at anchor => PASSIVE", p.verdict == VERDICT_PASSIVE, p.verdict)
    check("fill at anchor => 0 cost", close(p.cost_bps, 0.0), f"{p.cost_bps}")

    # --- buying above the anchor is impatient -------------------------
    a = classify_order(buy(100.4))
    check("40bps above => AGGRESSIVE", a.verdict == VERDICT_AGGRESSIVE, a.verdict)
    check("40bps above => cost 40", close(a.cost_bps, 40.0, 1e-4), f"{a.cost_bps}")

    # --- selling is the mirror image ----------------------------------
    s = classify_order(
        {
            "symbol": "A",
            "side": "sell",
            "order_type": "limit",
            "fill_price": 99.6,
            "reference_price": 100.0,
        }
    )
    check("sell below anchor => AGGRESSIVE", s.verdict == VERDICT_AGGRESSIVE, s.verdict)
    check(
        "sell below anchor => cost 40", close(s.cost_bps, 40.0, 1e-4), f"{s.cost_bps}"
    )

    # --- a better-than-expected fill is never a cost ------------------
    # Buying BELOW the anchor is a price improvement, not impatience.
    g = classify_order(buy(99.8))
    check("price improvement => 0 cost", close(g.cost_bps, 0.0), f"{g.cost_bps}")
    check("price improvement => PASSIVE", g.verdict == VERDICT_PASSIVE, g.verdict)

    # --- side must be honoured: cost is symmetric ---------------------
    up = classify_order(buy(100.4, symbol="UP"))
    down = classify_order(
        {
            "symbol": "DN",
            "side": "sell",
            "order_type": "limit",
            "fill_price": 99.6,
            "reference_price": 100.0,
        }
    )
    check(
        "buy/sell cost is symmetric",
        close(up.cost_bps, down.cost_bps, 1e-6),
        f"{up.cost_bps} vs {down.cost_bps}",
    )

    # --- book mid preferred over a stale reference --------------------
    # Reference says 100, but the real mid at the time was 101. The order
    # filled at 101 = exactly the mid = free. Using the stale reference would
    # have manufactured 100bps of phantom cost.
    m1 = classify_order(buy(101.0, bid=100.98, ask=101.02, reference_price=100.0))
    check(
        "book mid beats stale reference",
        close(m1.cost_bps, 0.0, 1e-3),
        f"{m1.cost_bps}",
    )
    check("basis reports the book", "mid" in m1.basis, m1.basis)

    # --- unmeasurable is NOT passive (the important one) ---------------
    u = classify_order(
        {"symbol": "U", "side": "buy", "order_type": "limit", "fill_price": 100.0}
    )
    check(
        "no reference => NEUTRAL, not PASSIVE", u.verdict == VERDICT_NEUTRAL, u.verdict
    )
    check("no reference => basis unavailable", u.basis == "unavailable", u.basis)
    check(
        "no reference => reason explains why",
        "not evidence of patience" in u.reason,
        u.reason,
    )

    # --- unfilled marketable limit ------------------------------------
    uf = classify_order(
        {
            "symbol": "F",
            "side": "buy",
            "order_type": "limit",
            "limit_price": 101.5,
            "bid": 100.0,
            "ask": 100.2,
        }
    )
    check(
        "unfilled through book => AGGRESSIVE",
        uf.verdict == VERDICT_AGGRESSIVE,
        uf.verdict,
    )
    check("unfilled through book => score 1.0", close(uf.score, 1.0), f"{uf.score}")

    uf2 = classify_order(
        {
            "symbol": "P",
            "side": "buy",
            "order_type": "limit",
            "limit_price": 99.0,
            "bid": 100.0,
            "ask": 100.2,
        }
    )
    check(
        "unfilled passive limit => NEUTRAL", uf2.verdict == VERDICT_NEUTRAL, uf2.verdict
    )

    # --- marketable limit that got a price improvement -----------------
    mi = classify_order(buy(100.1, limit_price=101.0, bid=100.0, ask=100.2))
    check(
        "marketable limit w/ good fill => AGGRESSIVE",
        mi.verdict == VERDICT_AGGRESSIVE,
        mi.verdict,
    )
    # mid = (100.0+100.2)/2 = 100.1 and it filled at 100.1, so the crossing
    # cost really is zero. The point is that we still call it AGGRESSIVE: the
    # order was priced through the book, so the cheap fill was luck, not
    # patience.
    check(
        "marketable limit at the mid costs 0",
        close(mi.cost_bps, 0.0, 1e-3),
        f"{mi.cost_bps}",
    )
    check(
        "cheap fill does not buy patience",
        mi.verdict == VERDICT_AGGRESSIVE,
        mi.verdict,
    )

    # --- score is bounded ----------------------------------------------
    huge = classify_order(buy(200.0))
    check("score never exceeds 1.0", close(huge.score, 1.0), f"{huge.score}")
    check("ceiling constant is positive", IMPATIENCE_CEILING_BPS > 0)

    # --- every verdict carries a reason --------------------------------
    for o in (buy(100.0), buy(100.4), buy(101.5, bid=100.0, ask=100.2)):
        check(
            f"reason present for {o.get('fill_price')}",
            len(classify_order(o).reason) > 20,
        )


# ── aggregate audit ─────────────────────────────────────────────────────────


def test_audit() -> None:
    print("\n[aggregate audit]")

    empty = audit_orders([])
    check("empty input is handled", empty["n_orders"] == 0, f"{empty}")

    # A realistic impatient account: most orders pay through the mid.
    orders = (
        [buy(100.5, symbol="AAA")] * 6
        + [buy(100.0, symbol="BBB")] * 3
        + [
            {
                "symbol": "CCC",
                "side": "buy",
                "order_type": "market",
                "fill_price": 100.6,
                "reference_price": 100.0,
            }
        ]
    )
    r = audit_orders(orders, portfolio_value=500_000, orders_per_year=250)

    check("counts all orders", r["n_orders"] == 10, f"{r['n_orders']}")
    check("impatient verdict", r["verdict"] == "IMPATIENT", r["verdict"])
    check(
        "aggressive share counted correctly",
        close(r["aggressive_share"], 0.7, 1e-9),
        f"{r['aggressive_share']} (expected 7/10)",
    )
    check("mean cost is real", r["mean_cost_bps"] > 0, f"{r['mean_cost_bps']}")
    check(
        "annualised drag computed",
        r["annualised_drag_bps"] > 0,
        f"{r['annualised_drag_bps']}",
    )
    check(
        "rupees computed",
        r["annualised_drag_rupees"] > 0,
        f"{r['annualised_drag_rupees']}",
    )
    check(
        "explicit orders_per_year is not flagged assumed",
        r["annualisation_assumed"] is False,
    )
    check(
        "by_symbol is per-symbol",
        set(r["by_symbol"]) == {"AAA", "BBB", "CCC"},
        f"{list(r['by_symbol'])}",
    )

    # A patient account reads the other way.
    calm = audit_orders([buy(100.0, symbol="P")] * 8 + [buy(99.99, symbol="P2")] * 2)
    check("patient verdict", calm["verdict"] == "PATIENT", calm["verdict"])
    check(
        "patient costs ~nothing",
        calm["mean_cost_bps"] < 1.0,
        f"{calm['mean_cost_bps']}",
    )

    # Assumption flag is honest when the caller gives no order count.
    check(
        "missing order count is flagged assumed",
        audit_orders([buy(100.4)])["annualisation_assumed"] is True,
    )

    # Unmeasurable orders must not be silently scored as passive.
    mixed = audit_orders(
        [
            buy(100.4, symbol="AGGR"),
            {"symbol": "UNKNOWN", "side": "buy", "fill_price": 100.0},
        ]
    )
    check(
        "unmeasurable counted",
        mixed["n_unmeasurable"] == 1,
        f"{mixed['n_unmeasurable']}",
    )
    check(
        "unmeasurable not called passive",
        mixed["n_passive"] == 0,
        f"{mixed['n_passive']}",
    )

    # Missing portfolio value must not fabricate rupees.
    check(
        "no portfolio => no rupees",
        audit_orders([buy(100.4)])["annualised_drag_rupees"] is None,
    )

    # Every order appears in the output with a reason.
    check("every order reported", len(r["orders"]) == len(orders))
    check("orders carry reasons", all(o["reason"] for o in r["orders"]))


# ── countermodel ────────────────────────────────────────────────────────────


def test_countermodel() -> None:
    print("\n[passive countermodel]")

    audits = [classify_order(buy(100.5)) for _ in range(4)]
    cm = passive_countermodel(audits, fill_probability=0.25)

    check("countermodel applies", cm["applicable"] is True, f"{cm}")
    check(
        "measured cost is real",
        close(cm["measured_realised_cost_bps"], 200.0, 0.01),
        f"{cm['measured_realised_cost_bps']}",
    )
    check(
        "passive crossing is ~0",
        close(cm["modelled_passive_crossing_bps"], 0.0),
        f"{cm['modelled_passive_crossing_bps']}",
    )
    check(
        "missed trades counted",
        close(cm["trades_that_would_not_have_happened"], 3.0),
        f"{cm['trades_that_would_not_have_happened']}",
    )
    check("assumption is disclosed", "fill_probability" in cm["assumptions"])
    check("caveat present", len(cm["caveat"]) > 40)
    check("modelled cost is never negative", cm["modelled_passive_crossing_bps"] >= 0)

    # No aggressive fills => not applicable, not a zero-cost triumph.
    calm = passive_countermodel([classify_order(buy(100.0))])
    check("no aggression => not applicable", calm["applicable"] is False, f"{calm}")

    # Guard the probability parameter.
    for bad in (0.0, -0.1, 1.5):
        try:
            passive_countermodel(audits, fill_probability=bad)
            check(f"rejects fill_probability={bad}", False, "no exception")
        except ValueError:
            check(f"rejects fill_probability={bad}", True)

    check("p=1.0 is allowed", passive_countermodel(audits, 1.0)["applicable"] is True)


def main() -> int:
    print("=" * 68)
    print("OMNIVEST execution-forensics test suite")
    print("=" * 68)
    for fn in (test_classify, test_audit, test_countermodel):
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
