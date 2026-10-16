# 🏭 WORKSHOP

[![GitHub](https://img.shields.io/badge/GitHub-vajithhusan--eng-blue?logo=github)](https://github.com/vajithhusan-eng/workshop)
[![OpenCode](https://img.shields.io/badge/built%20with-OpenCode-brightgreen)](https://opencode.ai)

A monorepo holding several unrelated projects side by side. Each one is
self-contained, has its own stack, its own tests, and its own complete document
set — **the same document set for every project**, current and future. See
[`PROJECT-STANDARD.md`](PROJECT-STANDARD.md).

## 📁 Projects

| Project | What it is | Stack | Status |
|---|---|---|---|
| [`projects/agora/`](projects/agora/) | Multi-AI council orchestrator driving real Chrome over CDP | Flutter desktop (AppImage) | **active** |
| [`projects/rgx/`](projects/rgx/) | Quant research harness — factors → ranker → regime → portfolio → validation | Python | active, no edge claimed |
| [`projects/cleantube/`](projects/cleantube/) | Android-first ad blocker (browser + native YouTube client + DNS sinkhole) | Flutter Android | **plan only, zero code** |
| [`projects/arise/`](projects/arise/) | Research and roadmap, in flight | — | in flight by another agent |
| [`backend/`](backend/) | OMNIVEST finance/forensics API (`:8123`) | Python + FastAPI | active |
| [`frontend/`](frontend/) | OMNIVEST terminal UI (`:8081`) | Flutter web | active |

Every project carries `README.md`, `AGENTS.md`, `STATE.md`, `CHANGELOG.md` and
`docs/README.md`. Start at the project's `README.md`; an agent should start at
`AGENTS.md`.

## 🚀 Quick start

```bash
make help            # every command, with one line each

make backend         # start the OMNIVEST API on :8123
make frontend        # start the OMNIVEST web UI on :8081
make dev-status      # what is running: session, port, pid, health

make test            # unit + api + frontend suites
make verify          # the pre-commit gate: units, lint, then a real HTTP call
make check           # documentation standard + STATE freshness
```

## ✅ Documentation standard

`PROJECT-STANDARD.md` is the contract: every project is arranged the same way,
with one concern per document, so a person or an agent arriving anywhere finds the
same doors in the same places.

```bash
make projects-check  # every project has the required files, headers well-formed
make docs-check      # every STATE.md pin matches HEAD; no agent defined twice
make check           # both
```

New project:

```bash
python3 scripts/new_project.py <slug> --name "<Name>" --one-line "<description>" --kind python
```

It stamps `templates/project/` into a new directory with the standard files, the
required headers, and a `STATE.md` already pinned to HEAD.

## 🗂️ Layout

```
WORKSHOP/
├── projects/            → agora, arise, cleantube, rgx
├── backend/             → OMNIVEST API (Python/FastAPI)
├── frontend/            → OMNIVEST web UI (Flutter)
├── scripts/             → devsup.py, new_project.py, verify_docs.py,
│                          verify_projects.py, verify_api.sh
├── templates/project/   → the canonical project skeleton
├── PROJECT-STANDARD.md  → the standard every project follows
├── AGENTS.md            → rules for agents working in this repo
├── Makefile             → every command
├── opencode.jsonc       → repo-level OpenCode config (.opencode/ wins over it)
├── .opencode/           → agents (architect, coder, reviewer, tester),
│                          commands (setup, dev, auto-fix), MCP servers
├── .devsup/             → live build/runtime state (gitignored)
├── archive/, tools/     → empty
└── skills → ~/.config/opencode/skills-active
```

## 🔗 Tooling

- **MCP servers** are configured in `.opencode/mcp.jsonc` (filesystem, context7,
  fetch, playwright, memory, sequential-thinking, time).
- **Protections** — `~/.local/bin/opencode-mcp-guard.sh` reaps orphaned MCP
  processes on a timer, if installed. Auto-compaction keeps **15000** tokens and
  buffers 20000.
- **Commits** follow `<type>(<scope>): <description>` — `feat`, `fix`, `docs`,
  `style`, `refactor`, `test`, `chore`, `perf`, `ci`, `build`.

## 🐛 When something looks wrong

1. The project is under `/home/vajith-husan/Documents/WORKSHOP/`.
2. Ports 8123 (backend) and 8081 (frontend) are listening — `make dev-status`.
3. `python3 scripts/devsup.py targets` lists what devsup can start.
4. Stale docs? `make check` names the exact file that needs re-verifying.

## 📧 Contact

- GitHub: [vajithhusan-eng](https://github.com/vajithhusan-eng)
- Email: vajithhusan2510@gmail.com
