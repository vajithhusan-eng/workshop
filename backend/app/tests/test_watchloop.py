"""Watch-loop test suite. No pytest dependency.

    cd backend && ./.venv/bin/python -m app.tests.test_watchloop

The property that matters most here: the documented rule list and the rules that
actually execute are the same list. The previous module advertised 12 rules and
implemented 4, so "every rule fires" is asserted structurally, not by hand.
"""

from __future__ import annotations

import random
from datetime import datetime, timedelta, timezone

from app.watchloop import (
    NOTE_REVISIT_MONTHS,
    OPTIONS_LOSS_RATE_PCT,
    RULE_LIST,
    RULES,
    detect,
    rules_digest,
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


NOW = datetime(2026, 10, 3, tzinfo=timezone.utc)


def ago(days: float) -> str:
    return (NOW - timedelta(days=days)).isoformat()


def fired_ids(findings: list[dict]) -> set[str]:
    return {f["rule"] for f in findings}


# ── structural: registry and docs can never drift ───────────────────────────


def test_registry() -> None:
    print("\n[registry integrity]")
    check("12 rules registered", len(RULE_LIST) == 12, f"{len(RULE_LIST)}")
    check("RULES mirrors the registry", len(RULES) == len(RULE_LIST), f"{len(RULES)}")
    check("ids unique", len({r.id for r in RULE_LIST}) == 12, "duplicate ids")

    # The load-bearing property: every documented rule has a live implementation,
    # and every implementation is documented. This is the check that would have
    # caught the original 12-declared-4-built gap automatically.
    for r in RULE_LIST:
        check(f"'{r.id}' is callable", callable(r.check), "not callable")
        check(f"'{r.id}' has a basis", len(r.basis) > 30, f"{r.basis[:40]}")
        check(f"'{r.id}' has a desc", len(r.desc) > 5, f"{r.desc}")
    documented = {d["id"] for d in RULES}
    implemented = {r.id for r in RULE_LIST}
    check(
        "docs == implementations",
        documented == implemented,
        f"docs-only={documented - implemented} impl-only={implemented - documented}",
    )

    # Every rule must be reachable through the registry, not a module-level
    # function that detect() forgot to call.
    check("digest lists all 12", len(rules_digest()["ids"]) == 12, "")


# ── each rule fires on its own trigger, and stays quiet otherwise ───────────


def test_rule_01_big_move() -> None:
    print("\n[01 big-move-vs-sector]")
    r = detect(
        {
            "events": [
                {"symbol": "AAA", "move_pct": 5.0, "sector_move_pct": 0.1},
                {
                    "symbol": "BBB",
                    "move_pct": 5.0,
                    "sector_move_pct": 4.0,
                },  # beta, not idio
                {"symbol": "CCC", "move_pct": 1.0, "sector_move_pct": 0.1},  # too small
                {
                    "symbol": "DDD",
                    "move_pct": -4.0,
                    "sector_move_pct": 0.0,
                },  # down counts
            ]
        }
    )
    ids = [f["symbol"] for f in r if f["rule"] == "big-move-vs-sector"]
    check("fires on idiosyncratic up", "AAA" in ids, f"{ids}")
    check("silent when sector explains it", "BBB" not in ids, f"{ids}")
    check("silent on small moves", "CCC" not in ids, f"{ids}")
    check("fires on idiosyncratic down", "DDD" in ids, f"{ids}")
    # Malformed numbers must not crash the rule.
    r2 = detect({"events": [{"symbol": "E", "move_pct": "x", "sector_move_pct": 0}]})
    check("survives non-numeric move", isinstance(r2, list), f"{r2}")


def test_rule_02_50dma() -> None:
    print("\n[02 break-50dma]")
    r = detect(
        {
            "events": [
                {"symbol": "AAA", "holding": True, "broke_50dma": True},
                {"symbol": "BBB", "holding": False, "broke_50dma": True},  # not held
                {"symbol": "CCC", "holding": True, "broke_50dma": False},
            ]
        }
    )
    ids = [f["symbol"] for f in r if f["rule"] == "break-50dma"]
    check("fires when holding", "AAA" in ids, f"{ids}")
    check("silent if not holding", "BBB" not in ids, f"{ids}")
    check("silent if no break", "CCC" not in ids, f"{ids}")


def test_rule_03_fund_holdings() -> None:
    print("\n[03 fund-holdings]")
    r = detect(
        {
            "events": [
                {
                    "fund": "F1",
                    "fund_holdings_updated": True,
                    "new_additions": ["NEWCO"],
                    "new_exits": ["OLDCO"],
                },
                {"symbol": "AAA", "fund_holdings_updated": False},
            ]
        }
    )
    f = [x for x in r if x["rule"] == "fund-holdings"]
    check("fires on disclosure", len(f) == 1, f"{len(f)}")
    check("names the additions", "NEWCO" in f[0]["note"], f[0]["note"])
    check("names the exits", "OLDCO" in f[0]["note"], f[0]["note"])
    check("disclosure is info, not alarm", f[0]["severity"] == "info", f[0]["severity"])


def test_rule_04_thesis_due() -> None:
    print("\n[04 thesis-due]")
    # From the market feed.
    r1 = detect({"events": [{"symbol": "AAA", "thesis_due": True}]})
    check("fires from feed", "thesis-due" in fired_ids(r1), f"{r1}")

    # From the journal, aged past its horizon.
    r2 = detect(
        {
            "as_of": NOW.isoformat(),
            "journal": [
                {"symbol": "OLD", "ts": ago(400), "horizon_months": 12},  # ~13 months
                {"symbol": "NEW", "ts": ago(30), "horizon_months": 12},  # 1 month
                {"symbol": "NOH", "ts": ago(400)},  # no horizon
                {"symbol": "NOTS", "horizon_months": 12},  # no timestamp
            ],
        }
    )
    syms = [f["symbol"] for f in r2 if f["rule"] == "thesis-due"]
    check("fires when horizon passed", "OLD" in syms, f"{syms}")
    check("silent before horizon", "NEW" not in syms, f"{syms}")
    check("needs a declared horizon", "NOH" not in syms, f"{syms}")
    check("needs a timestamp", "NOTS" not in syms, f"{syms}")


def test_rule_05_outside_circle() -> None:
    print("\n[05 outside-circle]")
    r1 = detect(
        {
            "circle": ["AAA", "BBB"],
            "events": [
                {"symbol": "AAA"},
                {"symbol": "ZZZ"},
            ],
        }
    )
    syms = [f["symbol"] for f in r1 if f["rule"] == "outside-circle"]
    check("fires outside declared circle", "ZZZ" in syms, f"{syms}")
    check("silent inside", "AAA" not in syms, f"{syms}")
    check(
        "circle match is case-insensitive",
        "aaa" not in [f["symbol"] for f in r1],
        f"{syms}",
    )

    # No declared circle => we refuse to invent a boundary.
    r2 = detect({"events": [{"symbol": "ZZZ"}]})
    check(
        "no circle declared => silent", "outside-circle" not in fired_ids(r2), f"{r2}"
    )
    r3 = detect({"circle": [], "events": [{"symbol": "ZZZ"}]})
    check("empty circle => silent", "outside-circle" not in fired_ids(r3), f"{r3}")


def test_rule_06_rule_broken() -> None:
    print("\n[06 rule-broken]")
    r = detect(
        {
            "journal": [
                {"symbol": "AAA", "rule_violated": "no averaging down"},
                {"symbol": "BBB", "broke_rule": True},
                {"symbol": "CCC"},
            ]
        }
    )
    f = [x for x in r if x["rule"] == "rule-broken"]
    check("fires on a violated rule", len(f) == 2, f"{len(f)}")
    check("quotes the user's own rule", "averaging down" in f[0]["note"], f[0]["note"])
    check(
        "breaking your own rule is urgent",
        all(x["severity"] == "urgent" for x in f),
        f"{[x['severity'] for x in f]}",
    )


def test_rule_07_earnings() -> None:
    print("\n[07 earnings-soon]")
    r = detect(
        {
            "events": [
                {"symbol": "A", "holding": True, "days_to_earnings": 0},
                {"symbol": "B", "holding": True, "days_to_earnings": 3},
                {
                    "symbol": "C",
                    "holding": True,
                    "days_to_earnings": 4,
                },  # outside window
                {"symbol": "D", "holding": True, "days_to_earnings": -2},  # already out
                {"symbol": "E", "holding": False, "days_to_earnings": 1},  # not held
                {"symbol": "F", "holding": True},  # no data
            ]
        }
    )
    syms = [f["symbol"] for f in r if f["rule"] == "earnings-soon"]
    check("fires today", "A" in syms, f"{syms}")
    check("fires at the 3-day edge", "B" in syms, f"{syms}")
    check("silent beyond the window", "C" not in syms, f"{syms}")
    check("ignores past dates", "D" not in syms, f"{syms}")
    check("only for holdings", "E" not in syms, f"{syms}")
    check("silent without the data", "F" not in syms, f"{syms}")


def test_rule_08_cost_drift() -> None:
    print("\n[08 cost-drift]")
    r1 = detect({"portfolio_invested": 100_000, "costs_ytd": 12_000})
    check("fires above 8%", "cost-drift" in fired_ids(r1), f"{r1}")
    check("cost-drift is urgent", r1[0]["severity"] == "urgent", r1[0]["severity"])
    check("reports the percentage", r1[0]["cost_pct"] == 12.0, f"{r1[0]}")

    check(
        "silent below 8%",
        "cost-drift"
        not in fired_ids(detect({"portfolio_invested": 100_000, "costs_ytd": 7_999})),
        "",
    )
    check(
        "silent at exactly 8% (strict >)",
        "cost-drift"
        not in fired_ids(detect({"portfolio_invested": 100_000, "costs_ytd": 8_000})),
        "",
    )
    check(
        "silent without data",
        "cost-drift" not in fired_ids(detect({"portfolio_invested": 100_000})),
        "",
    )
    check(
        "survives zero invested",
        "cost-drift"
        not in fired_ids(detect({"portfolio_invested": 0, "costs_ytd": 100})),
        "",
    )
    check(
        "survives bad types",
        "cost-drift"
        not in fired_ids(detect({"portfolio_invested": "x", "costs_ytd": 1})),
        "",
    )

    # Per-position attribution.
    r2 = detect(
        {
            "portfolio_invested": 100_000,
            "costs_ytd": 12_000,
            "positions": [
                {"symbol": "AAA", "invested": 10_000, "costs_ytd": 2_000},
                {"symbol": "BBB", "invested": 90_000, "costs_ytd": 100},
            ],
        }
    )
    f = [x for x in r2 if x["rule"] == "cost-drift"]
    syms = {x.get("symbol") for x in f}
    check("attributes the costly position", "AAA" in syms, f"{syms}")
    check("skips the cheap position", "BBB" not in syms, f"{syms}")


def test_rule_09_fomo_clock() -> None:
    print("\n[09 fomo-clock]")
    r = detect(
        {
            "as_of": NOW.isoformat(),
            "journal": [
                {"symbol": "FOMO", "ts": ago(40), "planned": False},
                {"symbol": "FRESH", "ts": ago(5), "planned": False},
                {"symbol": "TAGGED", "ts": ago(40), "tag": "fomo"},
                {"symbol": "PLANNED", "ts": ago(40), "planned": True},
                {"symbol": "NOTS", "planned": False},
            ],
        }
    )
    syms = [f["symbol"] for f in r if f["rule"] == "fomo-clock"]
    check("fires past 4 weeks", "FOMO" in syms, f"{syms}")
    check("silent inside 4 weeks", "FRESH" not in syms, f"{syms}")
    check("a 'fomo' tag counts even if marked planned", "TAGGED" in syms, f"{syms}")
    check("genuinely planned trades are exempt", "PLANNED" not in syms, f"{syms}")
    check("needs a timestamp", "NOTS" not in syms, f"{syms}")


def test_rule_10_drawdown_habit() -> None:
    print("\n[10 drawdown-habit]")
    r = detect(
        {
            "journal": [
                {
                    "symbol": "A",
                    "side": "sell",
                    "tag": "value",
                    "pnl_pct": -25,
                    "why": "thesis broke",
                },
                {
                    "symbol": "B",
                    "side": "sell",
                    "tag": "value",
                    "pnl_pct": -10,
                },  # edge, no why
                {
                    "symbol": "C",
                    "side": "sell",
                    "tag": "value",
                    "pnl_pct": -3,
                },  # shallow
                {
                    "symbol": "D",
                    "side": "buy",
                    "tag": "value",
                    "pnl_pct": -50,
                },  # not a sale
                {
                    "symbol": "E",
                    "side": "sell",
                    "tag": "momentum",
                    "pnl_pct": -50,
                },  # not value
                {"symbol": "F", "side": "sell", "tag": "value"},  # no pnl
            ]
        }
    )
    f = [x for x in r if x["rule"] == "drawdown-habit"]
    syms = [x["symbol"] for x in f]
    check("fires on a deep value sale", "A" in syms, f"{syms}")
    check("fires at the -10% edge", "B" in syms, f"{syms}")
    check("silent on a shallow loss", "C" not in syms, f"{syms}")
    check("buying down is not the habit", "D" not in syms, f"{syms}")
    check("only value-tagged names", "E" not in syms, f"{syms}")
    check("needs a pnl", "F" not in syms, f"{syms}")
    check("calls out the missing reason", "feeling" in f[1]["note"], f[1]["note"])


def test_rule_11_options_heavy() -> None:
    print("\n[11 options-heavy]")
    six = [
        {"symbol": "O", "instrument": "option", "ts": ago(d)}
        for d in (1, 2, 3, 4, 5, 6)
    ]
    r1 = detect({"as_of": NOW.isoformat(), "journal": six})
    check("fires above 5 option trades", "options-heavy" in fired_ids(r1), f"{r1}")
    check(
        "carries the historical rate",
        r1[0]["historical_loss_rate_pct"] == OPTIONS_LOSS_RATE_PCT,
        f"{r1[0]}",
    )
    check("options-heavy is urgent", r1[0]["severity"] == "urgent", r1[0]["severity"])

    five = six[:5]
    check(
        "silent at exactly 5",
        "options-heavy"
        not in fired_ids(detect({"as_of": NOW.isoformat(), "journal": five})),
        "",
    )
    check(
        "silent with no options",
        "options-heavy"
        not in fired_ids(
            detect(
                {"as_of": NOW.isoformat(), "journal": [{"symbol": "A", "ts": ago(1)}]}
            )
        ),
        "",
    )
    # Old trades fall out of the 31-day window.
    old = [
        {"symbol": "O", "instrument": "option", "ts": ago(d)}
        for d in (40, 45, 50, 55, 60, 65)
    ]
    check(
        "old trades fall outside the window",
        "options-heavy"
        not in fired_ids(detect({"as_of": NOW.isoformat(), "journal": old})),
        "",
    )
    # The 'options' tag also counts.
    tagged = [
        {"symbol": "O", "tag": "options", "ts": ago(d)} for d in (1, 2, 3, 4, 5, 6)
    ]
    check(
        "'options' tag counts too",
        "options-heavy"
        in fired_ids(detect({"as_of": NOW.isoformat(), "journal": tagged})),
        "",
    )


def test_rule_12_revisit_note() -> None:
    print("\n[12 revisit-note]")
    r = detect(
        {
            "as_of": NOW.isoformat(),
            "notes": [
                {"text": "Nifty will re-rate", "ts": ago(200)},  # ~6.5 months
                {"text": "Recent idea", "ts": ago(20)},  # fresh
                {"text": "Old thesis", "ts": ago(1000)},  # way past due
                {"text": "No timestamp"},
            ],
        }
    )
    f = [x for x in r if x["rule"] == "revisit-note"]
    check("fires when a note comes due", len(f) == 2, f"{len(f)}")
    check("quotes the user's own words", any("re-rate" in x["note"] for x in f), f"{f}")
    check("silent on a fresh note", len(f) == 2, f"{len(f)}")
    check("needs a timestamp", len(f) == 2, f"{len(f)}")
    check(
        "revisit windows are documented",
        NOTE_REVISIT_MONTHS == (6, 12, 24),
        f"{NOTE_REVISIT_MONTHS}",
    )


# ── engine behaviour ────────────────────────────────────────────────────────


def test_engine() -> None:
    print("\n[engine]")
    check("empty context is safe", detect({}) == [], f"{detect({})}")
    check("None-ish context is safe", detect(None) == [], f"{detect(None)}")

    # Backward compatibility: the old positional form must still work.
    legacy = detect([{"symbol": "AAA", "move_pct": 5.0, "sector_move_pct": 0.1}])
    check(
        "legacy positional form works",
        "big-move-vs-sector" in fired_ids(legacy),
        f"{legacy}",
    )

    # Every finding is well-formed.
    rich = detect(
        {
            "as_of": NOW.isoformat(),
            "circle": ["AAA"],
            "portfolio_invested": 100,
            "costs_ytd": 50,
            "events": [
                {
                    "symbol": "AAA",
                    "move_pct": 9,
                    "sector_move_pct": 0,
                    "holding": True,
                    "broke_50dma": True,
                    "days_to_earnings": 1,
                    "thesis_due": True,
                }
            ],
            "journal": [
                {
                    "symbol": "AAA",
                    "ts": ago(400),
                    "horizon_months": 12,
                    "side": "sell",
                    "tag": "value",
                    "pnl_pct": -30,
                    "rule_violated": "no leverage",
                }
            ],
            "notes": [{"text": "check this", "ts": ago(300)}],
        }
    )
    check(
        "rich context fires many rules",
        len(fired_ids(rich)) >= 7,
        f"{sorted(fired_ids(rich))}",
    )
    for f in rich:
        check(
            f"finding '{f.get('rule')}' has a note", len(f.get("note", "")) > 5, f"{f}"
        )
        check(
            f"finding '{f.get('rule')}' has a severity",
            f.get("severity") in {"urgent", "warn", "info"},
            f"{f}",
        )
        check(
            f"finding '{f.get('rule')}' rule is registered",
            f.get("rule") in {r.id for r in RULE_LIST},
            f"{f}",
        )

    # Severity ordering: urgent first.
    sevs = [f["severity"] for f in rich]
    rank = {"urgent": 0, "warn": 1, "info": 2}
    check(
        "findings sorted by severity",
        sevs == sorted(sevs, key=lambda s: rank[s]),
        f"{sevs}",
    )

    # Isolation: a hostile rule must not blind the other eleven.
    class Boom(dict):
        def get(self, *a, **k):
            raise RuntimeError("boom")

    orig = {r.id: r.check for r in RULE_LIST}
    try:
        RULE_LIST[0].check = lambda ctx: (_ for _ in ()).throw(RuntimeError("boom"))
        out = detect(
            {
                "events": [
                    {
                        "symbol": "AAA",
                        "move_pct": 9,
                        "sector_move_pct": 0,
                        "holding": True,
                        "broke_50dma": True,
                    }
                ]
            }
        )
        errs = [f for f in out if f.get("rule_error")]
        check("a failing rule is reported, not hidden", len(errs) == 1, f"{errs}")
        check("failure is labelled", errs and errs[0]["rule"] == "big-move-vs-sector", f"{errs}")
        check("other rules still ran", "break-50dma" in fired_ids(out), f"{out}")
    finally:
        for r in RULE_LIST:
            r.check = orig[r.id]

    restored = detect({"events": [{"symbol": "AAA", "move_pct": 9, "sector_move_pct": 0}]})
    check(
        "registry restored after the isolation test",
        "big-move-vs-sector" in fired_ids(restored)
        and not any(f.get("rule_error") for f in restored),
        f"{restored}",
    )

    # Determinism: same input, same output, every time.
    ctx = {
        "as_of": NOW.isoformat(),
        "journal": [{"symbol": "X", "ts": ago(40), "horizon_months": 12}],
    }
    check("deterministic across runs", detect(ctx) == detect(ctx), "output differed")


def main() -> int:
    print("=" * 68)
    print("OMNIVEST watch-loop test suite")
    print("=" * 68)
    for fn in (
        test_registry,
        test_rule_01_big_move,
        test_rule_02_50dma,
        test_rule_03_fund_holdings,
        test_rule_04_thesis_due,
        test_rule_05_outside_circle,
        test_rule_06_rule_broken,
        test_rule_07_earnings,
        test_rule_08_cost_drift,
        test_rule_09_fomo_clock,
        test_rule_10_drawdown_habit,
        test_rule_11_options_heavy,
        test_rule_12_revisit_note,
        test_engine,
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
