# opencode-usage-quota-tracker — WORKSHOP Project Notes

## Status: Already Configured Globally

The `opencode-usage-quota-tracker` plugin is **already enabled** in the global
OpenCode configuration at `~/.config/opencode/opencode.jsonc` (line 613).

```jsonc
"plugins": [
    "@tarquinen/opencode-dcp",
    "opencode-usage-quota-tracker",
    "opencode-model-recommender",
    "/home/vajith-husan/.config/opencode/plugins/custom-tools"
]
```

## No Project-Level Configuration Needed

The plugin works with the global config as-is. It requires:

1. **A provider API key**: Run `opencode2 auth login` (already done for this setup)
2. **OpenCode V2**: The global config uses V2 plugin API

## What It Does

- Shows a **sidebar footer** widget in the TUI with live session token/cost usage
- Displays quota rows for 5h / 1w / 1mo windows of the workspace plan
- Auto-detects the provider (Zen `opencode` or Go `opencode-go`)
- Refreshes every minute — no commands needed

## Switching Views

- `/usage-view` or `/usage` — picker for connected provider views
- `/usage-view zen` — Zen-specific view
- `/usage-view go` — Go-specific view

## Per-Project Installation (Alternative)

If needed, the plugin can also be installed per-project by copying it to:
`<project>/.opencode/plugins/opencode-usage-quota-tracker/`

This is NOT necessary for WORKSHOP since the global config already handles it.

## Prerequisites

- OpenCode V2
- Provider API key via `opencode2 auth login`
- The global config already satisfies both requirements
