from __future__ import annotations
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field
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
from .forensics import autopsy, momentum_crash_risk, pbo_cscv
from .execution import audit_orders, classify_order
from .watchloop import RULES, RULE_LIST, detect, rules_digest

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


def _delete_entries_where(predicate) -> int:
    """Remove entries matching predicate. Returns how many went.

    A journal you cannot correct is not a journal. Every write path here needs a
    matching undo, or the first mistyped symbol becomes a permanent, trusted-
    looking record of something the user never did.
    """
    db = _load()
    before = len(db.get("entries", []))
    db["entries"] = [e for e in db.get("entries", []) if not predicate(e)]
    removed = before - len(db["entries"])
    if removed:
        _save(db)
    return removed


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
    # extra="forbid" is load-bearing, not pedantry. `why` is the thesis — the
    # whole reason the journal exists — and a frontend sending `note` or
    # `thesis` would otherwise be silently dropped, losing the user's written
    # reasoning with no error anywhere. A 422 is loud; a blank thesis is not.
    model_config = ConfigDict(extra="forbid")

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
    # extra="forbid" everywhere, for the reason on JournalEntry. A forensics
    # client that misspells `sharpe` gets a plausible REJECT verdict computed
    # from the defaults instead — which is worse than an error, because the
    # number looks real and the user cannot see that nothing they sent landed.
    model_config = ConfigDict(extra="forbid")

    text: str
    symbol: str = ""
    horizon_months: int = 12


class Rule(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: str


class ExtractReq(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = "Untitled"
    text: str


class BriefReq(BaseModel):
    model_config = ConfigDict(extra="forbid")

    events: list[dict] = []
    name: str = "Investor"


class AutopsyReq(BaseModel):
    """Everything the forensics engine needs, and nothing it has to guess.

    Defaults are deliberately set to a *typical retail factor* rather than a
    flattering one: most signals the app gets handed should not survive.

    Field names mirror `forensics.autopsy()` exactly. They are not synonyms
    chosen for taste: an API and its engine that call the same idea `name` and
    `technique` will eventually drift, and a drift in *this* endpoint produces
    a confident verdict about the wrong signal.
    """

    model_config = ConfigDict(extra="forbid")

    technique: str = "Momentum 12-1"
    sharpe_ratio: float = 0.68
    n_trials: int = 47
    # Observations behind the backtest. 3y of daily bars is the usual claim.
    n_obs: int = 756
    backtest_excess_bps: int = 309
    live_excess_bps: int = -150
    # Optional: if the backtest did not span many years, divide by 252.
    periods_per_year: int = 252
    skew: float = 0.0
    kurtosis: float = 3.0
    t_stat: float | None = None
    n_tests: int | None = None
    confidence_z: float = 3.0


class PboReq(BaseModel):
    """PBO needs the whole thing: N strategies x T periods of returns.

    This is deliberately not a summary-statistic endpoint. PBO is about how a
    *selection procedure* behaves across splits, which no single Sharpe
    number can tell you. If you only have a headline Sharpe, that is a DSR
    question, not a PBO question.
    """

    model_config = ConfigDict(extra="forbid")

    name: str = "screen"
    returns_matrix: list[list[float]]
    n_splits: int = 8
    periods_per_year: int = 252


class AskReq(BaseModel):
    model_config = ConfigDict(extra="forbid")

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


class WatchReq(BaseModel):
    """Everything the 12 rules are allowed to look at.

    Every field is optional. A rule that cannot see what it needs stays quiet
    rather than guessing -- outside-circle will not fire without a declared
    circle, and cost-drift will not fire without a portfolio size. Silent is
    the correct output when the evidence is absent.
    """

    model_config = ConfigDict(extra="forbid")

    events: list[dict] = []
    as_of: str | None = None
    journal: list[dict] = []
    notes: list[dict] = []
    circle: list[str] = []
    positions: list[dict] = []
    portfolio_invested: float | None = None
    costs_ytd: float | None = None

    def context(self) -> dict:
        return {
            "events": self.events,
            "as_of": self.as_of,
            "journal": self.journal,
            "notes": self.notes,
            "circle": self.circle,
            "positions": self.positions,
            "portfolio_invested": self.portfolio_invested,
            "costs_ytd": self.costs_ytd,
        }


@app.get("/api/watch/rules")
def rules():
    # Driven by the same registry detect() runs, so the documented list and
    # the executing list cannot drift apart.
    return {
        "count": len(RULES),
        "items": RULES,
        "implemented": len(RULE_LIST),
        "note": "Every rule listed here has a live implementation. "
        "'implemented' is asserted equal to 'count' by the test suite.",
    }


@app.post("/api/watch/detect")
def watch_detect(req: WatchReq):
    fired = detect(req.context())
    return {
        "fired": fired,
        "n_fired": len(fired),
        "rules_registered": len(RULE_LIST),
        "rules_that_fired": sorted({f["rule"] for f in fired}),
        "errors": [f for f in fired if f.get("rule_error")],
    }


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


@app.delete("/api/journal/entries/{index}")
def delete_entry(index: int):
    """Delete one entry by index. Indices are positions in the current listing,
    so the client should re-read after deleting."""
    db = _load()
    entries = db.get("entries", [])
    if not 0 <= index < len(entries):
        raise HTTPException(status_code=404, detail=f"no entry at index {index}")
    removed = entries.pop(index)
    _save(db)
    return {"ok": True, "deleted": removed, "total": len(entries)}


@app.delete("/api/journal/entries")
def clear_entries():
    """Wipe the trade log. Deliberately separate from delete-one: this is the
    'start over' action and should never be one mis-tap from an entry."""
    db = _load()
    removed = len(db.get("entries", []))
    db["entries"] = []
    _save(db)
    return {"ok": True, "deleted": removed}


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
        req.technique,
        sharpe_ratio=req.sharpe_ratio,
        n_trials=req.n_trials,
        n_obs=req.n_obs,
        backtest_excess_bps=req.backtest_excess_bps,
        live_excess_bps=req.live_excess_bps,
        skew=req.skew,
        kurt=req.kurtosis,
        t_stat=req.t_stat,
        n_tests=req.n_tests,
    )


@app.post("/api/forensics/pbo")
def forensics_pbo(req: PboReq):
    """Probability of Backtest Overfitting via CSCV (Bailey et al. 2017).

    Single-draw PBO is materially noisy: the C(S, S/2) splits share subperiods,
    so treat the number as a signal, not a measurement. Re-run across
    different split points before believing it.
    """
    try:
        return pbo_cscv(
            req.returns_matrix,
            n_splits=req.n_splits,
            periods_per_year=req.periods_per_year,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.get("/api/forensics/crowding")
def forensics_crowding(
    comomentum: float = 0.2,
    vol_percentile: float = 0.2,
):
    """Momentum crash-risk overlay (Daniel & Moskowitz 2016; Lou & Polk 2022).

    Both inputs are percentiles in [0, 1]. Crowding and volatility are the two
    documented preconditions; both together is where the short leg explodes.
    """
    for name, value in (("comomentum", comomentum), ("vol_percentile", vol_percentile)):
        if not 0.0 <= value <= 1.0:
            raise HTTPException(
                status_code=422,
                detail=f"{name} must be a percentile in [0, 1], got {value}",
            )
    return momentum_crash_risk(comomentum, vol_percentile)


@app.get("/api/forensics/cite")
def forensics_cite():
    """The papers these numbers come from. Shipped with the app on purpose —
    a forensics product that hides its sources is just an oracle."""
    return {
        "E[max Sharpe under null]": {
            "claim": "sharpe_frontier()",
            "source": "Bailey & Lopez de Prado, 'The Sharpe Ratio Efficient "
            "Frontier', Journal of Risk 15(2), 2012",
        },
        "PSR / DSR": {
            "claim": "psr() / deflated_sharpe()",
            "source": "Bailey & Lopez de Prado, 'The Deflated Sharpe Ratio', "
            "Journal of Portfolio Management 40(5):94-107, 2014",
        },
        "PBO via CSCV": {
            "claim": "pbo_cscv()",
            "source": "Bailey, Borwein, Lopez de Prado & Zhu, 'The "
            "Probability of Backtest Overfitting', J. Computational Finance "
            "20(4):39-69, 2017",
        },
        "FDR / multiple testing": {
            "claim": "fdr_adjusted_pvalue()",
            "source": "Harvey, Liu & Zhu, '...and the Cross-Section of "
            "Expected Returns', RFS 29(1), 2016 (t>3.0 hurdle); Harvey & "
            "Liu, 'False (and Missed) Discoveries in Financial Economics', "
            "Journal of Finance 75(5), 2020 (FDR calibration). NOTE: this "
            "implementation is a Bonferroni normal approximation, not the "
            "paper's double bootstrap. Screening use only.",
        },
        "post-publication decay": {
            "claim": "autopsy().decay",
            "source": "McLean & Pontiff, 'Does Academic Research Destroy "
            "Stock Return Predictability?', Journal of Finance 71(1), 2016 "
            "-- 26% out-of-sample, 58% post-publication",
        },
        "momentum crash risk": {
            "claim": "momentum_crash_risk()",
            "source": "Daniel & Moskowitz, 'Momentum Crashes', JFE "
            "122(2), 2016; Lou & Polk, 'Comomentum', Journal of Finance "
            "77(1), 2022",
        },
        "disclaimer": "Implementation, not a legal or investment opinion. "
        "Every number is reproducible from the inputs.",
    }


# ---------- execution forensics ----------
# Barber & Odean put the bulk of retail underperformance on order handling, not
# stock picking. The journal's `aggressive` flag is a self-report, and nobody can
# self-assess this -- so it is derived from the fills instead.


class ExecutionReq(BaseModel):
    """A set of executions. Every field is optional except symbol and side,
    because a real broker export will have some of them and not others.

    What we do NOT do is default a missing reference price to the fill price.
    That would report every order as cost-free, which is the one conclusion
    this endpoint must never reach.
    """

    model_config = ConfigDict(extra="forbid")

    orders: list[dict] = []
    portfolio_value: float | None = None
    orders_per_year: float | None = None
    fill_probability: float = 0.30


class ClassifyReq(BaseModel):
    model_config = ConfigDict(extra="forbid")

    order: dict


@app.post("/api/execution/audit")
def execution_audit(req: ExecutionReq):
    try:
        return audit_orders(
            req.orders,
            portfolio_value=req.portfolio_value,
            orders_per_year=req.orders_per_year,
            fill_probability=req.fill_probability,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.post("/api/execution/classify")
def execution_classify(req: ClassifyReq):
    v = classify_order(req.order)
    return {
        "symbol": v.symbol,
        "verdict": v.verdict,
        "score": round(v.score, 3),
        "cost_bps": round(v.cost_bps, 2),
        "basis": v.basis,
        "reason": v.reason,
    }


@app.get("/api/execution/cite")
def execution_cite():
    return {
        "why_this_exists": (
            "Barber & Odean found the bulk of individual investor losses were "
            "attributable to aggressive orders rather than bad stock picks. "
            "Most retail execution audits start and end at 'you traded a lot'. "
            "This one prices the impatience."
        ),
        "source": "Barber, Lee & Odean, 'Trading Is Hazardous to Your Wealth', "
        "J. Finance 55(2), 2000; 'The Behavior of Individual Investors', "
        "RFS 15(2), 2002",
        "measured": {
            "claim": "Crossing cost in bps per fill, from your own fills",
            "assumptions": "None beyond the reference price you supply",
        },
        "modelled": {
            "claim": "passive_countermodel() -- what a patient book would have cost",
            "assumptions": "Fill probability is a parameter you set, not an "
            "estimate we make. Trades that would not have filled are NOT "
            "netted out, because whether they would have won is unknowable.",
            "verdict": "Treat as an upper bound on the cost of impatience, "
            "never as a return you forgone.",
        },
        "what_we_refuse_to_say": [
            "A cost of zero for an order we could not measure. Missing data is "
            "not evidence of patience.",
            "A profit from trading less. That number requires return data you "
            "have not given us.",
        ],
        "disclaimer": "Execution analytics only. Not investment advice.",
    }


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
