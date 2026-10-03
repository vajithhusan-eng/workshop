# Agora — project instructions

Native Ubuntu/Linux **desktop app (AppImage)** that acts as a multi-AI council
orchestrator. You state a problem once; a leader AI decomposes it and invites
other AIs into a real debate; they critique and revise until the leader declares
it solved. Every agent runs in a **real Chrome tab driven over CDP**, and every
word is stored **verbatim** — Agora never rewrites or summarises agent output.

One session = one chat = one project.

## Authority

- `PLAN.md` — **plan of record**, `Status: PLAN APPROVED`. Binding.
- `PLAN-GROUPCHAT.md` — `Status: PROPOSED`, **untracked in git**. An unratified
  design amendment, not the contract. It contradicts `PLAN.md` on the dispatch
  model (see Blocking contradiction). Never treat it as settled.
- `ARCHITECTURE-legacy.md` — historical Python backend. **Do not build against it.**
- `STATE.md` — derived build status. Regenerate via the `project-orientation` skill.

## Locked decisions — violating these reverses work already done

1. **Name is Agora.**
2. **Stack: Flutter desktop (Dart) + raw CDP + SQLite/drift. No Python. No Docker.
   No WebSocket/backend server. No telemetry.** `ARCHITECTURE-legacy.md` is the
   archived Python backend; it must never come back.
3. **Reuse the existing Flutter UI; rewrite only the service/provider layer.**
4. **Output is AppImage.** Native, local-first, air-gap capable except the AI sites.
5. **One live session at a time.** ~150–300 MB per Chromium tab. Other sessions
   are stored transcripts you resume, not live tabs.
6. **Verbatim output, always.** Raw text + raw HTML + screenshot, immutable.

## Non-negotiables (`PLAN.md` §2)

- **Adapters are data, not code.** Selectors live in versioned JSON under
  `assets/adapters/`. A ChatGPT redesign must never require an app release.
- **The orchestrator never guesses.** Dispatch only from a strict machine-readable
  block. Free text never triggers a dispatch.
- **Local-first.** SQLite on disk. No server, no telemetry.
- Hard caps on invites and rounds; strictly serialized dispatch, one agent at a time.

## Conventions

- Dart, `>=3.10.0`. State management is Riverpod, **now wired** — `lib/app.dart`
  defines `agoraDbProvider`, `repositoryProvider`, and `controllerProvider`, and
  `lib/main.dart` wraps everything in `ProviderScope`. Do not introduce a second DI
  mechanism, and do not pass the controller down by hand where `ref.watch` works.
- drift for SQLite. `drift_dev` is pinned deliberately: newer drift_dev hard-crashes
  codegen on Dart 3.10. Do not unpin it casually.
- CDP over raw WebSocket on port 9222. No Puppeteer, no Playwright.
- Typing is JS-synthetic (`page_script.dart`). CDP `Input.insertText` is proven only
  in `tool/cdp_smoke.dart` and will fail any `isTrusted` check.
- Tests: `test/` for unit, `tool/` for real-Chrome smoke checks. Real-site tests are
  **manual and opt-in only** — never wire them into CI.

## Blocking contradiction — needs a ruling before SpeakerSelector

`PLAN.md` §2.4 and §8: dispatch **only** from an `invite` block naming one agent;
free text never dispatches; delegates may not invite peers.
`PLAN-GROUPCHAT.md` D1: **round-robin broadcast** to all participants, leader may
force a speaker, no @-mention protocol.

**The code follows `PLAN.md`** (`lib/core/orchestration/orchestrator.dart:494`
dispatches on `CouncilAction.invite`; `:687` forbids delegate invites).

`TabPool` has since been built and is **dispatch-model-agnostic** — it only owns tabs,
so it was not wasted under either reading. `SpeakerSelector` genuinely is: choosing
*who speaks next* is the thing the contradiction is about. It is the last component
that must wait. Raise it, do not guess.

## Verified state as of last orientation

Regenerate with the `project-orientation` skill. `STATE.md` holds the full detail.

The UI landed in `ceb4a49` and the `lib/` tree is clean. Verify with `flutter test` and
`flutter analyze` before trusting any of this — the project moves fast and this section
goes stale within hours.

| Phase | Status | Evidence |
|---|---|---|
| P0 UI restore | **done** | `main.dart` → `ProviderScope(child: AgoraApp())`; `app.dart` mounts `HomeShell`; 9 files in `lib/ui/` |
| P1 Chrome launcher | 3/4 | `chrome_launcher.dart` done and now actually launched by `CouncilRunner`; onboarding wizard missing |
| P2 adapter framework | 3/4 | framework + 3 validating adapters done; Calibration Studio built but does not probe a live page |
| P3 storage | **done** | `SessionRepository`; `schemaVersion => 2` with a real `onUpgrade`; 19 repository tests |
| P4 orchestrator | **done and reachable** | `CouncilRunner` constructs it; `lib/core/council/` holds `TabPool` + `CouncilRunner` |
| P5 Gemini/DeepSeek | config only | JSON validates and the sandbox drives them, but no run against a **real** logged-in site yet |
| P6 safety | ~70% | `safety.dart` done; firewall warnings journaled by `CouncilRunner`; replay still outstanding |
| P7 packaging | **done** | `tool/build_appimage.sh` → `build/agora-0.1.0-x86_64.AppImage` (11.7 MB), launch-verified |

`flutter test` → **147 passed, 1 skipped, 0 failed**. `dart analyze lib/ test/` → **0 errors,
0 warnings**. `dart run tool/sandbox_smoke.dart` → 42/42 against real Chrome.

### The gap that defines the current stage

**There isn't one any more.** The app launches a real Chrome, opens a tab per AI, runs the
council and writes every word to the vault. See `STATE.md` for the verified list of what is
still open — the onboarding wizard, live selector probing, journal replay, trusted typing,
and `SpeakerSelector`.

## Known traps

- **Lib typing is JS-synthetic** (`page_script.dart:182`). CDP `Input.insertText` is proven
  in `tool/cdp_smoke.dart:128` but has **0 uses in `lib/`** → fails any `isTrusted` check.
- `analysis_options.yaml` excludes **`linux/**`** — this AppImage-targeting app never
  analyzes its own Linux platform runner. Enabling it may surface many lints; treat that
  as real work, not noise.
- `tool/dbg2.dart` is untracked scratch and holds the only 2 analyzer warnings. **Another
  agent commits in this monorepo concurrently and runs `git clean`/`git restore`;** it has
  already destroyed untracked work here. Commit after every edit and re-`grep` before
  trusting a result.
- Chrome 136+ blocks `--remote-debugging-port` on the default `--user-data-dir`.
  A **dedicated** profile at `~/.config/agora/chrome-profile` is mandatory. `PLAN.md`
  §0/§1.4 still over-promises "your own logged-in Chrome" — that text is stale, §4.1 is
  correct.
- `PLAN-GROUPCHAT.md` names files that will never exist under those names
  (`security_firewall.dart` → actual `safety.dart`; `context_compiler.dart` →
  `prompt_compiler.dart`). Do not use it as a literal task list.

## Open questions (`PLAN.md` §17 — answered, now live toggles)

1. Per-agent daily message cap — **60/agent/day**, persisted in Settings under
   `agora.dailyCapPerAgent`. `UsageCounters` has a writer (`SessionRepository.countMessage`).
2. Visible Chrome window — **visible**; a real AI site can throw a captcha or expire a
   login and the user has to see it. Tray minimisation is not built. `agora.chromeVisible`.
3. Relay — **raw**. `agora.relayRaw`.

All three are Settings toggles with the suggested defaults; none of them blocks work.