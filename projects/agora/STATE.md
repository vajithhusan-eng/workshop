# Agora — STATE

**Derived file.** Regenerate by verifying, not by trusting commit messages or this file.
**Verified:** 2026-10-17 · `HEAD 5df8f0b` · Flutter 3.47.0 / Dart 3.13.0 ·
`flutter test` 296 passed / 1 skipped; `dart analyze` and `flutter analyze` both
**`No issues found!` — 0 errors, 0 warnings, 0 info, exit 0.** Before this sweep a bare
`dart analyze` on the package reported **20 errors + 197 info**; every error, and all 22
of the tool/ infos, were in the ignored probe scratch. `tool/cpp_lint.sh` **PASS**
(5 files, 0 errors, 0 warnings) and `flutter build linux --release` **PASS** →
`build/agora-0.1.0-x86_64.AppImage`, 12 MB, plus a portable
`build/agora-0.1.0-x86_64.tar.gz` for FUSE-less hosts. `make docs-check` exit 0.

**Git hygiene (2026-10-17).** The working tree is clean. Everything formerly untracked
and load-bearing is now committed: `tool/cpp_lint.sh`, `PLAN-GROUPCHAT.md`,
`scripts/devsup.py`, `scripts/verify_docs.py`, the monorepo `AGENTS.md`, and the R1
sources + tests. `VISION.md` was deleted after `ce31de1` and **restored** byte-for-byte —
it holds the user's verbatim vision and the standing rule is add-only-never-delete. The
remaining `tool/` scratch (`run_*.dart`, `check_load*.dart`, `debug*.dart`, `dbg2.dart`,
`probe_fix.dart`) is **ignored, not deleted**, so a plain `git clean -fd` can no longer
destroy it. This STATE.md edit is deliberately **left uncommitted**: `verify_docs.py`
compares the working-tree pin against HEAD, so committing the pin would immediately
re-stale it. Do not "fix" that by committing this file.

**Analyzer scope (2026-10-17).** `analysis_options.yaml` now excludes those same five
scratch globs under `analyzer.exclude`. That is a *scope* fix, not a suppression: the
scratch is `.gitignore`d, so a checkout does not contain it, yet the analyzer was still
policing it and every one of the 20 errors it reported came from there. The exclusion
uses the identical globs as `.gitignore`. `dart analyze $(git ls-files 'tool/*.dart')`
remains the honest check for the tracked `tool/` sources. The remaining 24 real lint
findings in `lib/`, `test/` and the tracked tool sources were then fixed by hand —
including one genuine bug: `tool/sandbox_smoke.dart` compared a `String?` to a `bool`,
so its Verbatim hash check was vacuously true and asserted nothing; it now asserts
`contentHash == contentHash(rawText)`.

**Publish readiness (2026-10-17).** Three defects a clone would have hit are fixed.
(1) `.gitignore` no longer carries `*.g.dart`, so `lib/data/database.g.dart` (8149
lines) is tracked — a simulated clone without it reported **297 analyzer issues**, and
the scratch clone now analyzes clean and passes the full suite. (2) The Sandbox Lab
fixture no longer hard-codes a machine path: `tool/sandbox/adapter_sandbox.json` ships
`file://./tool/sandbox/mock_ai_site.html` and `AdapterConfig.fromJson` expands a
relative `file://` URL against the working directory at parse time (new
`test/adapter_config_test.dart` covers it). (3) `flutter_markdown 0.7.7+1` was
discontinued; migrated to `flutter_markdown_plus ^1.0.12` and took a full
`flutter pub upgrade` (29 packages), which cleared the *"1 package is discontinued"*
warning. `flutter test` is now **296 passed / 1 skipped** (the new test file adds 6).

## How to verify this file

```bash
cd projects/agora
flutter test          # 296 passed, 1 skipped, 0 failed
dart analyze          # No issues found! — 0 errors, 0 warnings, 0 info
tool/cpp_lint.sh      # 5 tracked C++ files, 0 errors, 0 warnings (GTK 3.24.52)
git log --oneline -1
```

Real-Chrome checks in `tool/` are **manual and opt-in** (`PLAN.md` §12). Never CI:

```bash
dart run tool/sandbox_smoke.dart   # 42 checks, mock AI site, real Chrome
dart run tool/focus_probe.dart     # anti-throttling + TabPool against real Chrome
./tool/build_appimage.sh           # builds the .AppImage + a portable .tar.gz
```

## Verified green

| Check | Result |
|---|---|
| `flutter test` | **296 passed · 1 skipped · 0 failed** |
| `dart analyze` / `flutter analyze` | **`No issues found!` — 0 errors · 0 warnings · 0 info · exit 0.** Before this sweep: 20 errors + 197 info, every error in the ignored `tool/` scratch, which is now excluded from analysis by the same globs as `.gitignore`. The 24 real findings that remained (print statements, a field-vs-getter/setter pair, a renamed constant and test helper, two unclosed `StreamController`s, two `exists()` calls, one vacuous type-equality assertion) were all fixed by hand. |
| Test inventory | 17 files — inc. `conversation_list_test.dart`, `conversation_state_test.dart`, `convergence_graph_test.dart`, `slash_commands_test.dart`, `chrome_mode_test.dart` |
| `dart run tool/sandbox_smoke.dart` | **42 passed · 0 failed** against real Chrome 154 |
| `dart run tool/focus_probe.dart` | **ALL OK** — focus emulation, `Page.bringToFront`, and all six `TabPool` paths |
| AppImage | `build/agora-0.1.0-x86_64.AppImage`, **12 MB**, rebuilt 2026-10-17 through the whole pipeline: `flutter build linux --release` → `appimagetool`, exit 0. Packaging needs `APPIMAGE_EXTRACT_AND_RUN=1` here because FUSE mounts are denied (`fusermount: mount failed: Operation not permitted`); `tool/build_appimage.sh` now retries that way automatically. The 2026-10-10 launch reading (from a FUSE mount: no exceptions, `agora.sqlite` at `user_version 2` with all 9 tables, FTS5 and all 4 hot-query indexes) has not been repeatable since FUSE was denied, so treat launch as last-verified at that date. |
| The 1 skip | `orchestrator_test.dart:494` — `stallForever is checked before mutation; kept as documentation`. Intentional, not hidden. |
| Ignored `tool/` scratch | `run_*.dart`, `check_load*.dart`, `debug*.dart`, `dbg2.dart`, `probe_fix.dart` — dead helpers against an older API, `.gitignore`d, kept on disk by decision (another agent works here concurrently and has destroyed untracked work before). Excluded from analysis in `analysis_options.yaml`; check the tracked sources with `dart analyze $(git ls-files 'tool/*.dart')`. |
| `tool/cpp_lint.sh` | **PASS — 5 files, 0 errors, 0 warnings, exit 0** (GTK 3.24.52, glib 2.88.0, `clang++ -fsyntax-only -Wall -Wextra`). The 2026-10-06 reading — "blocked, exits 2: `libgtk-3-dev`/`libglib2.0-dev` were removed" — **no longer reproduces**; the dev packages are present again and `pkg-config gtk+-3.0` resolves. |
| `flutter build linux --release` | **PASS**, exit 0, `build/linux/x64/release/bundle/agora` — now with an **unmodified `PATH`**. It used to fail with a `cmake` traceback, which was *not* a missing-package problem: `pip install --user` shims in `~/.local/bin` (installed under Python 3.12, which the system has since replaced with 3.14) resolved on `PATH` but died with `ModuleNotFoundError`, shadowing the working `/usr/bin/cmake` 4.2.3. Measured 2026-10-17: **45 of the 46** Python shims were dead (`vba_extract.py` survives — it is pure stdlib) and were **quarantined to `~/.local/bin.broken/`** (reversible: `mv ~/.local/bin.broken/* ~/.local/bin/`). `ninja` was never affected — it is a real ELF binary. `tool/build_appimage.sh` additionally detects a shim that resolves but does not run and falls back to `/usr/bin`, in case any come back. |

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
| **`SpeakerSelector`** | **BUILT.** Amendment R1 §18.1 released it; it now selects the next speaker from the channel table (invite target, broadcast set, or dm target), never from free text. `lib/core/orchestration/speaker_selector.dart` + `test/speaker_selector_test.dart` (24 tests). |
| **R1 build list (§18.5)** | **PART DONE.** Built: protocol parser for all five actions · orchestrator sender table + channel-aware `MessageCaptured`/`PacketDispatched` · `channels` + `messages.channel_id` (drift v3) + repo CRUD · the engine journals each message into the right §18.1 thread · silent Chrome `agora.chromeMode` + reveal · slash-command composer · **conversation chips with real avatar stacks, presence dots and unread badges (count-cursor read state)**. **Remaining:** the full §18.3 HUD (per-agent context-pressure meters, model picker, adversarial/fork/template — those engines do not exist) and conversation search/pin · ✓/✓✓ read receipts (impossible without site integration) · §18.5.5 UI widget tests beyond the chip and the convergence card. |
| **§18.1 public-thread mapping** | Public messages are stored with a **null** `messages.channel_id`, while `ensurePublicChannel` still materialises the `ch:$sessionId:public` row so the chat list has a conversation. The UI passes `null` for the public chip. This is deliberate — do not "fix" the public thread to filter on its own id. |
| Trusted typing | Lib typing is JS-synthetic (`page_script.dart`). CDP `Input.insertText` proven in `tool/cdp_smoke.dart`, **0 uses in `lib/`** → fails any `isTrusted` check. Not needed for the sites Agora targets, but it is a real limit. |
| Gemini / DeepSeek / ChatGPT end-to-end | JSON validates and the framework runs them in the sandbox, but none has been driven against the **real** site — that needs the user's own logged-in profile. **The tooling for it now exists** (`ce31de1`): `dart run tool/live_check.dart` does a read-only login check against `~/.config/agora/chrome-profile`, and `... council` runs one live council that writes genuine rows to the real vault; `tool/page_text.dart` dumps page text. **Neither has been executed yet** — `review.json` is still `{"armed": false}`. |
| Onboarding wizard | **CLOSED** | `lib/ui/onboarding_screen.dart` + `test/onboarding_test.dart` |
| Calibration Studio live probing | **CLOSED** | `lib/core/adapters/selector_prober.dart` + `test/selector_prober_test.dart`; `SelectorProber` reports which selector tier actually resolved on a live page |
| Journal replay (Time Machine) | **CLOSED** | `lib/core/council/journal_replay.dart` + `test/journal_replay_test.dart`; replays captured turns into the Sandbox Lab, with FIFO pairing, drift detection, and skip-vs-fail |
| ~~`linux/**` excluded from analysis~~ | **RESOLVED — the exclusion was a no-op, and the real gap is now closed.** `dart analyze` reads only `.dart` files and `linux/` has zero, so removing the exclusion changed the result by nothing (74 issues either way). The C++ runner was checked by no tool. Added `tool/cpp_lint.sh`: `clang++ -fsyntax-only -Wall -Wextra` over git-tracked `linux/` C++ only, with every flag (`APPLICATION_ID`, `BINARY_NAME`, GTK via `pkg-config`, plugin includes) derived from the files CMake actually reads. It found 2 real `-Wunused-parameter` warnings in `my_application.cc`, now fixed. **5 files, 0 errors, 0 warnings.** |
| `tool/dbg2.dart` | Untracked scratch, **now fully clean** — both warnings removed 2026-10-06: the unused `council_protocol.dart` import, and `@override` on `AgentAdapter get adapter` (a getter `AgentAdapter` never declares, hence `override_on_non_overriding_member`; the getter itself is legal and kept). Not deleted: **another agent works in this monorepo concurrently** and has destroyed untracked work here before, so an untracked file may be theirs. |
| **Dispatch model** | **RESOLVED by Amendment R1 (§18, ratified 2026-10-06).** See below — this was the blocking contradiction. |

## Dispatch model — RESOLVED by Amendment R1

**The blocking contradiction is closed.** `PLAN.md` **§18 (Amendment R1)** was ratified by
the user on 2026-10-06 and governs where it conflicts with §2.4, §8, §11 or §17. It also
makes `PLAN-GROUPCHAT.md` D1 moot — round-robin is now ratified *explicitly* as
`broadcast` under an approved plan, rather than argued from an untracked amendment.

| Action | Channel | Allowed senders |
|---|---|---|
| `invite` | public | leader only |
| `broadcast` | public | leader only |
| `dm` | private | **any participant** |
| `decide` / `comment` / `need_input` | public | leader only |

The non-negotiable is unchanged: **all dispatch comes from strict machine-readable blocks
— free text never dispatches.** What changed is that §2.4's "delegates may not invite" ban
is *replaced* by the table: delegates may `dm` privately, only the leader opens public
rounds.

**`SpeakerSelector` is explicitly unblocked** — §18.1: *"thereby unblocked — it selects the
next speaker according to this table (invite target, broadcast set, or dm target), never
from free text."*

**The §18.5 build list has landed** (2026-10-10). `CouncilProtocol` parses all five actions;
`Orchestrator._dispatch` runs the sender table and carries a `channelKey` on
`MessageCaptured`/`PacketDispatched`; `CouncilRunner` journals each message into the right
§18.1 thread (`channels` + `messages.channel_id`, drift v3); the centre pane reads the
selected thread; the composer has a real slash-command surface; Chrome can start silent with
reveal; the conversation chips carry real avatar stacks, presence dots and unread badges
(read state is a per-thread message **count**, not a timestamp — drift's `createdAt` is
whole seconds). Still open: the full §18.3 HUD and §18.5.5 UI widget tests.

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
