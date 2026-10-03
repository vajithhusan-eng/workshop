# Agora

A multi-AI council for your own desktop. You state a problem once, a leader AI
decomposes it and invites other AIs into a real debate, they critique and revise
until the leader declares it solved — and every word is kept **verbatim**.

Agora is a native Linux desktop app. It has no server, no cloud, no API keys and
no telemetry. It drives the AI websites you already have accounts for, through
your own Chrome, over the Chrome DevTools Protocol.

> **One session = one chat = one project.**

## Install

Download the AppImage, make it executable, and run it:

```bash
chmod +x agora-0.1.0-x86_64.AppImage
./agora-0.1.0-x86_64.AppImage
```

Build it yourself from source:

```bash
flutter pub get
dart run build_runner build            # regenerate drift code after schema edits
./tool/build_appimage.sh               # needs appimagetool on PATH
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
  data/           drift schema v2 + SessionRepository
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
flutter test                              # unit + repository suite
dart analyze lib/ test/                   # 0 errors, 0 warnings expected

dart run tool/sandbox_smoke.dart          # 42 checks against a mock AI site in real Chrome
dart run tool/focus_probe.dart            # proves the anti-throttling CDP calls still work
```

The `tool/` harnesses need a real Chrome and are **manual and opt-in**. They are
deliberately not wired into CI.

## On disk

| Path | What |
|---|---|
| `~/.config/agora/` | root |
| `~/.config/agora/chrome-profile` | the dedicated Chrome profile |
| `~/.config/agora/vault/<session>/` | screenshots and snapshots |
| `~/.config/agora/logs/` | logs |
| `~/.local/share/dev.agora.agora/agora.sqlite` | the database |

Nothing leaves your machine.

## Known limits

- **One live council at a time.** Each agent is a Chromium tab at 150–300 MB.
- The onboarding wizard and live selector probing in Calibration Studio are not
  built yet.
- Journal replay (Time Machine) is not built yet.
- Verified against Chrome 154 on Linux/Wayland.

## Design

`PLAN.md` is the plan of record (`Status: PLAN APPROVED`) and is binding.
`PLAN-GROUPCHAT.md` is a **proposed** amendment and is **not** ratified; where it
contradicts `PLAN.md`, `PLAN.md` wins. `ARCHITECTURE-legacy.md` documents a
deleted Python backend and must not be built against.
