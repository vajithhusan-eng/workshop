# OMNIVEST backend

The API behind the OMNIVEST terminal: **free knowledge, self-analytics and a
journal you can correct**. Python + FastAPI, no database server — the journal is
a JSON file on disk.

> OMNIVEST is the older product in this monorepo. It is **not** Agora, rgx or
> CleanTube, which live under `projects/`; it shares the repo, not the stack.

## What it is

- **Education, not advice.** `app/guardrails.py` runs in **SAFE mode by default**
  (`OMNIVEST_ADVISER_MODE` unset): trading calls, ratings, price targets and
  "guaranteed" language are blocked, and `/api/health` reports
  `"safe_mode": true`. ADVISER mode is for a SEBI-registered IA/RA partner only.
- **Self-analytics over your own actions.** Order execution audit and
  classification, portfolio forensics (autopsy, momentum-crash risk, PBO via
  CSCV), a watch loop over rules *you* wrote, and a journal.
- **Synthetic data says so.** When real bars are unavailable the response carries
  a `NO_DATA` verdict and a `data_warning` — plausible-looking numbers are never
  invented to fill the gap.

## Run it

```bash
cd backend
python -m venv .venv && ./.venv/bin/pip install -r requirements.txt
./.venv/bin/python run.py            # http://127.0.0.1:8123
```

| Env var | Default | Meaning |
|---|---|---|
| `OMNIVEST_PORT` | `8123` | Listen port |
| `OMNIVEST_RELOAD` | `1` | Uvicorn auto-reload |
| `OMNIVEST_ADVISER_MODE` | `0` | `1` disables the SAFE-mode guardrails. Read at **import time** — needs a restart |

Interactive API docs at `/docs`. `run.py` watches **only** `app/` and excludes
`tests/`; watching the repo root made the server restart on every test write.

## Test it

```bash
make test-unit     # 143 checks — forensics, execution, watchloop. No server.
make test-api      # 168 checks — needs the server above running.
```

`pytest app/tests` runs the **unit suite only**. `app/tests/test_api.py` is an
end-to-end smoke test that drives `httpx` against a live server, so
`app/tests/conftest.py` excludes it from pytest collection; run it with
`make test-api` against a booted server instead.

## HTTP surface

31 routes, all defined in `app/main.py`:

| Area | Routes |
|---|---|
| Health | `GET /api/health` |
| Canon / knowledge | `GET /api/canon/consensus`, `/api/canon/debates`, `/api/sebi/summary`, `/api/books/starter`, `/api/videos/channels`, `/api/techniques` |
| Watch loop | `GET /api/watch/rules`, `POST /api/watch/detect` |
| Journal | `POST|GET /api/journal/entries`, `DELETE /api/journal/entries[/{index}]`, `GET /api/journal/stats` |
| Notes / rules / books | `POST /api/notes`, `/api/rules`, `/api/books/extract` |
| Briefing | `POST /api/brief/daily` |
| Forensics | `POST /api/forensics/autopsy`, `POST /api/forensics/pbo`, `GET /api/forensics/crowding`, GET `/api/forensics/cite` |
| Execution | `POST /api/execution/audit`, `/api/execution/classify`, `GET /api/execution/cite` |
| Market | `GET /api/market/candles`, `/api/market/quote`, `/api/market/symbols` |
| Analysis | `GET /api/analysis/symbol`, `/api/analysis/scan` |
| Ask | `POST /api/ask` |

## Layout

| Path | What it holds |
|---|---|
| `run.py` | Uvicorn entry: port, reload scope, `sys.path` bootstrap |
| `app/main.py` | Every route and request model (31 handlers) |
| `app/guardrails.py` | SAFE-mode output guard — blocked phrases, ratings, price targets |
| `app/forensics.py` | `autopsy`, `momentum_crash_risk`, `pbo_cscv` |
| `app/execution.py` | `audit_orders`, `classify_order` |
| `app/strategy.py` | `analyse`, `scan`, `ACTIONS` |
| `app/market.py` | `get_candles`, `quote`, `symbol_search` (+ symbol aliases) |
| `app/indicators.py` | `compute_all`, `snapshot` |
| `app/watchloop.py` | `RULES`, `RULE_LIST`, `detect`, `rules_digest` |
| `app/data_seed.py` | Seeded knowledge: consensus, debates, SEBI FY26, books, channels |
| `app/tests/` | 7 test modules — 3 unit suites + 4 module suites + the live API smoke |

## Docs

- [`docs/README.md`](docs/README.md) — the documentation index.
- [`AGENTS.md`](AGENTS.md) — instructions for anyone (human or agent) changing this code.
- [`STATE.md`](STATE.md) — verified build status.
- [`CHANGELOG.md`](CHANGELOG.md) — commit history for this project.

## The journal file

`omnivest_journal.json` (next to `run.py`) is **user data** and is gitignored.
Every write path has a matching undo (`_delete_entries_where` in `main.py`) —
a journal you cannot correct is not a journal.
