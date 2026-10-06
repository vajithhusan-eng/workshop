# Agora — Master Plan

**Multi-AI Council Orchestrator · Native Ubuntu Desktop App · AppImage**
Status: PLAN APPROVED (stack locked) · Date: 2026-09-28 · **Amended 2026-10-06 — R1**
(ratified: private + public channels, silent Chrome, opencode × WhatsApp UI, live
identity seeding — §18 supersedes the earlier dispatch reading where they conflict)

---

## 0. TL;DR

One native Linux app. You type your problem once. A **leader AI** (ChatGPT, Gemini or
DeepSeek — whichever you pick) breaks the problem down and **invites other AIs into the
discussion**. They debate, critique and revise until the leader declares the problem solved.
Every agent runs in a real tab of your own logged-in Chrome. Every word an AI says is stored
**verbatim** — Agora never rewrites, shortens or "improves" their output.

One **session = one chat = one project**. Sessions are separate, editable, deletable.

You get a `.AppImage` file. Double-click. Native GTK window. No browser tab, no localhost
server, no Docker, no Python.

---

## 1. Your story → requirements

| # | What you said | Requirement |
|---|---|---|
| 1 | "asked ChatGPT, then Gemini, DeepSeek… copy-paste is slow and wrongly pasted" | Multi-agent orchestration, zero manual copy-paste |
| 2 | "connect multiple AI agents using web URL connection" | Drive real AI websites via your own Chrome profile |
| 3 | "fast and keep up to new trend" | Sub-second control loop; survives AI-site UI redesigns |
| 4 | "vajithhusan@gmail.com chrome browser profile" | Reuse your real logins — no API keys, no signup |
| 5 | "agent communicate infinitely until the problem is solve" | Leader-driven multi-agent loop with intelligent termination |
| 6 | "user can specifically use one AI … and leader role" | Choose which AI leads, per session |
| 7 | "session based, one session = one chat, every session separate project" | Session = project |
| 8 | "sessions can edit and delete" | Full session CRUD |
| 9 | "with their original chat length and style without changing their output" | Verbatim capture, zero transformation |
| 10 | "ubuntu linux app image mainly, not web app" | Native desktop → AppImage |
| 11 | "add your upgrade ideas too" | See §6 — 27 upgrades beyond the original idea |

---

## 2. Non-negotiable design rules

1. **Verbatim.** Store raw text + raw HTML + screenshot. Render as-is. Toggle Raw/Rendered/Plain.
   Agora's own words are always visually distinct from agent words.
2. **One live session at a time.** Bounds memory (each agent = a Chromium tab ≈ 150–300 MB).
   Other sessions are stored transcripts you can resume.
3. **Adapters are data, not code.** Selectors live in versioned JSON. A ChatGPT redesign
   must never require an app release.
4. **The orchestrator never guesses.** Invites come from a strict machine-readable block.
   Free-text never triggers a dispatch. Channel model per §18: `invite`/`broadcast`
   (public, leader-gated) and `dm` (private, any participant) — all still machine-readable
   blocks, never prose.
5. **Local-first.** SQLite on disk. No Agora server. No telemetry. Air-gap capable except for
   the AI sites themselves.

---

## 3. Architecture

```
┌─────────────────── Agora.AppImage (single native process) ────────────────────┐
│                                                                            │
│  UI LAYER (Flutter/Riverpod)          ENGINE LAYER (Dart isolate)          │
│  ┌──────────────────────────┐        ┌────────────────────────────────┐   │
│  │ Sessions · Council view  │◀──────▶│ Orchestrator (state machine)    │   │
│  │ Settings · Calibrate     │  typed │ TurnQueue (serialized)          │   │
│  │ Decision log             │  event │ BudgetGuard (rounds/time/tokens)│   │
│  └──────────────────────────┘  bus   │ ConvergenceScorer              │   │
│                                     │ CouncilProtocol parser          │   │
│  CORE                              │ PromptCompiler                  │   │
│  ┌──────────────────────────┐      │ ContextStrategist               │   │
│  │ ChromeLauncher           │      │ AdapterRegistry (hot-reload)   │   │
│  │ CdpClient (Dart WS)      │      │ AdapterHealer (auto-repair)    │   │
│  │ Storage (SQLite/drift)   │      │ VerbatimVault (raw+html+shot)  │   │
│  │ Journal (replay/debug)   │      │ SafetyFirewall (redaction)      │   │
│  └──────────────────────────┘      └────────────────────────────────┘   │
└──────────────────────────────────┬─────────────────────────────────────────┘
                                   │ Chrome DevTools Protocol (WebSocket, :9222)
                         ┌─────────▼──────────────────────────────────────┐
                         │  SYSTEM CHROME — dedicated Agora profile      │
                         │  /home/vajith/.config/agora/chrome-profile     │
                         │  tab: chatgpt.com  |  gemini.google.com  | ... │
                         └────────────────────────────────────────────────┘
```

**Why this shape:** a local WebSocket-to-self backend (the old FastAPI design) is pointless
overhead, and bundling a Python runtime inside an AppImage is a packaging nightmare. One
process, one binary, zero IPC.

---

## 4. The three hard problems

### 4.1 "Use my Chrome profile"
Modern Chrome (136+) **refuses** `--remote-debugging-port` on the *default* `--user-data-dir`.
This is a security fix, not a bug, and cannot be worked around.
→ **Solution:** Agora owns a dedicated profile at `~/.config/agora/chrome-profile`. You log in
to each AI site once (Google, OpenAI, DeepSeek). Those cookies persist forever. Agora launches
`google-chrome` with that dir + `--remote-debugging-port=9222`.
→ **Alternative** if you insist on your everyday profile: a Chrome extension + Native Messaging
bridge. Downside: extension install friction, and the browser must be open. Offered as a
fallback mode (`transport: extension`) because the adapter interface hides the difference.

### 4.2 "Agents talk until it's solved"
Free-text detection of "let me ask Gemini" is unreliable, and an unbounded loop burns quota
and your afternoon. Agora replaces vibes with a **protocol + a convergence score** (§8, §9).
Termination is decided by *evidence* (round-over-round answer similarity + per-agent confidence
votes), not by the leader's opinion alone.

### 4.3 "AI websites change their UI constantly"
This is guaranteed, not hypothetical. Every A-class bug in this app will be a broken selector.
→ Selectors in hot-reloadable JSON + an in-app **Calibration Studio** + an **Adapter Healer**
that dumps the DOM, proposes a fix from aria-label/text heuristics, and offers one-click apply
+ a **remote signed adapter update channel** so fixes ship without an AppImage release.

---

## 5. Core features (your idea, made real)

1. **Session = project.** Create / rename / edit settings / delete / archive / duplicate.
   Per-session: leader agent, participant set, role cards, round cap, time budget, context strategy.
2. **Leader election.** Any participant can be leader. Changeable mid-session.
3. **Invite & dispatch.** Leader emits a structured invite; Agora routes it to the target agent
   with a compiled context packet.
4. **Council transcript.** You see every message, from every agent, in one thread, colour-coded
   by agent, with round numbers.
5. **Verbatim storage.** Raw text, raw HTML, optional screenshot, per message.
6. **Session CRUD + search** (SQLite FTS5 full-text).
7. **Export** to Markdown / JSON / HTML. **Import** a session.
8. **AppImage** distribution.
9. **Onboarding wizard**: pick agents → log in each → verify → done.

---

## 6. Upgrades beyond your idea

### A. Turning a debate into a *decision*

| # | Upgrade | Why it matters |
|---|---|---|
| A1 | **Role Cards** — assign each participant a role (Architect, Reviewer, Physicist, Devil's Advocate, Fact-Checker, Implementer) | Kills groupthink. Five generalists agree; a critic and an implementer don't. |
| A2 | **Adversarial Round** — a mandatory round where a named agent must *refute* the current best answer | The single highest-value upgrade. Finds the flaws the leader rationalized away. |
| A3 | **Consensus Scoring** — every agent rates the candidate answer 0–10 with a confidence and a reason | Turns "I think it's fine" into a measurable spread. |
| A4 | **Convergence Graph** — plots answer similarity + mean score per round | You *see* when the council has stopped making progress. |
| A5 | **Decision Record export** — final answer + full evidence chain + round log as Markdown/PDF | Turns a chat into an engineering artifact you can defend later. Your battery-tech idea becomes a documented decision, not a lost thread. |

### B. Making it fast and honest

| # | Upgrade | Why it matters |
|---|---|---|
| B1 | **Delta Packets** — each round sends only what *changed* since last round | Web chats have hard context limits. Deltas are 5–10× cheaper and keep late rounds accurate. |
| B2 | **Context Pressure meter** — live estimate of remaining context per agent | Silent truncation is the #1 cause of hallucinated "agreements". Make it visible. |
| B3 | **Stagnation detector** — auto-stop on repeated near-identical answers | Directly fixes "infinity until solved". |
| B4 | **Rate-limit & CAPTCHA awareness** — detect 429 / "I'm not a robot" / quota walls, pause, notify, auto-resume | Otherwise one bad run silently kills the council. |
| B5 | **Journal & Time Machine** — record every action (navigate/type/send/extract) and replay a session without touching real sites | Debugging, plus regression tests against recorded runs. |
| B6 | **Sandbox Lab** — built-in mock AI websites (ChatGPT/Gemini clones) that imitate the real DOM | Test the whole system with zero real accounts, zero quota. |
| B7 | **Adapter regression suite** — recorded DOM fixtures; a test fails when a site changes | Turns "the app is broken today" into a CI signal. |

### C. Trust & safety

| # | Upgrade | Why it matters |
|---|---|---|
| C1 | **Cross-agent prompt-injection firewall** — relayed content is fenced and tagged; suspicious instructions from Agent A aimed at Agent B are flagged | Agent A can write "ignore previous instructions" into its answer. Agora must not launder that into Agent B. |
| C2 | **PII redaction preview** — detect and mask emails, keys, phone numbers before relaying to another vendor | Your gmail is one of the logins. Cross-vendor leakage is real. |
| C3 | **Verbatim Vault** — every message's raw HTML + screenshot, immutable, with a hash chain | If Agora ever "changes" someone's output, you can prove it didn't. Directly serves your requirement #9. |
| C4 | **No telemetry, ever** — with a visible "network activity" panel showing exactly which hosts Agora talks to | Trust a tool that shows its work. |

### D. Power-user quality of life

| # | Upgrade | Why it matters |
|---|---|---|
| D1 | **Prompt Compiler** — your messy 400-word thought → structured packet (Objective / Constraints / Deliverables / Acceptance criteria / Known unknowns) | Turns ramble into something 3 AIs can actually work on. |
| D2 | **Voice composer (hold-to-talk)** — dictate long prompts | Your #1 complaint was tedious copy-paste. Speaking beats typing. |
| D3 | **Side-by-side comparison view** — N answers to the same question, semantic diff highlighting | Decision-making, not just conversation. |
| D4 | **Session Fork / Time-travel** — branch from any message into a new session, re-run with a different leader or agent set | `git branch` for AI conversations. Answers "what if I had asked Gemini to lead?" |
| D5 | **Session Templates** — save "Battery chemistry design review" as a one-click template with roles + agents + leader | Repeated workflows become instant. |
| D6 | **Command palette (Ctrl+K)** + full keyboard control | Speed for power users. |
| D7 | **Local analytics** — which agent wins at which task type, over your own history | "Gemini is better on physics, GPT-5 on code" — discovered from your own data, not marketing. |
| D8 | **Desktop notifications** when the council finishes | Long runs shouldn't require babysitting. |
| D9 | **Model picker automation** — choose GPT-5 vs Claude vs Gemini model from each site's own model selector | Model quality changes monthly; the control belongs in the app. |
| D10 | **Agent marketplace / plugin format** — adapter JSON + role cards as shareable files | Community can fix a broken adapter in 10 minutes without forking. |

### E. One structural upgrade worth calling out

**Fractal Memory.** Web AI chats have fixed, small context windows and refuse to be told
otherwise. Agora's answer: each agent gets a **fresh chat per round**, rehydrated from a
project-scoped Memory that Agora maintains itself — a designated "Archivist" agent compacts the
round's essentials into structured facts, which are re-injected as the preamble next round.
Result: a 50-round council doesn't collapse at round 12. This is the difference between a toy
and something you'd actually use on a battery design.

---

## 7. Data model (SQLite / drift)

```sql
sessions(id, title, created_at, updated_at, archived,
         leader_agent_id, max_rounds, time_budget_sec, context_strategy,
         status, seed_prompt, template_id)

agents(id, session_id, kind, display_name, url, model_label, color,
       role_card, is_leader, status, login_ok, tab_id, adapter_version)

messages(id, session_id, round, agent_id, direction,      -- 'out' | 'in'
         role,                                            -- user|agent|system|orchestrator
         raw_text, raw_html, rendered_md, screenshot_path,
         content_hash, created_at, latency_ms, packet_ref)

invites(id, session_id, round, from_agent_id, to_agent_id, task,
        expect, context_ref, dispatched_at, returned_at, status)

packets(id, session_id, round, target_agent_id, strategy, bytes, body_hash, body)

agents_memory(session_id, fact, source_message_id, created_at, pinned)

events(id, session_id, ts, kind, payload_json)            -- journal / replay / analytics
adapters(id, provider, version, json, installed_at, verified_at)
```

Verbatim guarantee: `content_hash` + immutable `raw_text`/`raw_html`. Any UI rendering is a
*view*, never the source of truth.

---

## 8. The Council Protocol

The leader is instructed (once, per session) to end every reply with a fenced block. This is
the **only** thing Agora parses. Anything else is treated as prose.

````text
```council
{
  "action": "invite",              // or "decide" | "comment" | "need_input" | "broadcast" | "dm"
  "agent": "gemini",               // target agent kind (omit for broadcast)
  "task": "Critique the cathode spec",
  "context": "Compact delta: previous 2 rounds + open question",
  "expect": "5 bullet risks, each with severity",
  "why": "Physics validation needed"
}
```
```

```text
```council
{ "action": "broadcast", "task": "…same task to every participant…",
  "context": "…", "expect": "…", "why": "…" }
```
{ "action": "dm", "agent": "gemini", "task": "…private message, shown only in the
  gemini↔chatgpt private thread…", "context": "…", "why": "…" }
```
```

Channel model (ratified R1, §18): **public** council thread = `invite` (leader →
one participant) or `broadcast` (leader → all participants); **private** threads
(session-scoped DMs) = `dm` from any participant to any participant. Every channel
action still comes from a strict machine-readable block only.`

```text
```council
{
  "action": "decide",
  "status": "solved",              // or "blocked"
  "answer": "…the final, verbatim answer…",
  "confidence": 0.82,
  "dissent": ["gemini: disagrees on electrolyte choice"]
}
```
```

Protocol rules:
- Strict JSON parse. Invalid → treated as prose, surfaced to you as a protocol warning.
- `agent` must be a session participant. Unknown → warning, no dispatch.
- `invite` and `broadcast` are leader-only actions. `dm` is allowed from any participant.
  Violation → warning, no dispatch (and the offending line is flagged in the UI).
- `max` invites per round and `max_rounds` per session, both enforced hard.
- Every parse outcome is logged to `events` for audit.

---

## 9. Orchestrator state machine

```
        ┌─────────┐
        │  IDLE   │◀──────────────── user sends / resumes
        └────┬────┘
             │ sendTo(leader)
             ▼
     ┌───────────────┐
     │  LEADER_TURN  │─── timeout/error ──▶ ┌──────────┐
     └───────┬───────┘                     │ RETRY(≤2)│
             │ reply                       └──────────┘
             ▼
     ┌────────────────────┐  no council block / action=comment
     │  PARSE_PROTOCOL    │──────────────────────▶ ┌──────────────┐
     └────┬───────────────┘                        │ APPEND+NOTIFY│
          │ action=invite                          └──────┬───────┘
          ▼                                               │
     ┌────────────────────┐                                │
     │  BUILD_PACKET      │  strategy: delta | window | full | scratchpad
     │  (PromptCompiler)  │  + Fractal Memory preamble
     └────┬───────────────┘
          ▼
     ┌────────────────────┐
     │  DISPATCH (queue)  │  strictly serialized; one agent at a time
     └────┬───────────────┘
          ▼
     ┌────────────────────┐   not done
     │ AWAIT_COMPLETION   │──────────────────┐
     │  stability + stop  │                  │
     │  button + timeout  │                  │
     └────┬───────────────┘                  │
          ▼                                   │
     ┌────────────────────┐                  │
     │  STORE_VERBATIM    │                  │
     │  raw+html+hash     │                  │
     └────┬───────────────┘                  │
          ▼                                   │
     ┌────────────────────┐                  │
     │ CONSENSUS +        │                  │
     │ CONVERGENCE        │◀─────────────────┘
     └────┬───────────────┘
          │ solved / stagnant / cap hit
          ▼
     ┌────────────────────┐
     │  FINALIZE          │──▶ Decision Record, notification, session ready
     └────────────────────┘
```

Hard stops (always safe, never hangs): `action=decide`, round cap, wall-clock budget,
stagnation detection, 2× consecutive transport errors, user interrupt.

---

## 10. Adapter contract

```dart
abstract class AgentAdapter {
  String get kind;                 // 'chatgpt' | 'gemini' | 'deepseek'
  AdapterConfig get config;        // hot-reloadable JSON
  Future<LoginState> checkLogin();
  Future<void> newChat();
  Future<void> send(String text);
  Stream<String> stream();         // live tokens
  Future<String> awaitCompletion();// stability + stop-button + timeout
  Future<Verbatim> lastMessage();  // rawText + rawHtml + optional screenshot
  Future<void> selectModel(String label);
}
```

Config (per provider, versioned, hot-reloadable, optionally remote-signed):
selectors for composer, send button, stop button, message container, last assistant node,
model picker, login marker; stability thresholds; timeouts; locale.

---

## 11. UI/UX

```
┌────────────┬──────────────────────────────────────────┬──────────────────┐
│  SESSIONS  │            COUNCIL CHAT                  │   COUNCIL        │
│  ─────────  │  round 3 · leader: chatgpt               │   ───────────    │
│  ▸ Battery │  ┌────────────────────────────────────┐  │  ● chatgpt  lead │
│    design  │  │ [user] "here's the spec…"          │  │  ● gemini   ok   │
│  ▸ App bug │  └────────────────────────────────────┘  │  ◐ deepseek busy │
│  ▸ Thesis  │  ┌────────────────────────────────────┐  │  ○ claude  off   │
│            │  │ [gemini] verbatim answer…          │  │                  │
│  + New     │  │  ⟨rendered|raw|plain⟩  ⎘ 12s      │  │  [Template]      │
│  🔍 search │  └────────────────────────────────────┘  │  [Fork]  [Advers]│
│            │  ┌─ invite ─ gemini · critique cathode ┐│  [Export]  [Stop]│
│            │  └─────────────────────────────────────┘│                  │
├────────────┴──────────────────────────────────────────┴──────────────────┤
│  ⟶ type…  🎤  ⌘⏎ send   @gemini @deepseek @all @leader                   │
└──────────────────────────────────────────────────────────────────────────┘
```

- Left: session tree + FTS search.
- Center: transcript, agent-coloured, round markers, per-message Raw/Rendered/Plain toggle,
  copy, latency, packet link, and Agora's own annotations visually separated.
- Right: council panel — participants, live status, role cards, model picker, actions.
- Bottom: composer with voice + `@` routing.
- Also: Calibration Studio screen, Decision Record viewer, Settings.
- Shortcuts: `⌘/Ctrl+Enter` send · `⌘/Ctrl+K` palette · `Ctrl+S` snapshot · `Esc` interrupt.

> **§11 is the v1 layout (shipped).** The ratified **UI v2 — opencode × WhatsApp hybrid**
> (chat-list, bubbles, HUD, slash commands) is specified in §18.3 and supersedes this
> three-pane sketch where they conflict.

---

## 12. Testing without real accounts

- **Mock provider lab**: local web app imitating ChatGPT/Gemini/DeepSeek DOM (composer, send,
  streaming, stop button, model picker) with scripted replies → adapters tested end-to-end.
- **State-machine unit tests** with fake adapters: every stop condition, every protocol edge case.
- **Recorded DOM fixtures** → adapter regression suite.
- **Journal replay** → reproduces a real run against the mock lab.
- Real-site checks are opt-in, manual, and never part of CI.

---

## 13. Packaging

- `flutter build linux --release` → `build/linux/x64/release/bundle/Agora`
- `appimagetool` → `Agora-1.0.0-x86_64.AppImage`
- Also emit `.deb` and a tar.gz.
- AppImage ships **the app only** (~40–60 MB). It drives the system Chrome — no browser
  download, so the image stays small and stays current with your installed Chrome.

---

## 14. Roadmap

| Phase | Deliverable | Size |
|---|---|---|
| **P0** | Restore UI from git; rename to `agora`; archive Python backend; CDP hello-world against real Chrome | S |
| **P1** | ChromeLauncher + dedicated profile + login detection + onboarding wizard | S |
| **P2** | Adapter framework + mock lab + ChatGPT adapter + Calibration Studio | M |
| **P3** | SQLite store + session CRUD + search + export/import | M |
| **P4** | Orchestrator state machine + Council Protocol + budgets + convergence | L |
| **P5** | Gemini + DeepSeek adapters | M |
| **P6** | UI polish, journal/replay, safety firewall, **AppImage build** | M |
| **P7** | Upgrades batch 1: adversarial rounds, consensus, delta packets, forking, templates, voice | L |
| **P8** | Upgrades batch 2: Fractal Memory, remote adapter updates, analytics, marketplace | L |
| **P9** | Channels: `dm` + `broadcast` protocol actions, private thread storage, UI channels | M (R1) |
| **P10** | UI v2: opencode × WhatsApp hybrid — chat list + bubbles + HUD + slash commands | L (R1) |
| **P11** | Silent Chrome mode (`agora.chromeMode: silent`) + captcha/login auto-reveal | S (R1) |

Realistic: P0–P6 is a genuinely usable v1 in ~5–7 focused days. P7–P8 take it from useful
to something you'd build your engineering workflow around.

---

## 15. Risk register

| Risk | Severity | Mitigation |
|---|---|---|
| **ToS / account risk** — automating chat UIs violates most providers' terms | HIGH | Human-paced, single account, no burst parallelism, optional API-key mode, per-agent daily message cap. Your decision, made knowingly. |
| **DOM churn** | HIGH | Config-driven adapters + Calibration Studio + Adapter Healer + remote updates + regression suite |
| **ChatGPT login challenges / CAPTCHAs** | HIGH | Login detection, pause + notify, human solves once, cookies persist |
| **Context limits on web UIs** | MED | Delta packets, context pressure meter, Fractal Memory |
| **Memory from many tabs** | MED | One live session, tab pooling, idle tab close, keep 1 warm tab per agent |
| **"Solved" is a judgement** | MED | Convergence + consensus + mandatory dissent; always show the round log |
| **App crashes mid-council** | MED | Journal every action, resume from last completed round |
| **Prompt injection across agents** | MED | C1 firewall + fenced relayed content |
| **CDP profile lock** (Chrome already running with same dir) | LOW | Dedicated dir; detect and report clearly |
| **Silent Chrome hides a captcha or login prompt** (R1) | MED | Auto-reveal on `captcha`/`rateLimited`/`loggedOut` events; HUD "Reveal Chrome" button; audible alert |
| **Seeded identity goes stale** (R1: cookies copied from everyday Chrome) | MED | Re-check logins on launch (LoginChecker); seed refresh documented in §18.4; never read a live Cookie DB while its Chrome runs (copy only when Chrome is closed) |

---

## 16. Locked decisions

1. Name: **Agora**
2. Stack: **Flutter desktop (Dart) + raw CDP + SQLite/drift**. No Python, no Docker, no WebSocket backend.
3. Reuse: existing Flutter UI (models, theme, widgets, screens); **rewrite** the service/provider layer.
4. Output: **AppImage**, native, local-first.
5. **One live session at a time**; sessions are separate projects in storage.
6. Verbatim output, always.

## 17. Open questions

1. Per-agent daily message cap — set a default? (Suggested: 60/agent/day.)
2. Do you want a **visible Chrome window** (you can watch the agents) or a background window?
   → **Answered in R1 (§18.2): silent Chrome is the default, with auto-reveal + "Reveal Chrome"**
   → in the HUD. `agora.chromeMode: visible | silent`.
3. Should relayed answers be **summarized by the leader** before reaching other agents, or sent raw?
   (Suggested: raw, with the leader free to add its own framing.)

---

## 18. Amendment R1 — ratified 2026-10-06

Ratified by the user on 2026-10-06 ("Vajith Husan / vajithhusan@gmail.com … silent … private and
public communication between each other … opencode and whatsapp mixed interface … improve the
plan more"). This section amends the plan of record. Where it conflicts with anything above —
§2.4, §8, §11, §17 — **R1 wins**.

### 18.1 Communication model — private and public channels

The council is no longer a single leader→delegate thread. Every session has **one public
council channel** plus **N private channels** (one per agent pair, created lazily on first DM).

| Action | Channel | Allowed senders | Semantics |
|---|---|---|---|
| `invite` | public | leader only | Leader addresses one participant; reply lands in the public thread |
| `broadcast` | public | leader only | Leader sends one packet to all participants (ratifies the old GROUPCHAT round-robin, but *explicitly*, never by free text) |
| `dm` | private | **any participant** | Point-to-point message between two agents; reply swaps roles in the same private thread |
| `decide` / `comment` / `need_input` | public | leader only | As per §8 |

Rule unchanged: **all dispatch comes from strict machine-readable blocks.** The old "delegates
may not invite" ban (§2.4's original reading, `AGENTS.md`'s blocking-contradiction) is replaced
by this table: delegates may `dm` privately, but only the leader opens public rounds. The
**SpeakerSelector** is thereby unblocked — it selects the next speaker according to this table
(invite target, broadcast set, or dm target), never from free text.

Storage impact: `channels(id, session_id, kind, display_name, members, created_at)` and
`messages.channel_id` (nullable → public thread when null). Private threads render as
WhatsApp-style conversations (18.3) and are fully journaled/replayable like the public thread.

### 18.2 Silent Chrome (background driving)

Default mode is **silent**: Chrome launches on the dedicated profile, occluded/minimized
(`--start-minimized` + bring-to-front emulation already in the adapter), and only Agora is
visible. Safety valves, mandatory:

- **Auto-reveal**: on `captcha` / `rateLimited` / `loggedOut` login events the window is
  brought to front automatically, so a human can solve what only a human can solve.
- **HUD "Reveal Chrome" button** and **audible alert** when the council pauses for a human.
- Toggle `agora.chromeMode: silent | visible` — visible mode keeps the v1 behavior.
- Journal captures the window state alongside every action for replay fidelity.

### 18.3 UI v2 — opencode × WhatsApp hybrid (highest UI/UX, HUD, GUI)

Layout (three panes + HUD):

```
┌────────────────────┬──────────────────────────────────────────┬───────────────────────┐
│ CHATS (WhatsApp)   │  CONVERSATION (bubbles)                  │  HUD (workbench)      │
│ ────────────────── │  ┌────────────────────────────────────┐  │ ───────────────────── │
│ 🟢 Battery design  │  │ [9:41] gemini  ◐ typing…           │  │ ● chatgpt   lead      │
│    (council · 5)   │  │ ▸ round 4 · leader: chatgpt        │  │ ◐ gemini    busy      │
│ 🟢 gemini↔deepseek │  │ ┌──────────────────────────────┐   │  │ ○ deepseek   idle     │
│    (private · 2)   │  │ │ [gemini] vocalcritique… ✓✓  │   │  │ ⏱ ctx 62% ▮▮▮▯▯▯      │
│ 🟢 chatgpt↔gemini  │  │ │ ⟨raw|rendered|plain⟩ ⎘ 12s   │   │  │ 📈 convergence 0.82   │
│    (private · 1)   │  │ └──────────────────────────────┘   │  │ [Adversarial] [Fork]  │
│ 🔍 search          │  │  code blocks styled like opencode   │  │ [Export] [Reveal⇔]   │
│ + New session      │  └────────────────────────────────────┘  │ [Stop] [Templates]    │
│ pinned: Battery    │  ⟶ /adversarial  @gemini  …  🎤 ⌘⏎      │                       │
└────────────────────┴──────────────────────────────────────────┴───────────────────────┘
```

- **Left — chat list (WhatsApp conventions):** conversations = public councils + private
  channels, avatar stacks, unread badges, pinned, presence dots (● busy / ◐ generating /
  ○ idle derived from seat state), ✓ / ✓✓ read receipts on agent messages, search, archive.
- **Center — conversation bubbles:** per-agent colors + avatars + role chips; **verbatim**
  toggle Raw/Rendered/Plain per message (§2.1); round separators in the public thread;
  opencode-style code blocks + inline markdown + session fork/diff affordances (D3, D4);
  typing indicator while an agent streams; latency + packet links.
- **Right — HUD/workbench:** live seat status, per-agent context-pressure meters (B2),
  convergence graph (A4), model picker, one-click actions (adversarial round, fork, export,
  stop, reveal-Chrome), templates, decision record.
- **Composer (opencode conventions):** slash commands (`/adversarial`, `/fork`, `/template`,
  `/roles`, `/inject`), `@` routing (`@all` → broadcast, `@gemini` → DM + fast-path to that
  private thread), voice hold-to-talk, `⌘/Ctrl+Enter`, `⌘/Ctrl+K` palette, `Esc` interrupt.
- Every pane is keyboard-navigable; the HUD collapses into an overlay while a council runs
  (the "HUD" lives up to its name — you can watch the debate while working elsewhere).

### 18.4 Live identity — the Vajith Husan profile (done, verified 2026-10-06)

The dedicated profile `~/.config/agora/chrome-profile` is **pre-seeded** from the user's
everyday Chrome *Vajith Husan / vajithhusan@gmail.com* profile:

- Seeded once by cloning `~/.config/google-chrome/Profile 1` identity files into the dedicated
  profile as `Default` — `Local State` (carrying `os_crypt` portal key), `Cookies`, `Login
  Data*`, `Local Storage`, `IndexedDB`, `WebStorage`, avatar — **never** caches/extensions/
  sessions, and **only while the source Chrome is closed** (a live Cookie DB is never copied).
- Result (verified live 2026-10-06): **ChatGPT READY** and **Google/Gemini READY** on the
  dedicated profile; both sites authenticate without any manual sign-in.
- **DeepSeek has no stored login** in the Vajith profile (verified across Cookies, Local
  Storage and IndexedDB on 2026-10-06 — only `smidV2` tracking exists). The onboarding wizard
  detects this and leaves a sign-in tab open once; afterwards it persists in the dedicated
  profile. This is expected behavior, not a defect.
- The first live-council gate is a re-run of `tool/live_check.dart council` against the seeded
  profile (see STATE.md for the result and any adapter fixes that followed).
- Future: an in-app "import my logins" flow generalizes the seed (choose profile → read-only
  copy while closed → verify). Not in the R1 build list unless the manual copy rots.

### 18.5 What R1 changes in code/storage (build list)

1. `lib/core/council`: protocol parser accepts `dm` + `broadcast`; `orchestrator.dart` gains
   the sender table (leader-gate on `invite`/`broadcast`, open `dm`); SpeakerSelector unblocked
   per §18.1.
2. storage: `channels` table + `messages.channel_id` (drift migration v3); repository CRUD for
   private threads.
3. UI: `lib/ui` — chat list pane, bubbles, HUD, slash/`@` composer (P10); Chrome reveal +
   `agora.chromeMode` toggle (P11).
4. Login re-check on launch stays `LoginChecker`; auto-reveal hook added to the council pause
   path.
5. Tests: protocol parsing for all five actions, sender-table enforcement, channel journal
   replay, dm round-trip in the Sandbox Lab; UI widget tests for chat list + HUD.
