# Changelog

Append-only, newest first. One entry per change that altered behaviour or
recorded a decision — not one per commit.

## 2026-10-24 — Habit control, "detox", and the human behaviour model

- Added [`docs/HABIT-CONTROL-AND-DETOX.md`](docs/HABIT-CONTROL-AND-DETOX.md) —
  the intervention science. **The detox verdict:** dopamine fasting is
  unsupported (Harvard Health, Cleveland Clinic, The Scientist, Fei 2022,
  Cureus 2024) — you cannot fast from a neurotransmitter, and what the practice
  actually is, is CBT. **Digital detox:** reduction beats abstinence
  (Brailovskaia 2023, N=619: 1 h/day reduction had stronger and more durable
  effects at 4 months than 7-day abstinence). **The self-control ladder**
  (Duckworth, Gendler & Gross 2016): five strategy families, earlier = more
  effective — and the recorded self-critique that **v1 sits on the weakest rung**
  (response modulation), with the fix being strategy tags, cue-removal work at
  onboarding, and rung-1/2 actions before any tracker. Plus craving mechanics,
  the lapse protocol (AVE, attribution retraining, self-compassion, no-penalty
  logging), the sleep/stress platform with **stress→habit flagged as failed
  replication**, the willpower-belief trap, the **BCTTv1 active-ingredient audit**
  (three missing techniques: coping planning, reduce prompts/cues, instruction),
  the adversarial environment (Lyngs 2019, 367 tools, 74% blocking), and an
  explicit **what-Arise-will-not-claim** ledger.
- Added [`docs/HUMAN-BEHAVIOR.md`](docs/HUMAN-BEHAVIOR.md) — the seven-layer
  model (biology → reward learning → habit → motivation → identity → social →
  environment), integrated through **COM-B**, with the dual-process account,
  the needs table, **emotion regulation as the hidden variable**, the
  intention–behaviour gap (~28%), a layer-by-layer **refusal ledger**, a
  top-down diagnostic, and ten design rules.
- Recorded the strategic consequence: Arise must be an
  **opportunity-and-capability product with a motivation skin**, not the
  reverse — and must never ship the word "detox" in UI copy.

## 2026-10-24 — Genre atlas + source library

- Added [`docs/GENRE-ATLAS.md`](docs/GENRE-ATLAS.md) — the two-axis grammar of
  system stories (premise trope × mechanic × progression axis × emotional engine);
  a mechanic catalogue (status window, quests, penalties, ranks, stats, classes,
  titles, bestiary, gacha); the archetype atlas across anime/manga/manhwa; the
  non-System discipline protagonists (Rock Lee, Saitama, Ippo, Blue Lock,
  Thorfinn, Mob, Frieren); and the **binding borrow/refuse ledger** cross-checked
  against the 12 red lines.
- Added [`docs/SOURCE-LIBRARY.md`](docs/SOURCE-LIBRARY.md) — the canon: anime
  analysis channels, podcasts, game-design and behaviour books, and the research
  papers (SDT, Deci/Koestner/Ryan 1999, PENS, Hamari 2014, Li/Hew/Du 2024,
  Toda 2018 dark side, Bogost 2011). Ends with the **operational world-class bar**
  and the two traps on the way there (the PBL fallacy and the content trap).

## 2026-10-24 — 3D interface + habits & routines knowledge base

- **Name decided: ARISE** (was a working title). Recorded as a locked decision.
- **Personal & private, single-user** recorded as a locked decision.
- Added [`docs/3D-IMMERSIVE-UI.md`](docs/3D-IMMERSIVE-UI.md) — 3D/spatial UI
  spec: `flutter_scene`/Flutter GPU/Impeller vs 2.5D, three capability tiers
  (immersive → depth → flat), depth system, one-hero-3D-per-screen rule, motion,
  performance budget, vestibular safety, bundled-asset offline rule.
- Added [`docs/HABITS-ROUTINES-DEEP.md`](docs/HABITS-ROUTINES-DEEP.md) — habits
  vs routines, formation timelines (Lally; morning ~106 d vs evening ~154 d), Wood
  2024 context/friction levers, keystone habits, chronotype/synchrony, habit
  stacking, anchor sleep — each mapped to a concrete Arise feature.

## 2026-10-17 — UI/UX, architecture, and feature research

- Added [`docs/UI-UX-HUD.md`](docs/UI-UX-HUD.md) — the interface/HUD design
  spec: design thesis, dark-only palette tokens, typography, the glass-panel
  recipe, motion table, component inventory, screens/flows, WCAG 2.2 AA
  accessibility, and performance rules.
- Added [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — modules, layers, data
  models, pure domain engines (level/rank/streak/XP/scheduler), storage,
  state-management, routing, notifications, and testing. Records the M0
  technical decisions: package id `com.arise.system`, **Riverpod**, **Drift**,
  **go_router**, `flutter_local_notifications`, `flutter_animate`, bundled fonts.
- Added [`docs/FEATURE-SPEC.md`](docs/FEATURE-SPEC.md) — behavioural spec for
  every v1 feature plus the v2–v20 registry and the reserved hooks that keep v1
  from precluding the arc.
- Adopted the workspace project standard: added `README.md`, `CHANGELOG.md`,
  `.gitignore`, and re-shaped `STATE.md` to the pinned format.

## 2026-10-17 — porn & masturbation compulsion research

- Added [`docs/PORN-MASTURBATION-CONTROL.md`](docs/PORN-MASTURBATION-CONTROL.md)
  — evidence-graded research for the highest-stakes use case. Core rule:
  **target compulsion (loss of control + impairment), never frequency, guilt, or
  morality**; always include an off-ramp and signpost professional help.

## 2026-10-17 — deep research + v1-first decision

- **Decided:** build **v1 properly**, not v20 at once; the v20 arc is the north
  star and each version ships complete and offline before the next.
- Added `docs/BEHAVIOR-SCIENCE-DEEP.md`, `docs/SYSTEM-GENRE-DEEP.md`,
  `docs/GAMIFICATION-ETHICS.md`, `docs/ROADMAP.md`, `docs/README.md`,
  `AGENTS.md`, and `STATE.md`.

## 2026-10-17 — project created (research foundation)

- Initial research docs: `docs/SYSTEM-RESEARCH.md`, `docs/APP-LANDSCAPE.md`,
  `docs/PSYCHOLOGY.md`.
