# Changelog

All changes to Agora, newest first. Entries quote the commit that carried them.

## 2026-10-17 — AppImage: a FUSE-free artifact and a real launch proof

The reported failure was `Cannot mount AppImage, please check your FUSE setup.` It was
diagnosed rather than guessed at, and the packaging script now ships a second artifact.

- **Not a missing library.** `libfuse.so.2` is present, `/dev/fuse` exists, and
  `/usr/bin/fusermount3` is setuid root. The cause is `NoNewPrivs=1` in the session, which
  nullifies the setuid bit; Ubuntu 24.04's `kernel.apparmor_restrict_unprivileged_userns=1`
  breaks it the same way outside a container.
- **`tool/build_appimage.sh` now emits a portable tarball** alongside the AppImage
  (`build/agora-0.1.0-x86_64.tar.gz`). A type-2 AppImage that cannot mount cannot start at
  all; the tarball is the same bundle and needs nothing beyond the libraries beside the
  binary (`$ORIGIN` RPATH). It is the only runnable form on a locked-down host.
- **Payload proved by extraction:** `--appimage-extract` → a complete `squashfs-root`
  containing `AppRun`, the `agora` ELF pie executable, `data/`, `lib/` and `usr/`.
- **Launch proved without FUSE:** `xvfb-run -a ./AppRun` ran the full 30 s timeout (exit
  124 — alive, not crashed), logged the Impeller/OpenGLES backend, and created
  `~/.config/agora/agora.sqlite` at `user_version 3` with all 14 tables including the FTS5
  set. The tarball path and `APPIMAGE_EXTRACT_AND_RUN=1` were verified identically.
- Closes the gap the 2026-10-17 build entry recorded: launch had been unrepeatable since
  FUSE was denied and was last verified 2026-10-10.

## 2026-10-17 — 45 dead `~/.local/bin` shims quarantined (machine fix)

This is what actually unblocked `flutter build linux`; the repo-side guard is only a
backstop. Nothing in the repository changed — the shims live in the user's home.

- Measured, not assumed: of the **46** files in `~/.local/bin` with a
  `#!/usr/bin/python3` shebang, **45 were dead** (`ModuleNotFoundError` /
  `No module named`). The survivor, `vba_extract.py`, is pure stdlib and runs on 3.14.
- **`ninja` was not one of them.** It is a real ELF binary shipped by the `ninja`
  package and always ran; an earlier note claiming it was "shadowed the same way" as
  `cmake` was wrong and has been corrected.
- Moved the 45 dead shims to `~/.local/bin.broken/`. Reversible:
  `mv ~/.local/bin.broken/* ~/.local/bin/`.
- Effect: `command -v cmake` → `/usr/bin/cmake` (4.2.3), and a bare
  `flutter build linux --release` succeeds with an **unmodified `PATH`**.
- Side effect: `pip`, `pip3`, `black`, `pytest`, `uvicorn`, `tqdm`, `httpx`,
  `websockets`, `watchfiles`, `coverage`, `alembic`, `django-admin` and the rest are now
  **absent** from `PATH` rather than present-and-broken. None worked before, so nothing
  regressed. Use a project venv (`backend/.venv`, `projects/rgx/.venv`), or
  `python3 -m ensurepip --upgrade` to get pip back.
- No repository tooling referenced any of them (`grep` over the Makefiles and CI found
  nothing). Re-verified after the move: `make check` exit 0 · backend `143/143` · agora
  `flutter analyze` clean, 290 tests, `cpp_lint.sh` PASS · rgx 47 passed / 6 skipped ·
  frontend 165 passed.

## 2026-10-17 — Linux build and AppImage packaging unblocked

Both were recorded as blocked since 2026-10-06. Neither blocker was real.

- `tool/cpp_lint.sh` → **PASS**, 5 files, 0 errors, 0 warnings, exit 0. The
  `libgtk-3-dev` / `libglib2.0-dev` absence no longer reproduces; `pkg-config
  gtk+-3.0` resolves GTK 3.24.52 and glib 2.88.0.
- `flutter build linux --release` → **PASS**. Its `cmake` traceback was never a
  missing package: a stale `pip install --user` shim at `~/.local/bin/cmake`,
  installed under Python 3.12 (the system has since moved to 3.14), still resolves
  on `PATH` but exits with `ModuleNotFoundError`, shadowing a working
  `/usr/bin/cmake 4.2.3`. (`ninja` was suspected too, but it is a real ELF binary in
  `~/.local/bin` and always ran; `/usr/bin/ninja` is fine as well.)
  `tool/build_appimage.sh` now detects a tool that resolves but does not run and
  falls back to `/usr/bin`, printing a note instead of dying.
- AppImage packaging runs `appimagetool`, itself an AppImage, which needs FUSE;
  mounts are denied here, so the script retries with `APPIMAGE_EXTRACT_AND_RUN=1`
  after a FUSE failure.
- Rebuilt `build/agora-0.1.0-x86_64.AppImage` — **12 MB**.

## 2026-10-17 — analyzer scope + lint sweep (Agora)

`dart analyze` on the package went from **20 errors + 197 info (exit 3)** to
**`No issues found!` (exit 0)**.

- Every one of the 20 errors was in the gitignored `tool/` probe scratch
  (`check_load*.dart`, `debug3.dart`, `debug_connect*.dart`, `probe_fix.dart`) —
  dead helpers written against an abandoned API. The scratch is kept on disk by
  decision, so `analysis_options.yaml` now excludes **the same globs as
  `.gitignore`**. That is a scope fix, not a suppression: the files are not part of
  a checkout, and the analyzer was the only thing still policing them.
- `dart fix --apply` cleared 34 findings; the remaining 24 were fixed by hand:
  `print` → `stdout.writeln` in `tool/focus_probe.dart` (12) and
  `tool/registry_check.dart` (4); `_isLeader` + getter/setter collapsed to one
  mutable `bool isLeader` field in `lib/core/orchestration/orchestrator.dart`;
  `_HOME_NOTE` → `_homeNote`; `r_scoreSeries` → `rScoreSeries`; `FakeAgent.close()`
  now closes the two `StreamController`s it owns; two `exists()` → `existsSync()` in
  `lib/core/adapters/adapter_registry.dart`.
- **Genuine bug fixed.** The Verbatim hash check in `tool/sandbox_smoke.dart`
  compared a `String?` to a `bool`, so it was vacuously true and asserted nothing.
  It now asserts `contentHash == contentHash(rawText)`, which is the guarantee
  `SessionRepository.isIntact` relies on.
- `flutter test` 290 passed / 1 skipped; `flutter analyze` clean.

## 2026-10-17 — documentation standard, and Amendment R1

- `0707233` feat(agora): Amendment R1 channels, silent Chrome, conversation UI and tests
  Protocol parser for all five actions, the sender table, `SpeakerSelector`, drift
  v3 `channels` + `messages.channel_id`, per-thread journaling, silent Chrome mode
  with reveal, slash composer, conversation chips with avatar stacks / presence
  dots / count-cursor unread, convergence card and graph.
- `2cc557d` fix(make,docs): make `make push` report failures; correct the `tool/` scratch note
- `3e3aeae` chore(tooling): track the dev supervisor, docs-check and C++ lint scripts
- `d504935` docs: add monorepo and per-project orientation docs
- Added `docs/README.md` and this changelog. `STATE.md` re-verified:
  `flutter test` **290 passed / 1 skipped**, `dart analyze lib/ test/` **62 info,
  0 warnings, 0 errors**.

## 2026-10-06 — Amendment R1 ratified

- `76233ad` docs(agora): ratify amendment R1 — channels, silent Chrome, opencode × WhatsApp UI
  Closes the dispatch contradiction. Round-robin was adopted, but as `broadcast`
  under the approved plan rather than as `PLAN-GROUPCHAT.md` D1. Supersedes
  §2.4, §8, §11 and §17 where they conflict.
- `ce31de1` feat(agora): live real-site check tool, page text dumper, vision note

## 2026-10-03 — the build-out (43 commits)

The day Agora went from scaffold to a working app. Highlights:

- `ceb4a49` **UI mounted** — three-pane council room, `@`-routing composer,
  calibration studio, decision record, settings
- `a233db1` "Start the council" runs for real, with live progress, a stop button
  and a blocked-reason card; `96e7fdb` real snapshot (Ctrl+S) and interrupt (Esc)
- `3a1dfe8` `TabPool` + `CouncilRunner`; `d1014cd` orchestrator state machine;
  `b2f67e9` the 57-test orchestration suite, previously untracked
- `32fe89b` `SessionRepository`; `91e6dc7` schema v2 + hot-query indexes;
  `e28b4a0`, `f3527a6`, `96846af` index-DDL fixes
- `33a9d9e` prompt compiler (B1 delta packets, D1 brief) + safety firewall
- `49bf0ae`, `b825f93`, `d86045c` `SelectorProber` — ask a real page what each
  selector actually resolves
- `e4633fc` Time Machine — journal dispatch/capture and replay against the Sandbox Lab
- `7bd2f67` 10 replay tests; `b2f67e9` the 57-test orchestration suite
- `e6ace6c` onboarding wizard; `fb5b873` `LoginChecker`
- `20359ab`, `d7a7426` defeat background-tab throttling
- `08fa086` AppImage packaging — desktop entry, metainfo, icon, AppRun, build script
- `d5921b1`, `1baa1de`, `62db429` documentation brought back in line with the code

## 2026-09-30 — the adapter framework

- `bd7c5fb` adapter framework: data-driven config model + JS page kernel
- `e4a2d9c` real adapter configs for ChatGPT / Gemini / DeepSeek (3/3 validate)
- `84a551c` adapter registry — bundled + user JSON overlay, hot reload, graceful skip
- `7a1a346` adapter config contract, drift codegen, agent + web adapters
- `23bdc2c` Sandbox Lab — mock AI site fixture + full adapter e2e smoke test
- `639cde5` sandbox suite green: 42/42 e2e against real Chrome
- `a6ab401` CRITICAL: capture the answer baseline *before* the send click
- `bba6047` resolve all 20 analyzer errors

## 2026-09-28 — scaffolding

- `34c0220` P0 baseline: clean Flutter Linux desktop scaffold
- `a8857fe` P1 CDP engine, proven against real Chrome 154
- `cf9bd0b` Council Protocol parser + 24 passing tests
- `335e91b` restructure `story-app` into Agora
