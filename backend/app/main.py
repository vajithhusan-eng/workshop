from __future__ import annotations
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from datetime import datetime, timezone
import json, os

from .data_seed import (
    CONSENSUS_8,
    DEBATES,
    SEBI_FY26,
    STARTER_BOOKS,
    CHANNELS,
    TECHNIQUES,
)
from .guardrails import check_output, brief_disclaimer, ADVISER_MODE
from .forensics import autopsy
from .watchloop import RULES, detect

DB_PATH = os.path.join(os.path.dirname(__file__), "..", "omnivest_journal.json")


def _load():
    try:
        with open(DB_PATH) as f:
            return json.load(f)
    except Exception:
        return {"entries": [], "notes": [], "rules": []}


def _save(db):
    with open(DB_PATH, "w") as f:
        json.dump(db, f, indent=2)


app = FastAPI(
    title="OMNIVEST",
    version="0.1.0",
    description="Free knowledge + accountability terminal. Education + self-analytics + journal.",
)

app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)


# ---------- models ----------
class JournalEntry(BaseModel):
    symbol: str
    side: str = "buy"
    qty: float = 0
    price: float = 0
    tag: str = "value"
    why: str = ""
    invalidation: str = ""
    aggressive: bool = False
    ts: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


class Note(BaseModel):
    text: str
    symbol: str = ""
    horizon_months: int = 12


class Rule(BaseModel):
    text: str


class ExtractReq(BaseModel):
    title: str = "Untitled"
    text: str


class BriefReq(BaseModel):
    events: list[dict] = []
    name: str = "Investor"


class AutopsyReq(BaseModel):
    name: str = "Momentum 12-1"
    sharpe: float = 0.68
    trials: int = 47
    backtest_excess_bps: int = 309
    live_excess_bps: int = -150


class AskReq(BaseModel):
    question: str
    context: str = ""


# ---------- routes ----------
@app.get("/api/health")
def health():
    return {
        "ok": True,
        "app": "omnivest",
        "safe_mode": not ADVISER_MODE,
        "time": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/api/canon/consensus")
def consensus():
    return {"count": len(CONSENSUS_8), "items": CONSENSUS_8}


@app.get("/api/canon/debates")
def debates():
    return {"count": len(DEBATES), "items": DEBATES}


@app.get("/api/sebi/summary")
def sebi():
    return SEBI_FY26


@app.get("/api/books/starter")
def books():
    return {
        "count": len(STARTER_BOOKS),
        "items": STARTER_BOOKS,
        "note": "Only Reminiscences (1923) is PD in India. Everything else: lessons + page citation + purchase link. Never full text.",
    }


@app.get("/api/videos/channels")
def channels():
    return {
        "count": len(CHANNELS),
        "items": CHANNELS,
        "note": "Embed-only. Never scrape/rehost. Transcript via user paste or caption API.",
    }


@app.get("/api/techniques")
def techniques():
    return {"count": len(TECHNIQUES), "items": TECHNIQUES}


@app.get("/api/watch/rules")
def rules():
    return {"count": len(RULES), "items": RULES}


@app.post("/api/watch/detect")
def watch_detect(req: BriefReq):
    return {"fired": detect(req.events)}


# journal
@app.post("/api/journal/entries")
def add_entry(e: JournalEntry):
    db = _load()
    db["entries"].append(e.model_dump())
    _save(db)
    return {"ok": True, "total": len(db["entries"])}


@app.get("/api/journal/entries")
def list_entries():
    return _load()


@app.get("/api/journal/stats")
def stats():
    db = _load()
    es = db["entries"]
    if not es:
        return {"n": 0, "hint": "Log 3+ trades to unlock your Bias Report."}
    by_tag: dict[str, dict] = {}
    agg = sum(1 for e in es if e.get("aggressive"))
    for e in es:
        t = e.get("tag", "?")
        by_tag.setdefault(t, {"n": 0, "agg": 0})
        by_tag[t]["n"] += 1
        by_tag[t]["agg"] += 1 if e.get("aggressive") else 0
    return {
        "n": len(es),
        "aggressive_share": round(agg / max(len(es), 1), 2),
        "by_tag": by_tag,
        "barber_note": "Virtually all individual losses trace to aggressive orders (Barber et al. 2009). Your passive vs aggressive split is the mechanism.",
        "sebi_note": f"SEBI FY26: {SEBI_FY26['loss_rate']}% of Indian traders lost money. Compare yourself to the base rate, not to finfluencers.",
    }


@app.post("/api/notes")
def add_note(n: Note):
    db = _load()
    db["notes"].append({**n.model_dump(), "ts": datetime.now(timezone.utc).isoformat()})
    _save(db)
    return {"ok": True, "total": len(db["notes"])}


@app.post("/api/rules")
def add_rule(r: Rule):
    db = _load()
    db["rules"].append(r.model_dump())
    _save(db)
    return {"ok": True, "rules": db["rules"]}


# book extractor (heuristic, $0 — local LLM plugs in later)
@app.post("/api/books/extract")
def extract(req: ExtractReq):
    paras = [p.strip() for p in req.text.split("\n\n") if len(p.strip()) > 60][:10]
    lessons = [
        {
            "n": i + 1,
            "lesson": p[:220] + ("…" if len(p) > 220 else ""),
            "mistake_prevented": "Acting without writing an invalidation first.",
            "apply_now": "Attach this to one open position and one rule.",
            "page_cite": f"{req.title} — auto-extract #{i + 1} (verify against your copy)",
        }
        for i, p in enumerate(paras)
    ]
    if not lessons:
        lessons = [
            {
                "n": 1,
                "lesson": "Paste 2+ paragraphs to extract lessons.",
                "mistake_prevented": "—",
                "apply_now": "—",
                "page_cite": req.title,
            }
        ]
    return {
        "title": req.title,
        "lessons": lessons,
        "rights": "Extract only. Keep your lawful copy; we never store full text of non-PD books.",
    }


# morning brief (deterministic draft + guardrail)
@app.post("/api/brief/daily")
def brief(req: BriefReq):
    fired = detect(req.events)
    if not fired:
        text = f"Morning, {req.name}. Nothing fired overnight — silence is the product. Your rules stand; your journal waits."
    else:
        lines = [f"🌅 Morning, {req.name}. {len(fired)} signal(s) — facts first:"]
        for f in fired:
            lines.append(f"• [{f['rule']}] {f['note']}")
        lines += [
            "",
            "WHAT YOUR LIBRARY SAYS: 'Price is what you pay. Value is what you get.' — Ch.8, your copy.",
            "WHAT YOU DID LAST TIME: check /api/journal/stats before deciding.",
            "THE DISAGREEMENT: your 2023 note vs your book — which one wins today?",
            "WHAT YOU CAN DO: write your invalidation level down before you act.",
        ]
        text = "\n".join(lines)
    g = check_output(text, {})
    return {
        "brief": text + "\n\n—\n🔎 " + brief_disclaimer(),
        "fired": fired,
        "guardrail": g,
    }


# forensics
@app.post("/api/forensics/autopsy")
def forensics(req: AutopsyReq):
    return autopsy(
        req.name, req.sharpe, req.trials, req.backtest_excess_bps, req.live_excess_bps
    )


# ask (retrieval stub — library-first, never a trading call in safe mode)
@app.post("/api/ask")
def ask(req: AskReq):
    q = req.question.strip()
    answer = (
        f"Q: {q}\n\n1) WHAT CHANGED: pull live facts for your symbols (BYO key).\n"
        f"2) WHAT YOUR LIBRARY SAYS: circle of competence + margin of safety + your saved clips.\n"
        f"3) WHAT YOU DID LAST TIME: see /api/journal/stats.\n"
        f"4) THE DISAGREEMENT: Buffett vs Dalio on this exact question — pick a side, we grade in 12 months.\n"
        f"5) WHAT YOU CAN DO: write the invalidation, check your max-positions rule, wait 24h on FOMO tags."
    )
    g = check_output(answer, {})
    return {"answer": answer + "\n\n—\n🔎 " + brief_disclaimer(), "guardrail": g}
