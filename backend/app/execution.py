"""Execution forensics — did you lose money *filling* orders, not picking them?

Barber & Odean, "Trading Is Hazardous to Your Wealth" (JF 55(2), 2000) found that
the overwhelming majority of individual investor underperformance was attributable
to aggressive orders, not to bad stock selection. The uncomfortable implication
for a product like this one: the user cannot self-report this. They do not know
whether the order they placed was impatient, because "impatient" is a property of
the fill relative to the market at that instant, not of their intent.

So this module never asks. It classifies execution from the fill itself.

WHAT IS MEASURED HERE vs WHAT IS MODELLED
    measured : crossing cost in bps per fill, straight from your own fills and
               the reference price at decision time. No assumptions.
    modelled : what a passive fill would have cost. NOT observable from fill
               data alone — it depends on a fill probability you would have to
               assume. Therefore it is opt-in, parameterised, and always
               returned in a separate `countermodel` block that is explicitly
               labelled as a model.

Keep that boundary. The whole product thesis is that we would rather show you
less than show you a confident number we cannot defend.

REFERENCE
    Barber, Lee & Odean, "Trading Is Hazardous to Your Wealth", J. Finance 55(2),
    2000 — aggressive orders account for the bulk of measured losses.
    Barber & Odean, "The Behavior of Individual Investors", RFS 15(2), 2002.
"""

from __future__ import annotations

from dataclasses import dataclass, field

# How much extra you must pay, versus the mid, before we call the order
# maximally impatient. Beyond this a "limit" order is a market order in all but
# name — you paid whatever the book demanded.
IMPATIENCE_CEILING_BPS = 25.0

# Average daily order count for a fairly active retail account. Only used to
# annualise a cost figure when the caller does not tell us the period. Anything
# here is an assumption and is reported as one.
ASSUMED_ORDERS_PER_YEAR = 250.0

VERDICT_AGGRESSIVE = "AGGRESSIVE"
VERDICT_NEUTRAL = "NEUTRAL"
VERDICT_PASSIVE = "PASSIVE"


def _side_sign(side: str) -> int:
    """+1 for a buy (you lift the offer, cost pushes the price up), -1 for a sell."""
    return 1 if str(side).strip().lower() in {"buy", "b", "long"} else -1


def _nonneg(x: float) -> float:
    return x if x > 0.0 else 0.0


@dataclass
class OrderVerdict:
    symbol: str
    verdict: str
    score: float  # 0 = maximally patient, 1 = maximally impatient
    cost_bps: float  # measured crossing cost vs the reference price
    basis: str  # what we compared against
    reason: str


@dataclass
class AuditResult:
    n_orders: int
    n_aggressive: int
    aggressive_share: float
    mean_cost_bps: float
    total_cost_bps: float
    annualised_drag_bps: float
    by_symbol: dict = field(default_factory=dict)


def classify_order(order: dict) -> OrderVerdict:
    """Classify one execution. Never raises on missing fields — it reports why.

    Recognised keys (all optional except symbol/side):
        symbol, side, order_type, tif, limit_price, fill_price,
        reference_price, bid, ask

    `reference_price` is the price you *decided* against — the mid, the
    previous close, or the VWAP. When `bid`/`ask` are both present the true mid
    is preferred, because a previous close is a stale anchor and will happily
    manufacture cost that never happened.
    """
    symbol = str(order.get("symbol", "?"))
    side = str(order.get("side", "buy"))
    sign = _side_sign(side)
    order_type = str(order.get("order_type", "limit")).strip().lower()

    bid, ask = order.get("bid"), order.get("ask")
    reference = order.get("reference_price")

    basis = "reference_price"
    mid: float | None = None
    if bid is not None and ask is not None and float(ask) > float(bid) > 0:
        mid = (float(bid) + float(ask)) / 2.0
        basis = "book mid at decision time"

    if mid is None and reference is not None and float(reference) > 0:
        mid = float(reference)
    if mid is None:
        # Nothing to measure against. Say so rather than guessing a cost of 0,
        # which would silently flatter the user.
        return OrderVerdict(
            symbol=symbol,
            verdict=VERDICT_NEUTRAL,
            score=0.0,
            cost_bps=0.0,
            basis="unavailable",
            reason=(
                "No reference price or book supplied, so crossing cost is "
                "unknowable from this fill alone. Not scored as passive — "
                "missing data is not evidence of patience."
            ),
        )

    fill = order.get("fill_price")
    if fill is None:
        # No fill means no realised cost. The *order* may still have been
        # aggressive (a marketable limit that never filled would have been
        # aggressive), which is exactly the behaviour worth surfacing.
        limit = order.get("limit_price")
        aggressive_unfilled = False
        if limit is not None and (
            (sign > 0 and bid is not None and float(limit) >= float(bid))
            or (sign < 0 and ask is not None and float(limit) <= float(ask))
        ):
            aggressive_unfilled = True
        return OrderVerdict(
            symbol=symbol,
            verdict=VERDICT_AGGRESSIVE if aggressive_unfilled else VERDICT_NEUTRAL,
            score=1.0 if aggressive_unfilled else 0.0,
            cost_bps=0.0,
            basis=basis,
            reason=(
                "Unfilled order priced through the book. It would have crossed; "
                "it simply never got there. This is the signature of a patient "
                "limit being cancelled in panic."
                if aggressive_unfilled
                else "Unfilled and not through the book — a patient order."
            ),
        )

    fill_px = float(fill)
    if mid <= 0:
        mid = fill_px

    # Cost is always positive: how much worse than the anchor did we get?
    cost_bps = _nonneg(sign * (fill_px - mid) / mid * 10_000.0)
    score = min(1.0, cost_bps / IMPATIENCE_CEILING_BPS)

    # An order type overrides the arithmetic when the arithmetic is unavailable
    # or contradicted.
    if order_type in {"market", "mkt", "marketable"}:
        return OrderVerdict(
            symbol=symbol,
            verdict=VERDICT_AGGRESSIVE,
            score=1.0,
            cost_bps=cost_bps,
            basis=basis,
            reason="Market order. You paid whatever the book asked. No discretion.",
        )

    limit = order.get("limit_price")
    marketable = False
    if limit is not None:
        if (sign > 0 and ask is not None and float(limit) >= float(ask)) or (
            sign < 0 and bid is not None and float(limit) <= float(bid)
        ):
            marketable = True

    if marketable and cost_bps < 1.0:
        # Priced through the book yet filled at the mid. Usually a price
        # improvement, but it still *behaved* like an aggressive order.
        return OrderVerdict(
            symbol=symbol,
            verdict=VERDICT_AGGRESSIVE,
            score=1.0,
            cost_bps=cost_bps,
            basis=basis,
            reason=(
                "Limit priced through the book (it was marketable). The fill "
                "happened to be near the mid, but the order had no patience "
                "built into it."
            ),
        )

    if score >= 0.6:
        verdict, reason = (
            VERDICT_AGGRESSIVE,
            (
                f"Paid {cost_bps:.1f} bps through the anchor — you took the "
                f"market's price, not the market's patience."
            ),
        )
    elif score >= 0.2:
        verdict, reason = (
            VERDICT_NEUTRAL,
            (
                f"Paid {cost_bps:.1f} bps through the anchor — mild urgency, "
                f"possibly a partial fill working against you."
            ),
        )
    else:
        verdict, reason = (
            VERDICT_PASSIVE,
            (
                f"Filled within {cost_bps:.1f} bps of the anchor — patient. This "
                f"is the order style that historically survives the costs."
            ),
        )

    return OrderVerdict(
        symbol=symbol,
        verdict=verdict,
        score=score,
        cost_bps=cost_bps,
        basis=basis,
        reason=reason,
    )


def passive_countermodel(
    audits: list[OrderVerdict],
    fill_probability: float = 0.30,
) -> dict:
    """What a passive book would have cost. A MODEL, clearly labelled as one.

    Two facts, and only two:
      1. A passive limit resting at the anchor pays no crossing cost, so the
         measured realised crossing cost would fall to roughly zero.
      2. It would have filled only with probability `fill_probability`. The
         remaining (1-p) of those trades would not have happened at all.

    So the crossing cost avoided is the full measured cost -- but it is not free
    money. It is bought with the trades you would not have made, and whether
    those missing trades would have won or lost is unknowable from fill data.
    This function refuses to net that out, because netting it needs exactly the
    return data we are trying to teach the user not to fabricate.
    """
    if not 0.0 < fill_probability <= 1.0:
        raise ValueError("fill_probability must be in (0, 1]")

    aggressive = [a for a in audits if a.verdict == VERDICT_AGGRESSIVE and a.cost_bps > 0]
    if not aggressive:
        return {
            "applicable": False,
            "reason": "No priced-aggressive fills in this sample.",
            "assumptions": {},
        }

    realised = sum(a.cost_bps for a in aggressive)
    n = len(aggressive)
    missed = n * (1.0 - fill_probability)

    return {
        "applicable": True,
        "measured_realised_cost_bps": round(realised, 2),
        "modelled_passive_crossing_bps": 0.0,
        "crossing_cost_avoided_bps": round(realised, 2),
        "n_aggressive": n,
        "trades_that_would_not_have_happened": round(missed, 1),
        "assumptions": {
            "fill_probability": fill_probability,
            "note": (
                "Passive limit assumed to rest at the anchor and fill at it, "
                "so zero crossing cost. No optimistic fill-price improvement is "
                "credited, because that depends on a queue position you cannot "
                "observe from your own fills."
            ),
        },
        "caveat": (
            "A model, not a measurement. The cost avoided is real; the trades "
            "you would have missed are not netted out, because whether they "
            "would have won is unknowable. Read this as an upper bound on what "
            "impatience cost you -- never as a return you forgone."
        ),
    }


def audit_orders(
    orders: list[dict],
    portfolio_value: float | None = None,
    orders_per_year: float | None = None,
    fill_probability: float = 0.30,
) -> dict:
    """Full execution audit across a set of fills.

    `portfolio_value` turns the annualised bps drag into rupees, because bps
    alone do not make anybody feel anything.
    """
    if not orders:
        return {
            "n_orders": 0,
            "verdict": "NOTHING TO AUDIT",
            "narrative": "No executions supplied. Nothing to be learned from.",
        }

    audits = [classify_order(o) for o in orders]
    priced = [a for a in audits if a.cost_bps > 0]
    aggressive = [a for a in audits if a.verdict == VERDICT_AGGRESSIVE]
    passive = [a for a in audits if a.verdict == VERDICT_PASSIVE]
    unmeasurable = [a for a in audits if a.basis == "unavailable"]

    total_cost = sum(a.cost_bps for a in priced)
    mean_cost = total_cost / len(priced) if priced else 0.0
    share = len(aggressive) / len(audits)

    # Annualise. Prefer the caller's real order count; otherwise fall back to
    # the assumption and label it as one.
    assumed = orders_per_year is None
    opy = ASSUMED_ORDERS_PER_YEAR if assumed else float(orders_per_year)
    annual_drag = mean_cost * opy

    by_symbol: dict[str, dict] = {}
    for a in audits:
        b = by_symbol.setdefault(a.symbol, {"n": 0, "aggressive": 0, "cost_bps": 0.0})
        b["n"] += 1
        if a.verdict == VERDICT_AGGRESSIVE:
            b["aggressive"] += 1
        b["cost_bps"] += a.cost_bps
    for b in by_symbol.values():
        b["cost_bps"] = round(b["cost_bps"], 2)

    rupees = None
    if portfolio_value:
        rupees = round(portfolio_value * annual_drag / 10_000.0, 0)

    if share >= 0.6:
        verdict = "IMPATIENT"
        narrative = (
            f"{share:.0%} of your executions were aggressive. This is the "
            f"single largest drag in the account, and it is not a stock-picking "
            f"problem — it is a filling problem."
        )
    elif share >= 0.3:
        verdict = "MIXED"
        narrative = (
            f"{share:.0%} aggressive. You know how to be patient; you just "
            f"don't do it when it costs something to wait."
        )
    else:
        verdict = "PATIENT"
        narrative = (
            f"Only {share:.0%} aggressive. Your execution is disciplined — "
            f"this is rarer than it should be, and it is the good news here."
        )

    return {
        "n_orders": len(audits),
        "n_priced": len(priced),
        "n_aggressive": len(aggressive),
        "n_passive": len(passive),
        "n_unmeasurable": len(unmeasurable),
        "aggressive_share": round(share, 4),
        "mean_cost_bps": round(mean_cost, 2),
        "total_cost_bps": round(total_cost, 2),
        "annualised_drag_bps": round(annual_drag, 1),
        "annualised_drag_rupees": rupees,
        "annualisation_assumed": assumed,
        "verdict": verdict,
        "narrative": narrative,
        "by_symbol": by_symbol,
        "orders": [
            {
                "symbol": a.symbol,
                "verdict": a.verdict,
                "score": round(a.score, 3),
                "cost_bps": round(a.cost_bps, 2),
                "basis": a.basis,
                "reason": a.reason,
            }
            for a in audits
        ],
        "countermodel": passive_countermodel(audits, fill_probability=fill_probability),
        "source": "Barber & Odean, J. Finance 55(2), 2000 — 'Trading Is Hazardous to Your Wealth'",
    }
