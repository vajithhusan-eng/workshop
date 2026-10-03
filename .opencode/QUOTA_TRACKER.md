# opencode-usage-quota-tracker — WORKSHOP Project Notes

## Status: Configured Globally

The `opencode-usage-quota-tracker` plugin is enabled in the global OpenCode
configuration at `~/.config/opencode/opencode.jsonc`.

### Live global plugin list

```jsonc
"plugins": [
  "@tarquinen/opencode-dcp",
  "opencode-usage-quota-tracker",
  "/home/vajith-husan/.config/opencode/plugins/custom-tools",
  "/home/vajith-husan/.config/opencode/plugins/opencode-auto-fix"
]
```

Local directories under `~/.config/opencode/plugins/` are **auto-scanned**, so
anything present there loads even when it is absent from the array above.

### Disabled

`opencode-model-recommender` is currently parked at
`plugins/.disabled-opencode-model-recommender/`. It depends on `ctx.catalog`,
which was removed from the plugin API in OpenCode v2, so it throws on load and
self-neutralises (ranking silently off). Rename it back to
`opencode-model-recommender/` to re-enable once a v2-compatible release ships.

## No Project-Level Configuration Needed

The plugin works with the global config as-is. It requires:

1. A provider API key, already present via `opencode auth login`
2. OpenCode V2 — the global config uses the V2 plugin API

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