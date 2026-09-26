# 🏭 WORKSHOP — Main Project Workspace

[![GitHub](https://img.shields.io/badge/GitHub-vajithhusan-eng-blue?logo=github)](https://github.com/vajithhusan-eng)
[![OpenCode](https://img.shields.io/badge/OpenCode-Active-brightgreen?logo=opencode)](http://127.0.0.1:49374)

All projects are stored as subdirectories under this folder. Every project is fully configured with OpenCode, Git, MCP servers, skills, and agents.

## 📁 Project Structure

```
WORKSHOP/
├── 📁 projects/          → All project code
├── 📁 backend/           → Finance backend (Python/FastAPI)
├── 📁 frontend/          → Flutter web frontend
├── 📁 tools/             → Tool scripts and utilities
├── 📁 archive/           → Completed/archived projects
├── 📄 opencode.jsonc     → Project-level OpenCode config
├── 📄 Makefile           → Quick commands (make backend, make frontend)
├── 📄 package.json       → Workspace package with subdirectory workspaces
├── 📄 .github/           → CI/CD pipelines
├── 📄 .opencode/         → Agents, MCPs, commands, plugins
│   ├── agents/           → architect, coder, reviewer, tester
│   ├── mcp.jsonc         → All 7 MCP servers configured
│   ├── commands/         → setup command
│   └── QUOTA_TRACKER.md  → Usage tracking
├── 🔗 skills/            → Symlink to 70+ global skills
└── 📄 .gitignore         → Excludes all build artifacts
```

## 🚀 Quick Start

```bash
# Start OpenCode in WORKSHOP
cd /home/vajith-husan/Documents/WORKSHOP
opencode .

# Start the finance backend
make backend

# Start the Flutter web frontend
make frontend

# Setup everything
make setup
```

## 🔗 MCP Servers (All 7 Connected)

| Server | Purpose |
|--------|---------|
| **filesystem** | Access to WORKSHOP files |
| **context7** | Live library documentation |
| **fetch** | Web search and content |
| **playwright** | Browser automation |
| **memory** | Cross-session knowledge |
| **sequential-thinking** | Reasoning and planning |
| **time** | Date/time queries |

## 🛡️ Protections

- **opencode-mcp-guard.sh** — Reaps orphaned MCP processes every 5 min
- **Watchdog disabled** — No restart storms
- **Auto-compaction** — 12k tokens keep, 20k buffer
- **Git version control** — All configs tracked
- **Quota tracker** — Live usage monitoring

## 🧠 Agents

| Agent | Purpose |
|-------|---------|
| **architect** | System design and planning |
| **coder** | Code implementation |
| **reviewer** | Code review and quality |
| **tester** | Testing and QA |

## 📝 Commit Convention

```
<type>(<scope>): <description>
```
Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`, `build`

## 🐛 Issues

If OpenCode can't find your project, check:
1. The project is under `/home/vajith-husan/Documents/WORKSHOP/`
2. Ports 8123/8081 are listening (backend/frontend running)
3. Run `bash ~/.local/bin/opencode-mcp-guard.sh` to clean zombie processes

## 📧 Contact

- GitHub: [vajithhusan-eng](https://github.com/vajithhusan-eng)
- Email: vajithhusan2510@gmail.com
