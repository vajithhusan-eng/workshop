"""Watch loop — 12 deterministic rules. No LLM here. Ever."""

from __future__ import annotations

RULES = [
    {"id": "big-move-vs-sector", "desc": "moved >3% while sector flat (<0.8%)"},
    {"id": "break-50dma", "desc": "you hold this and it broke your 50-DMA"},
    {"id": "fund-holdings", "desc": "a fund you're in published new holdings"},
    {"id": "thesis-due", "desc": "your claim passed its horizon — grade it"},
    {"id": "outside-circle", "desc": "trade outside your stated circle of competence"},
    {"id": "rule-broken", "desc": "you broke one of your own written rules"},
    {"id": "earnings-soon", "desc": "results within 3 days on something you hold"},
    {"id": "cost-drift", "desc": "costs >8% of invested this year"},
    {"id": "fomo-clock", "desc": "unplanned trade open >4 weeks without review"},
    {"id": "drawdown-habit", "desc": "sold a tagged 'value' position past −10% before"},
    {"id": "options-heavy", "desc": ">5 option trades this month (you're in the 92%)"},
    {"id": "revisit-note", "desc": "a note you wrote 6/12/24 months ago came due"},
]


def detect(events: list[dict]) -> list[dict]:
    """events: [{symbol, move_pct, sector_move_pct, holding, ...}]. Pure python."""
    fired: list[dict] = []
    for e in events:
        sym = e.get("symbol", "?")
        mv, sm = float(e.get("move_pct", 0)), float(e.get("sector_move_pct", 0))
        if abs(mv) > 3 and abs(sm) < 0.8:
            fired.append(
                {
                    "rule": "big-move-vs-sector",
                    "symbol": sym,
                    "note": f"{sym} {mv:+.1f}% vs sector {sm:+.1f}% — idiosyncratic, not beta.",
                }
            )
        if e.get("holding") and e.get("broke_50dma"):
            fired.append(
                {
                    "rule": "break-50dma",
                    "symbol": sym,
                    "note": f"{sym} broke 50-DMA while you hold it.",
                }
            )
        if e.get("thesis_due"):
            fired.append(
                {
                    "rule": "thesis-due",
                    "symbol": sym,
                    "note": f"Your claim on {sym} passed its horizon — time to grade.",
                }
            )
        if e.get("outside_circle"):
            fired.append(
                {
                    "rule": "outside-circle",
                    "symbol": sym,
                    "note": f"{sym} is outside your stated circle — your rule, applied.",
                }
            )
    return fired
