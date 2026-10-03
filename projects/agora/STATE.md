# Agora — STATE

**Derived file.** Regenerate by verifying, not by trusting commit messages or this file.
**Verified:** 2026-10-03 · `HEAD d5921b1` (`docs(agora): replace the Flutter template README`).
The working tree is clean for `lib/ test/ tool/ assets/ linux/ README.md` — the only
untracked path is `tool/dbg2.dart`, a scratch file (see Still open).

## How to verify this file

```bash
cd projects/agora
flutter test          # 147 passed, 1 skipped, 0 failed
dart analyze lib/ test/   # 0 errors, 0 warnings (59 info)
git log --oneline -1
```

Real-Chrome checks in `tool/` are **manual and opt-in** (`PLAN.md` §12). Never CI:

```bash
dart run tool/sandbox_smoke.dart   # 42 checks, mock AI site, real Chrome
dart run tool/focus_probe.dart     # anti-throttling + TabPool against real Chrome
./tool/build_appimage.sh           # builds the .AppImage
```

## Verified green

| Check | Result |
|---|---|
| `flutter test` | **147 passed · 1 skipped · 0 failed** |
| `dart analyze lib/ test/` | **0 errors · 0 warnings** (59 info) |
| Test inventory | 148 `test()` blocks · 7 files |
| `dart run tool/sandbox_smoke.dart` | **42 passed · 0 failed** against real Chrome 154 |
| `dart run tool/focus_probe.dart` | **ALL OK** — focus emulation, `Page.bringToFront`, and all six `TabPool` paths |
| AppImage | `build/agora-0.1.0-x86_64.AppImage`, 11.7 MB. Launched from its FUSE mount; no exceptions; created `agora.sqlite` at `user_version 2` with all 9 tables, FTS5, and all 4 hot-query indexes |
| The 1 skip | `orchestrator_test.dart:494` — `stallForever is checked before mutation; kept as documentation`. Intentional, not hidden. |
| `dart analyze tool/` | 2 warnings, **both in the untracked scratch file `tool/dbg2.dart`**. Zero in shipped code. |

## The one thing that matters

**Agora now runs a real council, end to end, and keeps every word.**

The wiring gap that used to define this project is closed:

- `lib/core/council/tab_pool.dart` — one Chrome tab per AI. `Target.createTarget` now
  has real call sites (it had zero, which is why the tab pool in `PLAN.md` could not be
  built). Opens all tabs up front, caches one flattened session per target, closes
  everything in a `finally`.
- `lib/core/council/council_runner.dart` — the **only** class that knows both Chrome and
  SQLite. Launches Chrome against the dedicated profile (visible, not headless — a real
  AI site can throw a captcha the user must see), loads `assets/adapters/<kind>.json`,
  opens a tab per seat, refuses to start a seat whose config fails validation or whose
  login is not ready (as a sentence the user can act on, not a stack trace), then hands
  the adapters to the orchestrator and writes every captured message to the vault.
- `AgoraController.startCouncil()` / `interruptCouncil()` / `snapshot()` drive it from the
  UI; the council panel shows live progress, a Stop button, and any blocking reason in
  full.

## Closed since the previous orientation

| Gap | Status | Evidence |
|---|---|---|
| `main.dart` stub, UI unmounted | **CLOSED** | `ProviderScope(child: AgoraApp())`; `app.dart` mounts `HomeShell` |
| Riverpod declared, 0 imports | **CLOSED** | 3 providers in `app.dart` |
| P3 storage "schema only" | **CLOSED** | `lib/data/session_repository.dart` + 19 repository tests |
| `schemaVersion => 1`, no `onUpgrade` | **CLOSED** | v2, real migration, `onUpgrade` |
| **Fresh installs got zero indexes** | **CLOSED** | index DDL moved into both `onCreate` and `onUpgrade`; asserted by `test/database_schema_test.dart` |
| **Index DDL used camelCase columns** | **CLOSED** | drift emits `session_id`/`created_at`; the old DDL would have thrown on every upgrade |
| **Orchestrator never constructed** | **CLOSED** | `CouncilRunner` builds it; `lib/` has a live dispatch path |
| `Target.createTarget` zero call sites | **CLOSED** | `TabPool.open` |
| Background-tab throttling | **CLOSED** | `Emulation.setFocusEmulationEnabled` in `WebAgentAdapter.connect()`, `Page.bringToFront` in `send()`; both proven by `tool/focus_probe.dart` |
| Snapshot / Esc were stubs | **CLOSED** | Ctrl+S photographs every live tab into `vault/<session>/`; Esc interrupts a running council |
| Packaging | **CLOSED** | `tool/build_appimage.sh`; desktop entry, metainfo, 512px icon, AppRun; verified launch |
| `README.md` Flutter template | **CLOSED** | rewritten: install, first run, dispatch rules, verbatim vault, layout, known limits |

## Still open

| Item | Status |
|---|---|
| **`SpeakerSelector` / round-robin dispatch** | **Blocked on the dispatch contradiction below.** Do not build before it is settled. |
| Trusted typing | Lib typing is JS-synthetic (`page_script.dart`). CDP `Input.insertText` proven in `tool/cdp_smoke.dart`, **0 uses in `lib/`** → fails any `isTrusted` check. Not needed for the sites Agora targets, but it is a real limit. |
| Gemini / DeepSeek end-to-end | JSON validates and the framework runs them in the sandbox, but neither has been driven against the **real** site — that needs the user's own logged-in profile. ChatGPT has the same gap. |
| Onboarding wizard | Not built. First run currently depends on reading the README. |
| Calibration Studio live probing | Loads, validates and displays adapter JSON. Does not yet probe a live page to suggest selectors. |
| Journal replay (Time Machine) | `journal_events` has a writer via `CouncilRunner._onEvent`; nothing replays it into the Sandbox Lab yet. |
| `linux/**` excluded from analysis | An AppImage-targeting app that never analyzes its own Linux runner. Surfaced, not changed — enabling it may surface a wall of lints in unreviewed code. |
| `tool/dbg2.dart` | Untracked scratch carrying the only 2 analyzer warnings. Not deleted: **another agent works in this monorepo concurrently**, and an untracked file may be theirs. |

## The decision that blocks the remaining engine work

**Dispatch model — unresolved.** `PLAN.md` §2.4/§8 (`PLAN APPROVED`) = invite-only, one
named agent, free text never dispatches, delegates cannot invite. `PLAN-GROUPCHAT.md` D1
(`PROPOSED`, untracked) = round-robin broadcast, leader may force a speaker, no
@-mention protocol.

**Code follows `PLAN.md`** — `orchestrator.dart:494` dispatches on `CouncilAction.invite`;
`:687` forbids delegate invites. The composer's `@`-chips say *"addressing … never
dispatches on its own"*, which is `PLAN.md` behaviour made visible.

`PLAN.md` wins (APPROVED > PROPOSED; GROUPCHAT is untracked). Build to `PLAN.md` unless the
user rules otherwise. **`SpeakerSelector` is the last piece that depends on this** and it
is wasted work under the wrong model — so it is the one thing left to ask about.

## Open questions (`PLAN.md` §17)

1. Per-agent daily message cap default. **Taken: 60/agent/day.** `UsageCounters` has a
   writer and the default is persisted in Settings (`agora.dailyCapPerAgent`).
2. Visible Chrome or background. **Taken: visible**, no tray minimisation yet — a real AI
   site can show a captcha or expire a login and the user must be able to see that.
3. Relay raw or leader-summarized. **Taken: raw** (`agora.relayRaw`).

All three are live toggles in Settings with the suggested defaults. No longer blocking.

## Not verifiable in this environment

There is **no pixel-level confirmation of the UI**. I cannot view images, and X11
`ffmpeg -f x11grab` grabs a black root window under Wayland, so `xdotool`/`wmctrl` also
find nothing (no EWMH under Wayland compositors, no Xvfb installed). What *was* verified:
the AppImage process starts, imports cleanly, creates its database, and stays alive. The
UI's own rendering is asserted only by `flutter analyze` and `flutter test`.
