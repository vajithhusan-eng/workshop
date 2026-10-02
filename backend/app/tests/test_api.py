"""End-to-end API smoke test. Exercises every route against a live server.

    cd backend && ./.venv/bin/python run.py &          # in one shell
    ./.venv/bin/python -m app.tests.test_api            # in another

Two things this buys over testing functions directly:

  1. It catches wiring bugs — a route that calls a renamed kwarg raises a 500
     that no unit test will ever see. That exact class of bug cost real time
     during the forensics rewrite.
  2. It pins the contract the Flutter frontend depends on, so a silent schema
     change shows up here instead of as a null-deref in the UI.

No pytest: same reason the forensics suite has none.
"""

from __future__ import annotations

import json
import random
import sys
import urllib.error
import urllib.request

BASE = "http://127.0.0.1:8123"

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


def call(method: str, path: str, payload: dict | None = None) -> tuple[int, object]:
    """Returns (status, parsed_body). Never raises on HTTP error."""
    url = BASE + path
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    if data is not None:
        req.add_header("content-type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return resp.status, json.loads(resp.read() or b"null")
    except urllib.error.HTTPError as exc:
        body = exc.read()
        try:
            return exc.code, json.loads(body or b"null")
        except json.JSONDecodeError:
            return exc.code, body.decode(errors="replace")
    except urllib.error.URLError as exc:
        return 0, f"cannot reach {url}: {exc.reason}"


# ─────────────────────────────────────────────────────────────────────────────


def test_reachable() -> None:
    print("\n[server reachable]")
    status, body = call("GET", "/api/health")
    if status == 0:
        print(f"  FATAL  {body}")
        print("\n  Start the server first: cd backend && ./.venv/bin/python run.py")
        raise SystemExit(2)
    check("health 200", status == 200, f"{status}")
    check("health ok", isinstance(body, dict) and body.get("ok") is True, f"{body}")
    check("health reports safe_mode", "safe_mode" in body, f"{body}")


def test_forensics_api() -> None:
    print("\n[forensics — autopsy]")
    status, body = call(
        "POST",
        "/api/forensics/autopsy",
        {
            "name": "Typical Retail Factor",
            "sharpe": 0.9,
            "trials": 200,
            "n_obs": 756,
            "backtest_excess_bps": 800,
            "live_excess_bps": 700,
        },
    )
    check("autopsy 200", status == 200, f"{status} {str(body)[:200]}")
    if status != 200:
        return
    check("autopsy rejects an overfit claim", body["severity"] == "high", f"{body}")
    check("verdict is a string", isinstance(body["verdict"], str) and body["verdict"])
    check("decay block present", "decay" in body, f"{list(body)}")
    check("dsr in [0,1]", 0.0 <= body["deflated_sharpe"]["dsr"] <= 1.0, f"{body}")
    check("minbtl present", "observations_needed" in body["min_backtest_length"])
    check("red/amber counts", "red_flags" in body, f"{list(body)}")

    # fat tails must lower confidence over the wire, not just in-process
    _, thin = call(
        "POST",
        "/api/forensics/autopsy",
        {
            "name": "T",
            "sharpe": 1.0,
            "trials": 10,
            "n_obs": 1000,
            "backtest_excess_bps": 500,
            "live_excess_bps": 480,
            "kurtosis": 3.0,
        },
    )
    _, fat = call(
        "POST",
        "/api/forensics/autopsy",
        {
            "name": "T",
            "sharpe": 1.0,
            "trials": 10,
            "n_obs": 1000,
            "backtest_excess_bps": 500,
            "live_excess_bps": 480,
            "kurtosis": 12.0,
            "skew": -1.5,
        },
    )
    check(
        "kurtosis crosses the wire",
        fat["deflated_sharpe"]["dsr"] < thin["deflated_sharpe"]["dsr"],
        f"thin {thin['deflated_sharpe']['dsr']} vs fat {fat['deflated_sharpe']['dsr']}",
    )

    # defaults must not explode — this is what the frontend sends on a cold load
    status, body = call("POST", "/api/forensics/autopsy", {})
    check(
        "autopsy works with bare defaults", status == 200, f"{status} {str(body)[:160]}"
    )


def test_pbo_api() -> None:
    print("\n[forensics — pbo]")
    rng = random.Random(4242)
    noise = [
        [round(rng.gauss(0.0004, 0.015), 6) for _ in range(480)] for _ in range(20)
    ]
    status, body = call(
        "POST", "/api/forensics/pbo", {"returns_matrix": noise, "n_splits": 8}
    )
    check("pbo 200", status == 200, f"{status} {str(body)[:200]}")
    if status != 200:
        return
    check("pbo in [0,1]", 0.0 <= body["pbo"] <= 1.0, f"{body}")
    check("pbo reports 70 combos", body["n_combos"] == 70, f"{body}")
    check("pbo interprets the number", "interpretation" in body, f"{list(body)}")
    check(
        "pure noise reads as overfit",
        body["pbo"] > 0.5,
        f"expected >0.5 on noise, got {body['pbo']}",
    )

    # bad input must be a 422 with a message, never a 500
    for payload, why in (
        ({"returns_matrix": [[0.01, 0.02]]}, "one strategy"),
        ({"returns_matrix": noise, "n_splits": 7}, "odd splits"),
        (
            {"returns_matrix": [[0.01] * 4, [0.02] * 4], "n_splits": 8},
            "too few periods",
        ),
    ):
        status, body = call("POST", "/api/forensics/pbo", payload)
        check(f"422 for {why}", status == 422, f"got {status}: {str(body)[:120]}")
        check(
            f"422 explains {why}",
            isinstance(body, dict) and "detail" in body,
            f"{str(body)[:120]}",
        )


def test_crowding_api() -> None:
    print("\n[forensics — crowding]")
    status, body = call(
        "GET", "/api/forensics/crowding?comomentum=0.15&vol_percentile=0.2"
    )
    check("calm crowding 200", status == 200, f"{status} {str(body)[:160]}")
    if status == 200:
        check("calm => NORMAL", body["risk_level"] == "NORMAL", f"{body}")

    status, body = call(
        "GET", "/api/forensics/crowding?comomentum=0.92&vol_percentile=0.88"
    )
    check("hot crowding 200", status == 200, f"{status} {str(body)[:160]}")
    if status == 200:
        check("hot => SEVERE", body["risk_level"] == "SEVERE", f"{body}")

    status, body = call("GET", "/api/forensics/crowding?comomentum=1.4")
    check("out-of-range percentile rejected", status == 422, f"got {status}")


def test_citations() -> None:
    print("\n[forensics — citations]")
    status, body = call("GET", "/api/forensics/cite")
    check("cite 200", status == 200, f"{status}")
    if status != 200:
        return
    check("cites every engine", len(body) >= 7, f"{list(body)}")
    check(
        "every entry names a source",
        all("source" in v for k, v in body.items() if isinstance(v, dict)),
        f"{list(body)}",
    )
    check("carries a disclaimer", "disclaimer" in body, f"{list(body)}")


def test_content_endpoints() -> None:
    print("\n[content + journal]")
    for path, keys in (
        ("/api/sebi/summary", None),
        ("/api/canon/consensus", None),
        ("/api/canon/debates", None),
        ("/api/techniques", None),
        ("/api/videos/channels", None),
        ("/api/watch/rules", None),
        ("/api/books/starter", None),
        ("/api/journal/entries", None),
        ("/api/journal/stats", None),
    ):
        status, body = call("GET", path)
        check(f"GET {path}", status == 200, f"{status} {str(body)[:120]}")
        if status == 200 and keys:
            check(f"{path} has {keys}", keys in body, f"{list(body)[:10]}")


def test_write_paths() -> None:
    print("\n[write paths - journal round-trip]")
    marker = "smoke-test-marker-omnivest"
    payload = {
        "symbol": "OMNITEST",
        "side": "buy",
        "price": 100.0,
        "why": "wiring check",
        "invalidation": "close below 90",
        "tag": marker,
    }
    status, body = call("POST", "/api/journal/entries", payload)
    check("create entry 200", status == 200, f"{status} {str(body)[:200]}")
    if status != 200:
        return
    status, listing = call("GET", "/api/journal/entries")
    check("list entries 200", status == 200, f"{status}")
    entries = listing.get("entries", []) if isinstance(listing, dict) else []
    check("entry is listed", len(entries) > 0, f"{str(listing)[:200]}")
    if not entries:
        return
    # The field is `why`. If it is ever renamed this is what catches a frontend
    # sending a stale name, instead of silently persisting a blank thesis -
    # which is exactly how a journal quietly becomes worthless.
    found = [e for e in entries if e.get("tag") == marker]
    check("entry persisted", len(found) >= 1, f"{len(found)} matches")
    if found:
        entry = found[0]
        check(
            "thesis round-trips as `why`",
            entry.get("why") == payload["why"],
            f"got {entry.get('why')!r}",
        )
        check(
            "invalidation round-trips",
            entry.get("invalidation") == payload["invalidation"],
            f"got {entry.get('invalidation')!r}",
        )
        check("aggressive defaults false", entry.get("aggressive") is False)
        check("timestamp auto-filled", bool(entry.get("ts")), f"{entry.get('ts')!r}")

    # unknown fields must be rejected, not silently swallowed
    status, _ = call(
        "POST",
        "/api/journal/entries",
        {"symbol": "OMNITEST", "thesis": "wrong field name"},
    )
    check("unknown field rejected (422)", status == 422, f"got {status}")

    status, _ = call("POST", "/api/journal/entries", {})
    check("missing required symbol rejected", status == 422, f"got {status}")

    status, stats = call("GET", "/api/journal/stats")
    check("stats 200", status == 200, f"{status}")
    if status == 200 and isinstance(stats, dict) and stats.get("n", 0) > 0:
        check(
            "stats exposes aggressive share",
            "aggressive_share" in stats,
            f"{list(stats)}",
        )
        check("stats cites the base rate", "sebi_note" in stats, f"{list(stats)}")

    # ── cleanup, then prove delete works ────────────────────────────────────
    # Tests must leave no residue: the journal is user data, and a test that
    # leaves fake trades in it corrupts every later stat the user looks at.
    status, listing = call("GET", "/api/journal/entries")
    entries = listing.get("entries", []) if isinstance(listing, dict) else []
    victims = [i for i, e in enumerate(entries) if e.get("tag") == marker]
    for i in reversed(victims):
        status, body = call("DELETE", f"/api/journal/entries/{i}")
        check(f"delete entry {i} 200", status == 200, f"{status} {str(body)[:120]}")
    status, listing = call("GET", "/api/journal/entries")
    entries = listing.get("entries", []) if isinstance(listing, dict) else []
    check(
        "test entries cleaned up",
        not [e for e in entries if e.get("tag") == marker],
        f"{len([e for e in entries if e.get('tag') == marker])} left",
    )

    status, _ = call("DELETE", "/api/journal/entries/9999")
    check("delete out-of-range 404s", status == 404, f"got {status}")


def test_guardrail_surfaced() -> None:
    print("\n[guardrails]")
    status, body = call("POST", "/api/ask", {"question": "Should I buy this tomorrow?"})
    check("ask 200", status == 200, f"{status} {str(body)[:160]}")
    if status == 200:
        check("ask returns an answer", bool(body.get("answer")), f"{list(body)}")
        check("guardrail result attached", "guardrail" in body, f"{list(body)}")
        text = body.get("answer", "")
        check(
            "answer carries a disclaimer",
            "🔎" in text or "not" in text.lower(),
            "no disclaimer found in answer",
        )


def test_execution_api() -> None:
    """The execution audit must never report zero cost for what it cannot measure."""
    print("\n[execution forensics]")

    st, body = call("GET", "/api/execution/cite")
    check("cite 200", st == 200, f"status={st}")
    check("cite names the source", "Barber" in json.dumps(body), "")
    check("cite separates measured from modelled",
          body.get("measured") is not None and body.get("modelled") is not None, f"{body}")
    check("cite states what we refuse to say",
          len(body.get("what_we_refuse_to_say", [])) >= 2, f"{body}")

    # A marketable limit that filled at the mid: zero cost, still AGGRESSIVE.
    st, body = call("POST", "/api/execution/classify", {
        "order": {"symbol": "AAA", "side": "buy", "order_type": "limit",
                  "limit_price": 101.0, "fill_price": 100.1,
                  "reference_price": 100.0, "bid": 100.0, "ask": 100.2},
    })
    check("classify 200", st == 200, f"status={st} {body}")
    check("classify => AGGRESSIVE", body.get("verdict") == "AGGRESSIVE", f"{body}")
    check("classify cost 0 at the mid", abs(body.get("cost_bps", -1)) < 1e-3, f"{body}")
    check("classify returns a reason", len(body.get("reason", "")) > 20, f"{body}")

    # No reference price at all -> must NOT be reported as passive/cheap.
    st, body = call("POST", "/api/execution/classify",
                    {"order": {"symbol": "AAA", "side": "buy", "fill_price": 100.0}})
    check("unmeasurable => NEUTRAL", body.get("verdict") == "NEUTRAL", f"{body}")
    check("unmeasurable => basis unavailable", body.get("basis") == "unavailable", f"{body}")

    # An empty audit is handled, not a crash.
    st, body = call("POST", "/api/execution/audit", {"orders": []})
    check("empty audit 200", st == 200, f"status={st} {body}")
    check("empty audit => n_orders 0", body.get("n_orders") == 0, f"{body}")

    # A real impatient account.
    orders = [{"symbol": "AAA", "side": "buy", "order_type": "limit",
               "fill_price": 100.5, "reference_price": 100.0}] * 6
    orders += [{"symbol": "BBB", "side": "buy", "order_type": "limit",
                "fill_price": 100.0, "reference_price": 100.0}] * 3
    st, body = call("POST", "/api/execution/audit",
                    {"orders": orders, "portfolio_value": 500000,
                     "orders_per_year": 250})
    check("audit 200", st == 200, f"status={st} {body}")
    check("audit => IMPATIENT", body.get("verdict") == "IMPATIENT", f"{body.get('verdict')}")
    # 6 aggressive + 3 passive out of 9 orders.
    check(
        "audit share is 6/9",
        abs(body.get("aggressive_share", 0) - (6 / 9)) < 1e-3,
        f"{body.get('aggressive_share')}",
    )
    # 50bps a fill on a 250-order year is ruinous, and the engine says so
    # rather than quietly shrinking it. This is the honest answer.
    check(
        "audit does not soften an absurd drag",
        body.get("annualised_drag_bps", 0) > 10_000,
        f"{body.get('annualised_drag_bps')}",
    )
    check("audit reports rupees", (body.get("annualised_drag_rupees") or 0) > 0, f"{body}")
    check("audit does not assume order count",
          body.get("annualisation_assumed") is False, f"{body}")
    check("audit returns a countermodel",
          isinstance(body.get("countermodel"), dict), f"{body}")
    check("countermodel carries a caveat",
          len(body["countermodel"].get("caveat", "")) > 30, f"{body['countermodel']}")

    # Unknown fields are rejected, not silently dropped.
    st, _ = call("POST", "/api/execution/audit",
                 {"orders": [], "portfolio_valu": 5})
    check("unknown field => 422", st == 422, f"status={st}")

    # Out-of-range fill probability.
    st, body = call("POST", "/api/execution/audit",
                    {"orders": orders, "fill_probability": 0.0})
    check("fill_probability 0 => 422", st == 422, f"status={st} {body}")
    st, _ = call("POST", "/api/execution/audit",
                 {"orders": orders, "fill_probability": 2.0})
    check("fill_probability 2 => 422", st == 422, f"status={st}")

def main() -> int:
    print("=" * 68)
    print("OMNIVEST API smoke test")
    print("=" * 68)
    if call("GET", "/api/health")[0] == 0:
        print(
            "\nFATAL: server not reachable. Run: cd backend && ./.venv/bin/python run.py"
        )
        return 2
    for fn in (
        test_reachable,
        test_forensics_api,
        test_pbo_api,
        test_crowding_api,
        test_citations,
        test_content_endpoints,
        test_write_paths,
        test_guardrail_surfaced,
    test_execution_api,
    ):
        fn()
    print("\n" + "=" * 68)
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} of {PASSED + len(FAILURES)}")
        for f in FAILURES:
            print(f"  - {f}")
        return 1
    print(f"ALL {PASSED} API CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
