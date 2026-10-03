"""Watch loop — 12 deterministic rules. No LLM here. Ever.

The whole product rests on a claim that the software does not flatter you. That
claim is only worth anything if the detection layer is boring, auditable and
reproducible: if a rule fires, you should be able to read the rule, read the
inputs, and get the same answer every time. A language model cannot promise
that, so nothing in this file calls one.

Design
------
Each rule is a pure function `ctx -> list[finding]`, registered in RULES with its
own threshold justification. Two consequences worth the effort:

  * `GET /api/watch/rules` and `POST /api/watch/detect` are driven by the same
    registry, so the documented rule list cannot drift from the rules that
    actually run. The previous version advertised 12 rules and implemented 4,
    which is precisely the kind of gap that makes a product untrustworthy.
  * Every threshold carries a `basis`. If we cannot say why the number is the
    number, we do not get to fire on it.

`detect` isolates failures. One rule raising on malformed input reports a
`rule_error` finding and the remaining eleven still run — a crash in the
thinnest rule must not blind the user to the other eleven.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Callable

# Thresholds. Every one of these is cited in the `basis` of the rule that uses
# it, and deliberately kept at module level so they can be argued with in one
# place rather than buried in eleven conditionals.
BIG_MOVE_PCT = 3.0  # idiosyncratic enough to be worth a look
FLAT_SECTOR_PCT = 0.8  # "flat" = the sector did not explain it
EARNINGS_WINDOW_DAYS = 3  # results close enough to matter this week
COST_DRIFT_PCT = 8.0  # all-in costs as a share of capital deployed
FOMO_CLOCK_DAYS = 28  # four weeks of an unreviewed impulsive position
DRAWDOWN_HABIT_PCT = -10.0  # selling a "value" name this far down, unexamined
OPTIONS_HEAVY_PER_MONTH = 5
NOTE_REVISIT_MONTHS = (6, 12, 24)

# SEBI's study of individual F&O participants found roughly 9 in 10 lose money.
# That figure is the reason this rule fires at all, so it travels with it.
OPTIONS_LOSS_RATE_PCT = 92


def _parse_dt(value) -> datetime | None:
    """Best-effort ISO-8601 parse. Returns tz-aware UTC, or None."""
    if value is None:
        return None
    if isinstance(value, datetime):
        dt = value
    else:
        text = str(value).strip()
        if not text:
            return None
        if text.endswith("Z"):
            text = text[:-1] + "+00:00"
        try:
            dt = datetime.fromisoformat(text)
        except ValueError:
            return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def _months_between(then: datetime, now: datetime) -> float:
    return (now - then).days / 30.4375


@dataclass
class Rule:
    id: str
    desc: str
    basis: str
    check: Callable[[dict], list[dict]]


def _f(rule_id: str, note: str, severity: str = "warn", **kw) -> dict:
    out = {"rule": rule_id, "note": note, "severity": severity}
    out.update(kw)
    return out


# ── 1. big-move-vs-sector ───────────────────────────────────────────────────


def _big_move(ctx: dict) -> list[dict]:
    fired = []
    for e in ctx.get("events", []):
        sym = e.get("symbol", "?")
        try:
            mv = float(e.get("move_pct", 0))
            sm = float(e.get("sector_move_pct", 0))
        except (TypeError, ValueError):
            continue
        if abs(mv) > BIG_MOVE_PCT and abs(sm) < FLAT_SECTOR_PCT:
            fired.append(
                _f(
                    "big-move-vs-sector",
                    f"{sym} {mv:+.1f}% while its sector moved {sm:+.1f}% — "
                    f"idiosyncratic, not beta. Something specific happened here.",
                    symbol=sym,
                )
            )
    return fired


# ── 2. break-50dma ──────────────────────────────────────────────────────────


def _break_50dma(ctx: dict) -> list[dict]:
    fired = []
    for e in ctx.get("events", []):
        if e.get("holding") and e.get("broke_50dma"):
            sym = e.get("symbol", "?")
            fired.append(
                _f(
                    "break-50dma",
                    f"{sym} broke its 50-DMA and you hold it. Your exit rule, "
                    f"if you have one, just triggered.",
                    symbol=sym,
                )
            )
    return fired


# ── 3. fund-holdings ────────────────────────────────────────────────────────


def _fund_holdings(ctx: dict) -> list[dict]:
    fired = []
    for e in ctx.get("events", []):
        if e.get("fund_holdings_updated"):
            sym = e.get("symbol") or e.get("fund") or "your fund"
            added = e.get("new_additions") or []
            dropped = e.get("new_exits") or []
            detail = []
            if added:
                detail.append(f"added {', '.join(map(str, added))}")
            if dropped:
                detail.append(f"dropped {', '.join(map(str, dropped))}")
            tail = (" (" + "; ".join(detail) + ")") if detail else ""
            fired.append(
                _f(
                    "fund-holdings",
                    f"{sym} published new holdings{tail}. Your money now holds "
                    f"things you have never read.",
                    symbol=sym,
                    severity="info",
                )
            )
    return fired


# ── 4. thesis-due ───────────────────────────────────────────────────────────


def _thesis_due(ctx: dict) -> list[dict]:
    now = _parse_dt(ctx.get("as_of")) or datetime.now(timezone.utc)
    fired = []
    for e in ctx.get("events", []):
        if e.get("thesis_due"):
            fired.append(
                _f(
                    "thesis-due",
                    f"Your claim on {e.get('symbol', '?')} passed its horizon. "
                    f"Grade it: right, wrong, or right for the wrong reason.",
                    symbol=e.get("symbol"),
                )
            )
    # The same rule, driven from the journal rather than the market feed.
    for j in ctx.get("journal", []):
        horizon = j.get("horizon_months")
        opened = _parse_dt(j.get("ts"))
        if not horizon or not opened:
            continue
        age = _months_between(opened, now)
        if age >= float(horizon):
            fired.append(
                _f(
                    "thesis-due",
                    f"{j.get('symbol', '?')}: {age:.0f} months old against a "
                    f"{horizon}-month thesis. Was the reasoning right, and does "
                    f"the reason still hold?",
                    symbol=j.get("symbol"),
                    age_months=round(age, 1),
                )
            )
    return fired


# ── 5. outside-circle ───────────────────────────────────────────────────────


def _outside_circle(ctx: dict) -> list[dict]:
    circle = {str(c).upper() for c in ctx.get("circle", [])}
    if not circle:
        # No declared circle means we cannot judge. Silence is the honest
        # output; inventing a boundary would be theatre.
        return []
    fired = []
    for e in ctx.get("events", []):
        sym = str(e.get("symbol", "")).upper()
        if sym and sym not in circle and e.get("outside_circle", True):
            fired.append(
                _f(
                    "outside-circle",
                    f"{e.get('symbol')} sits outside the circle you wrote down. "
                    f"You said you would not do this without knowing it.",
                    symbol=e.get("symbol"),
                )
            )
    return fired


# ── 6. rule-broken ──────────────────────────────────────────────────────────


def _rule_broken(ctx: dict) -> list[dict]:
    fired = []
    for j in ctx.get("journal", []):
        text = j.get("rule_violated") or j.get("broke_rule")
        if not text:
            continue
        fired.append(
            _f(
                "rule-broken",
                f"You wrote a rule and broke it: {text if isinstance(text, str) else ''}".strip(),
                symbol=j.get("symbol"),
                severity="urgent",
            )
        )
    return fired


# ── 7. earnings-soon ────────────────────────────────────────────────────────


def _earnings_soon(ctx: dict) -> list[dict]:
    fired = []
    for e in ctx.get("events", []):
        if not e.get("holding"):
            continue
        raw = e.get("days_to_earnings")
        if raw is None:
            continue
        try:
            days = float(raw)
        except (TypeError, ValueError):
            continue
        if 0 <= days <= EARNINGS_WINDOW_DAYS:
            when = "today" if days < 1 else f"in {days:.0f} day(s)"
            fired.append(
                _f(
                    "earnings-soon",
                    f"{e.get('symbol')} reports {when} and you hold it. Your thesis "
                    f"either survives that print or it never was a thesis.",
                    symbol=e.get("symbol"),
                    days_to_earnings=days,
                )
            )
    return fired


# ── 8. cost-drift ───────────────────────────────────────────────────────────


def _cost_drift(ctx: dict) -> list[dict]:
    invested = ctx.get("portfolio_invested")
    costs = ctx.get("costs_ytd")
    if invested is None or costs is None:
        return []
    try:
        invested = float(invested)
        costs = float(costs)
    except (TypeError, ValueError):
        return []
    if invested <= 0:
        return []
    pct = costs / invested * 100.0
    if pct > COST_DRIFT_PCT:
        fired = [
            _f(
                "cost-drift",
                f"Costs are {pct:.1f}% of capital deployed this year "
                f"({costs:,.0f} on {invested:,.0f}). Eight percent a year compounds "
                f"against you before any view is wrong.",
                severity="urgent",
                cost_pct=round(pct, 2),
            )
        ]
        # Per-position attribution, when the positions carry their own costs.
        for p in ctx.get("positions", []):
            inv = p.get("invested")
            pc = p.get("costs_ytd")
            if inv is None or pc is None:
                continue
            try:
                inv_f, pc_f = float(inv), float(pc)
            except (TypeError, ValueError):
                continue
            if inv_f <= 0:
                continue
            if pc_f / inv_f * 100.0 > COST_DRIFT_PCT:
                fired.append(
                    _f(
                        "cost-drift",
                        f"{p.get('symbol', '?')}: {pc_f / inv_f * 100:.1f}% of the "
                        f"position paid away in costs.",
                        symbol=p.get("symbol"),
                        cost_pct=round(pc_f / inv_f * 100.0, 2),
                    )
                )
        return fired
    return []


# ── 9. fomo-clock ───────────────────────────────────────────────────────────


def _fomo_clock(ctx: dict) -> list[dict]:
    now = _parse_dt(ctx.get("as_of")) or datetime.now(timezone.utc)
    fired = []
    for j in ctx.get("journal", []):
        opened = _parse_dt(j.get("ts"))
        if not opened:
            continue
        planned = j.get("planned", True)
        if planned is True and str(j.get("tag", "")).lower() != "fomo":
            continue
        age = (now - opened).days
        if age > FOMO_CLOCK_DAYS:
            fired.append(
                _f(
                    "fomo-clock",
                    f"{j.get('symbol', '?')} was opened {age} days ago without a "
                    f"plan and has not been reviewed once. Either write the thesis "
                    f"or close it.",
                    symbol=j.get("symbol"),
                    age_days=age,
                )
            )
    return fired


# ── 10. drawdown-habit ──────────────────────────────────────────────────────


def _drawdown_habit(ctx: dict) -> list[dict]:
    fired = []
    for j in ctx.get("journal", []):
        if str(j.get("tag", "")).lower() != "value":
            continue
        if str(j.get("side", "")).lower() not in {"sell", "s", "exit"}:
            continue
        raw = j.get("pnl_pct")
        if raw is None:
            continue
        try:
            pnl = float(raw)
        except (TypeError, ValueError):
            continue
        if pnl <= DRAWDOWN_HABIT_PCT:
            why = (j.get("why") or "").strip()
            unsound = not why
            fired.append(
                _f(
                    "drawdown-habit",
                    f"You sold {j.get('symbol', '?')} at {pnl:.1f}% after calling "
                    f"it value."
                    + (
                        " No reason was written, so this was a feeling."
                        if unsound
                        else " Check the reason still applies before you count it as discipline."
                    ),
                    symbol=j.get("symbol"),
                    pnl_pct=pnl,
                )
            )
    return fired


# ── 11. options-heavy ───────────────────────────────────────────────────────


def _options_heavy(ctx: dict) -> list[dict]:
    now = _parse_dt(ctx.get("as_of")) or datetime.now(timezone.utc)
    trades = [
        j
        for j in ctx.get("journal", [])
        if j.get("instrument") == "option" or str(j.get("tag", "")).lower() == "options"
    ]
    if not trades:
        return []
    dated = []
    for j in trades:
        t = _parse_dt(j.get("ts")) or now
        dated.append(t)
    # Anything older than 31 days is outside "this month" for our purposes.
    recent = [t for t in dated if (now - t).days <= 31]
    if len(recent) > OPTIONS_HEAVY_PER_MONTH:
        return [
            _f(
                "options-heavy",
                f"{len(recent)} option trades in the last 31 days. Around "
                f"{OPTIONS_LOSS_RATE_PCT}% of individual option traders lose money; "
                f"the more you trade, the less of it can be skill.",
                severity="urgent",
                count=len(recent),
                historical_loss_rate_pct=OPTIONS_LOSS_RATE_PCT,
            )
        ]
    return []


# ── 12. revisit-note ────────────────────────────────────────────────────────


def _revisit_note(ctx: dict) -> list[dict]:
    now = _parse_dt(ctx.get("as_of")) or datetime.now(timezone.utc)
    fired = []
    for n in ctx.get("notes", []):
        written = _parse_dt(n.get("ts"))
        if not written:
            continue
        age = _months_between(written, now)
        due = next((m for m in NOTE_REVISIT_MONTHS if age >= m), None)
        if due is None:
            continue
        text = (n.get("text") or "").strip()
        fired.append(
            _f(
                "revisit-note",
                f'{due} months ago you wrote: "{text[:140]}" — was that right?',
                symbol=n.get("symbol"),
                age_months=round(age, 1),
            )
        )
    return fired


# ── the registry ────────────────────────────────────────────────────────────

RULE_LIST: list[Rule] = [
    Rule(
        "big-move-vs-sector",
        "moved >3% while sector flat (<0.8%)",
        "Threshold is a screen, not a finding. It separates an idiosyncratic "
        "move from a sector move so the brief says something beyond 'the "
        "market went up'.",
        _big_move,
    ),
    Rule(
        "break-50dma",
        "you hold this and it broke your 50-DMA",
        "50-day is the conventional trend filter. We do not claim it predicts "
        "anything; we only claim your own exit rule fires here.",
        _break_50dma,
    ),
    Rule(
        "fund-holdings",
        "a fund you're in published new holdings",
        "Quarterly disclosure is the only moment you can see what you actually "
        "own. Outside it, you own a black box.",
        _fund_holdings,
    ),
    Rule(
        "thesis-due",
        "your claim passed its horizon — grade it",
        "Every journal entry carries a horizon. A thesis without an expiry is "
        "a feeling with a ticker attached.",
        _thesis_due,
    ),
    Rule(
        "outside-circle",
        "trade outside your stated circle of competence",
        "Fires only against a circle the user declared themselves. We refuse "
        "to guess a boundary on their behalf.",
        _outside_circle,
    ),
    Rule(
        "rule-broken",
        "you broke one of your own written rules",
        "The user's own rules, surfaced at the moment the journal contradicts "
        "them. Nothing here is our opinion.",
        _rule_broken,
    ),
    Rule(
        "earnings-soon",
        "results within 3 days on something you hold",
        "Three days is the window in which a 'long-term' holder is usually "
        "deciding on a short-term fact.",
        _earnings_soon,
    ),
    Rule(
        "cost-drift",
        "costs >8% of invested this year",
        "8% all-in per year is roughly the drag where fees alone can consume "
        "a decade of reasonable returns. Deliberately conservative.",
        _cost_drift,
    ),
    Rule(
        "fomo-clock",
        "unplanned trade open >4 weeks without review",
        "Four weeks is how long an unexamined position usually survives before "
        "it becomes a long-term holding by accident.",
        _fomo_clock,
    ),
    Rule(
        "drawdown-habit",
        "sold a tagged 'value' position past -10% before",
        "Catches the specific failure of abandoning a value label at the "
        "moment the value thesis was being tested.",
        _drawdown_habit,
    ),
    Rule(
        "options-heavy",
        ">5 option trades this month (you're in the 92%)",
        "SEBI's study of individual F&O participants found ~9 in 10 lose "
        "money; frequency is the part a user controls.",
        _options_heavy,
    ),
    Rule(
        "revisit-note",
        "a note you wrote 6/12/24 months ago came due",
        "Scheduled self-review. The value is in re-reading your own past "
        "reasoning, which is the only claim you have an honest record of.",
        _revisit_note,
    ),
]

# Kept as plain dicts because the API returns this verbatim and tests assert on it.
RULES = [{"id": r.id, "desc": r.desc, "basis": r.basis} for r in RULE_LIST]

_BY_ID = {r.id: r for r in RULE_LIST}


def detect(events: list[dict] | dict) -> list[dict]:
    """Run every rule. Accepts the old positional `events` form or a full ctx."""
    if isinstance(events, list):
        ctx: dict = {"events": events}
    elif isinstance(events, dict):
        ctx = events
    else:
        ctx = {}

    fired: list[dict] = []
    for rule in RULE_LIST:
        try:
            findings = rule.check(ctx)
        except Exception as exc:  # noqa: BLE001 - isolation is the point
            # Surface the failure rather than hiding it: a rule that silently
            # stops running is indistinguishable from a rule that never fires,
            # and the user would have no way to tell which.
            fired.append(
                _f(
                    rule.id,
                    f"Rule '{rule.id}' could not run: {type(exc).__name__}. "
                    f"Treated as no result, not as 'nothing to report'.",
                    severity="info",
                    rule_error=True,
                )
            )
            continue
        for finding in findings:
            finding.setdefault("rule", rule.id)
        fired.extend(findings)

    order = {"urgent": 0, "warn": 1, "info": 2}
    fired.sort(
        key=lambda f: (order.get(f.get("severity", "warn"), 1), f.get("rule", ""))
    )
    return fired


def rules_digest() -> dict:
    """Counts for the brief header: how many rules ran vs how many fired."""
    return {
        "rules_registered": len(RULE_LIST),
        "ids": [r.id for r in RULE_LIST],
    }
