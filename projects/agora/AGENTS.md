# Agora — project instructions

Native Ubuntu/Linux **desktop app (AppImage)** that acts as a multi-AI council
orchestrator. You state a problem once; a leader AI decomposes it and invites
other AIs into a real debate; they critique and revise until the leader declares
it solved. Every agent runs in a **real Chrome tab driven over CDP**, and every
word is stored **verbatim** — Agora never rewrites or summarises agent output.

One session = one chat = one project.

## Authority

- `PLAN.md` — **plan of record**, `Status: PLAN APPROVED`. Binding.
- `PLAN-GROUPCHAT.md` — `Status: PROPOSED`, **untracked in git**. **Superseded.** Its
  D1 round-robin was ratified on 2026-10-06 — but as `PLAN.md` **§18 Amendment R1**,
  under the approved plan. Keep the file as the record of what was proposed; never
  cite it as authority over `PLAN.md`.
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

## Dispatch model — RESOLVED by Amendment R1 (§18)

The contradiction that used to block `SpeakerSelector` is **closed.** `PLAN.md`
**§18 Amendment R1** was ratified by the user on 2026-10-06 and supersedes §2.4,
§8, §11 and §17 wherever they conflict. `PLAN-GROUPCHAT.md` D1 is therefore moot —
round-robin was adopted, but under the approved plan and renamed `broadcast`.

| Action | Channel | Who may send it |
|---|---|---|
| `invite` | public | leader only |
| `broadcast` | public | leader only |
| `dm` | private | **any participant** |
| `decide` / `comment` / `need_input` | public | leader only |

**Unchanged non-negotiable: all dispatch comes from strict machine-readable blocks;
free text never dispatches.** §2.4's "delegates may not invite" ban is *replaced* —
delegates may `dm` privately, but only the leader opens a public round.

`SpeakerSelector` is **unblocked**: it selects the next speaker from this table
(invite target, broadcast set, or dm target), never from free text.

**Built** (§18.5, landed 2026-10-10): protocol parser for all five actions · orchestrator
sender table with channel-aware `MessageCaptured`/`PacketDispatched` ·
`channels(id, session_id, kind, display_name, members, created_at)` + `messages.channel_id`
(drift migration v3) and repo CRUD · `CouncilRunner` journals each message into the right
§18.1 thread · centre pane reads the selected thread · slash-command composer · silent
Chrome `agora.chromeMode` (P11) with reveal · conversation chips carry real avatar stacks,
presence dots and unread badges (read state is a per-thread message **count**, not a
timestamp — drift's `createdAt` is whole seconds).

**Still to build:** the full §18.3 HUD (per-agent context-pressure meters, model picker,
adversarial/fork/template actions — their engines do not exist) and conversation
search/pin · ✓/✓✓ read receipts (impossible without site integration) · §18.5.5 UI widget
tests beyond the conversation chip and the convergence card.

**§18.1 mapping to keep:** public messages are the **null-`channel_id`** rows; the
`ch:$sessionId:public` row exists only so the chat list has a public conversation. Do not
"fix" it to filter on its own id — the UI passes `null` for the public thread.

`TabPool` was built dispatch-model-agnostic — it only owns tabs, so it holds under
either reading and was never wasted.

## Verified state as of last orientation

Regenerate with the `project-orientation` skill. `STATE.md` holds the full detail.

The UI landed in `ceb4a49` and the `lib/` tree is clean. Verify with `flutter test` and
`flutter analyze` before trusting any of this — the project moves fast and this section
goes stale within hours.

| Phase | Status | Evidence |
|---|---|---|
| P0 UI restore | **done** | `main.dart` → `ProviderScope(child: AgoraApp())`; `app.dart` mounts `HomeShell`; 9 files in `lib/ui/` |
| P1 Chrome launcher | **done** | `chrome_launcher.dart` launched by `CouncilRunner`; first-run onboarding wizard in `lib/ui/onboarding_screen.dart` |
| P2 adapter framework | **done** | framework + 3 validating adapters; `SelectorProber` reports which selector tier resolved on a live page |
| P3 storage | **done** | `SessionRepository`; `schemaVersion => 3` with a real `onUpgrade` (v2→v3 adds `channels` + `messages.channel_id`); repository tests incl. §18.1 thread tests |
| P4 orchestrator | **done and reachable** | `CouncilRunner` constructs it; `lib/core/council/` holds `TabPool` + `CouncilRunner` |
| P5 Gemini/DeepSeek | config only | JSON validates and the sandbox drives them, but no run against a **real** logged-in site yet |
| P6 safety | **done** | `safety.dart`; firewall warnings journaled by `CouncilRunner`; Time Machine replays captured turns into the Sandbox Lab |
| P7 packaging | **done** | `tool/build_appimage.sh` → `build/agora-0.1.0-x86_64.AppImage` (11.7 MB), launch-verified |

`flutter test` → **290 passed, 1 skipped, 0 failed**. `dart analyze lib/ test/` → **0 errors,
0 warnings** (62 info). `dart run tool/sandbox_smoke.dart` → 42/42 against real Chrome.

### The gap that defines the current stage

**There isn't one any more.** The app launches a real Chrome, opens a tab per AI, runs the
council and writes every word to the vault. See `STATE.md` for the verified list of what is
still open — trusted typing, real-site runs for Gemini/DeepSeek/ChatGPT, `linux/**` analysis,
and `SpeakerSelector` (blocked on the dispatch contradiction below).

## Known traps

- **Lib typing is JS-synthetic** (`page_script.dart:182`). CDP `Input.insertText` is proven
  in `tool/cdp_smoke.dart:128` but has **0 uses in `lib/`** → fails any `isTrusted` check.
- **`analysis_options.yaml` excludes `linux/**` — but the exclusion is inert, and the C++
  runner is now actually checked.** `dart analyze` reads only `.dart` files; `linux/` has
  zero of them, so removing the exclusion changes nothing. The real gap was that
  `linux/runner/*.cc` was checked by no tool at all. `tool/cpp_lint.sh` closes it via
  `clang++ -fsyntax-only -Wall -Wextra`, deriving every flag from the real CMake files. Do
  not "fix" the exclusion by deleting it — the comment there explains why it stays.
- `tool/dbg2.dart` and its siblings (`run_*.dart`, `check_load*.dart`, `debug*.dart`,
  `probe_fix.dart`) are **ignored scratch — kept on disk, never shipped.** They are dead
  helpers written against an older API and are the *only* source of analyzer output in
  `tool/` (whole directory: 4 warnings, 20 errors; tracked sources: 22 info, 0 err, 0 warn —
  check with `dart analyze $(git ls-files 'tool/*.dart')`). They are `.gitignore`d rather
  than deleted because **another agent commits in this monorepo concurrently and runs
  `git clean`/`git restore`;** that has already destroyed untracked work here. Ignoring them
  additionally makes a plain `git clean -fd` skip them. Do not assume an untracked file is
  yours to delete. Commit after every edit and re-`grep` before trusting a result.
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