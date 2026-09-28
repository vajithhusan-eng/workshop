---
name: auto-fix
description: Control the auto-fix feature — check status, view history, run diagnostics, and trigger a specific fix
---

# Auto-Fix Command Center

> **Golden Rules**
> 1. Never run `opencode service restart` while the desktop app runs
> 2. Auth lives in the desktop-managed sidecar
> 3. One writer per repo file
> 4. Auto-fix only when safe; escalate when unsure

All commands below call the `opencode-auto-fix` plugin tools. Run
`/auto-fix status` first if unsure — it is read-only.

---

## `/auto-fix status` — Show current state

Read-only. Nothing is modified.

**Tool:** `auto-fix-status`

**Reports:** enabled state, the seven known categories, the attempt cap (2), the
cooldown (60s), the log file path, and the last 25 history entries.

---

## `/auto-fix check` — Run diagnostics

Read-only. Inspects the installation without changing it.

**Tool:** `auto-fix-check`

**Checks:**
- `opencode mcp list` — which MCP servers are up
- config JSONC validity for `opencode.json` / `opencode.jsonc`
- `opencode.db` size (a runaway session DB shows up here)

---

## `/auto-fix history` — Show the fix log

**Tool:** `auto-fix-status` (the `history` field)

The full log is at `~/.local/share/opencode/logs/auto-fix.log`. Each line records
the timestamp, the action, the category, the source that triggered it, and the
outcome.

Status keywords to look for:

| Keyword | Meaning |
|---|---|
| `FIXED` | The action ran and succeeded. |
| `REPORTED` | Found a defect, deliberately did not repair it. |
| `ESCALATED` | No safe automatic action; needs a human. |
| `FIX_FAILED` | The action threw; the error is on the same line. |
| `BACKUP_FAILED` | A file could not be backed up before an edit. |

---

## `/auto-fix fix <category>` — Trigger a specific fix

**Tool:** `auto-fix-apply` with `{ "category": "<id>" }`

Passing an explicit category bypasses the 60s cooldown, so the action always
makes a real attempt. It does not bypass the 2-attempt cap.

| Category | What happens |
|---|---|
| `mcp-disconnected` | Clears `~/.cache/opencode/mcp*` so the server re-initialises. |
| `provider-transient` | Clears `~/.cache/opencode/providers`. |
| `config-parse` | Diagnose only — reports the file and parse error, does not edit. |
| `provider-auth` | Always escalates. Auth belongs to the desktop sidecar. |
| `tool-unavailable` | Always escalates. A session restart is required, which is forbidden. |
| `session-stuck` | Always escalates. Killing processes risks in-flight work. |
| `watchdog-storm` | Always escalates. Needs a `systemctl` change. |

Any other value returns `unknown category` along with the valid list.

---

## `/auto-fix fix auto "<error text>"` — Match by error message

**Tool:** `auto-fix-apply` with `{ "category": "auto", "error": "<text>" }`

Matches the text against the playbook and runs whatever it hits. Returns
`unmatched` if nothing matches — which is the honest answer, not a failure. Use
this after an `unmatched` line in the log to confirm a message is genuinely
unrecognised.

---

## `/auto-fix off` — Disable automatic fixing

**Tool:** `auto-fix-toggle` with `{ "enabled": false }`

Stops all automatic action. Detection and logging continue, so you can watch what
*would* have been fixed. Manual `/auto-fix fix <category>` also stops working
while disabled.

---

## `/auto-fix on` — Re-enable

**Tool:** `auto-fix-toggle` with `{ "enabled": true }`

---

## Notes

- There is no `OPENCODE_AUTO_FIX_*` environment configuration. The plugin's knobs
  are the two constants at the top of `index.mjs`: `maxAttempts` and `cooldownMs`.
- The plugin does not fix source files. It handles OpenCode's own runtime
  failures. For code-level fixes (types, lint, imports) use the `coder` or
  `tester` agents, or your project's own tooling.
