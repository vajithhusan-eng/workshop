# Agora

[![Platform](https://img.shields.io/badge/platform-Linux-1793D1?logo=linux&logoColor=white)](#install)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-025EBA?logo=flutter&logoColor=white)](https://flutter.dev)
[![Tests](https://img.shields.io/badge/tests-290%20passing-brightgreen)](test/)
[![Analyzer](https://img.shields.io/badge/dart%20analyze-0%20issues-blueviolet)](analysis_options.yaml)
[![No telemetry](https://img.shields.io/badge/telemetry-none-success)](README.md)
[![Local-first](https://img.shields.io/badge/data-stays%20on%20your%20machine-informational)](#the-verbatim-vault)

**A multi-AI council for your own desktop.** You state a problem once, a leader AI
decomposes it and invites other AIs into a real debate, they critique and revise
until the leader declares it solved — and every word is kept **verbatim**.

Agora is a native Linux desktop app. It has no server, no cloud, no API keys and
no telemetry. It drives the AI websites you already have accounts for, through
your own Chrome, over the Chrome DevTools Protocol.

> **One session = one chat = one project.**

## Install

Two artifacts ship, and they are interchangeable — same binary, same 12 MB:

| Artifact | Needs FUSE to start |
|---|---|
| `agora-0.1.0-x86_64.AppImage` | yes, to self-mount |
| `agora-0.1.0-x86_64.tar.gz` | **no** |

```bash
# AppImage — single file, self-mounting
chmod +x agora-0.1.0-x86_64.AppImage
./agora-0.1.0-x86_64.AppImage

# Portable bundle — no FUSE, nothing to install
tar -xzf agora-0.1.0-x86_64.tar.gz
./agora-0.1.0-x86_64/agora
```

### If it says "Cannot mount AppImage, please check your FUSE setup"

An AppImage type 2 mounts itself through FUSE. Three unrelated things break that,
none of them Agora's fault:

- **Ubuntu 24.04 and later** ship `kernel.apparmor_restrict_unprivileged_userns=1`,
  which blocks unprivileged user-namespace mounts:
  `sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0`
- **Containers and sandboxes** deny the mount outright. `NoNewPrivs=1` also
  nullifies `fusermount`'s setuid bit, so a setuid `fusermount` does not save you.
- **`libfuse2` missing** — on Ubuntu 24.04 the package is `libfuse2t64`.

Either fallback works with FUSE switched off entirely:

```bash
APPIMAGE_EXTRACT_AND_RUN=1 ./agora-0.1.0-x86_64.AppImage
tar -xzf agora-0.1.0-x86_64.tar.gz && ./agora-0.1.0-x86_64/agora
```

Build from source:

```bash
flutter pub get
dart run build_runner build            # regenerate drift code after schema edits
./tool/build_appimage.sh               # emits both artifacts; needs appimagetool on PATH
```

## First run

1. Press **Convene** in the left sidebar and type a problem.
2. Agora opens Chrome **visibly** — a real AI site can show a captcha or expire a
   login, and you have to be able to see and fix that.
3. Chrome uses a **dedicated profile** at `~/.config/agora/chrome-profile`, not
   your everyday one. Sign in to ChatGPT, Gemini and DeepSeek **once**; the
   cookies persist and you will not be asked again.
   (Chrome 136+ refuses `--remote-debugging-port` on the default user-data-dir,
   so a separate profile is a security requirement, not a preference.)
4. Pick a leader in the council panel, then **Start the council**.

## How a debate runs

Dispatch follows one rule: **Agora never guesses.**

- Only a strict machine-readable `invite` block inside the leader's reply
  dispatches anything.
- Free prose never dispatches. Typing `@gemini` in the composer *addresses* that
  agent; it does not send them a turn.
- A delegate cannot invite. Only the leader can.
- Invites and rounds are hard-capped by `BudgetGuard`, and the daily cap per
  agent is persisted, so a crash loop cannot quietly blow past it.

## The verbatim vault

Every message is stored exactly as captured — raw text, raw HTML, a screenshot,
and a 128-bit content hash. Nothing is trimmed, summarised or reformatted on the
way in or out.

The transcript has three views per message:

- **Raw** — the bytes as received.
- **Rendered** — Markdown, for reading.
- **Plain** — Markdown markers stripped, **content untouched**.

A shield icon on each message re-checks the stored hash against the stored bytes.
If it ever turns into a broken shield, something rewrote the vault and Agora has
broken its own promise. **Session → Export** produces a Markdown Decision Record
containing the verdict, the round log and the full evidence chain with a
per-message integrity verdict.

## Layout

```
lib/
  core/
    adapters/     adapter framework + the JS page kernel
    cdp/          raw CDP over WebSocket
    chrome/       launcher, dedicated profile, paths
    council/      TabPool + CouncilRunner  (the only code that knows Chrome AND SQLite)
    orchestration/ protocol, budget, convergence, prompt compiler, firewall
    util/         hashing
  data/           drift schema v3 + SessionRepository
  state/          AgoraController
  ui/             theme, sidebar, transcript, council panel, composer, screens
  app.dart        Riverpod wiring
```

`orchestration/` is storage-free and browser-free so it can be tested with fake
adapters. `council/` is the seam: it launches Chrome, opens one tab per seat,
hands the adapters to the orchestrator, and writes every word to the vault as it
is captured.

## Adapters are data, not code

`assets/adapters/{chatgpt,gemini,deepseek}.json` hold every selector the page
kernel needs. When a site redesigns, you edit JSON — no app release. The
**Calibration Studio** (left rail) loads, validates and displays them; a tab
whose config fails validation blocks that seat's council with a sentence
explaining why, rather than a stack trace.

## Tests

```bash
flutter test                              # unit + repository suite: 290 passed, 1 skipped
dart analyze                              # 0 errors, 0 warnings, 0 info

dart run tool/sandbox_smoke.dart          # 42 checks against a mock AI site in real Chrome
dart run tool/focus_probe.dart            # proves the anti-throttling CDP calls still work
```

The `tool/` harnesses need a real Chrome and are **manual and opt-in**. They are
deliberately not wired into CI.

## On disk

| Path | What |
|---|---|
| `~/.config/agora/` | root |
| `~/.config/agora/agora.sqlite` | the database |
| `~/.config/agora/chrome-profile` | the dedicated Chrome profile |
| `~/.config/agora/adapters/` | user adapter overrides, hot-reloaded |
| `~/.config/agora/vault/<session>/` | screenshots and snapshots |
| `~/.config/agora/logs/` | logs |

Nothing leaves your machine.

## Known limits

- **One live council at a time.** Each agent is a Chromium tab at 150–300 MB.
- **Time Machine has no in-app UI.** The replay engine
  (`lib/core/council/journal_replay.dart`) and a manual harness
  (`tool/journal_replay.dart`, which replays a captured session against the
  Bundled Sandbox Lab) both exist — there is simply no button for it yet.
- **Live-site verification is partial.** The shipped ChatGPT, Gemini and DeepSeek
  configs validate and drive the mock site end to end; a recorded run against each
  *logged-in real* site does not exist yet.
- Verified against Chrome 154 on Linux/Wayland.

## Design

`PLAN.md` is the plan of record (`Status: PLAN APPROVED`) and is binding.
`PLAN-GROUPCHAT.md` is a **proposed** amendment and is **not** ratified; where it
contradicts `PLAN.md`, `PLAN.md` wins. `ARCHITECTURE-legacy.md` documents a
deleted Python backend and must not be built against.
