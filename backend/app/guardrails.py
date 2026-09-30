"""Guardrails — SAFE mode default (education + self-analytics).
ADVISER_MODE=false → block trading calls, ratings, targets, rankings.
Set OMNIVEST_ADVISER_MODE=1 only behind a SEBI-registered IA/RA partner.
"""

from __future__ import annotations
import os
import re

ADVISER_MODE = os.getenv("OMNIVEST_ADVISER_MODE", "0") == "1"

BLOCKED_PATTERNS = [
    r"\bguaranteed\b",
    r"\bsure thing\b",
    r"\bcan't lose\b",
    r"\b100%\s*certain\b",
    r"\bshould buy\b",
    r"\bshould sell\b",
    r"\bmust buy\b",
    r"\bmust sell\b",
]

PRICE_RE = re.compile(r"₹?\s?\d[\d,]*\.?\d*")


def check_output(text: str, facts: dict) -> dict:
    """Post-generation guardrail. Returns {ok, violations[]}."""
    violations: list[str] = []
    low = text.lower()
    for pat in BLOCKED_PATTERNS:
        if re.search(pat, low):
            violations.append(f"blocked-phrase:{pat}")
    if not ADVISER_MODE:
        # In safe mode, any standalone BUY/SELL/HOLD rating line is a violation
        if re.search(r"^\s*(rating\s*:\s*)?(buy|sell|hold|accumulate)\b", low, re.M):
            violations.append("trading-call: ratings disabled in SAFE mode")
        if re.search(r"target\s*(price)?\s*[:=]\s*₹?\s?\d", low):
            violations.append("price-target: disabled in SAFE mode")
    return {
        "ok": not violations,
        "violations": violations,
        "adviser_mode": ADVISER_MODE,
    }


def brief_disclaimer() -> str:
    return (
        "AI-generated from your own library. Data as of briefing time. Not investment advice."
        + (
            ""
            if not ADVISER_MODE
            else " Published under SEBI-registered partner; rating carries horizon, never a date-of-action."
        )
    )
