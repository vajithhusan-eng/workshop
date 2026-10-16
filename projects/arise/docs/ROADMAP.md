# Arise — Roadmap

> **Status: DECIDED 2026-10-17.** We build **v1 properly**, not the whole v20 at
> once. The v20 arc is the north star; each version ships *complete and offline*
> before the next begins. The version numbers are a **discipline**, not a
> backlog — which is the whole point of the product.

---

## The decision (recorded)

- The full 20-version arc was explored (see below). The tempting move was to
  build it all as "v1."
- **Decision:** start at **v1**, ship it whole, then iterate. Rationale: most
  apps die at v3 because v2 tried to do too much; the arc only works if each
  step is finished before the next. This also matches the app's own thesis.
- **North star:** the v20 vision stays documented so v1 is *architected* for it —
  data model, storage, and progression designed so later versions extend rather
  than rewrite.

---

## Version arc (north star, not scope)

| Ver | Codename | Function | System wrapper |
|---|---|---|---|
| 1 | **The Awakening** | Daily/weekly quests, XP, levels, ranks, streaks | System windows, quest pop-ups |
| 2 | Stats & Job | Habits→stats, job classes | Stat sheet, class selection |
| 3 | Penalty Zone | HP, bounded penalty, recovery | Penalty quest, HP |
| 4 | Dungeon Runs | Timed focus sessions | Gates, floors, boss battles |
| 5 | Inventory & Shop | Earn gold, spend on self-defined rewards | Loot, potions, items |
| 6 | Bestiary & Titles | Category mastery, achievements | Shadows, equippable titles |
| 7 | System Logs | Analytics dashboard | The System's log |
| 8 | Awakening | Prestige/ascension, exclusive classes | Rank reset, keeps titles |
| 9 | Quest Builder | User-authored quest chains, conditionals | The System obeys you |
| 10 | Shadow Monarch | Full life-RPG; army, throne room, chronicle | Your life as a saga |
| 11 | Guild | Offline/local co-op, accountability | Guild |
| 12 | Class Trees | Branching evolution from years of data | Build identity |
| 13 | Procedural Quests | Rule-based adaptive generation | The System recommends |
| 14 | Life Chapters | Journey segmented into arcs | Scrollable story |
| 15 | The Archive | Exportable life chronicle | Your discipline as a saga |
| 20 | World System | Seasonal events, Pantheon, Chronicle Engine, widgets, Habit DNA | On-device discipline platform in the best manhwa costume ever built |

## What's buildable now vs gated by time

- **Now (~90%)**: quests, XP, levels, ranks, stats, jobs, HP/penalty, dungeon
  mode, inventory, titles, quest builder, notifications, widget, bestiary,
  analytics, shadow army, chronicle logging, basic Habit DNA, seasonal events.
- **Gated by design**: Awakening (needs max level), Pantheon (needs first
  Awakening), rich chronicle (needs months). — All are *supposed* to be gated;
  a player can't prestige at level 1.

---

## v1 scope — "The Awakening" (definition of done)

**In scope:**
1. **Quests** — daily, weekly, custom; each with cue time, XP value, and an
   optional 2-minute minimum version.
2. **XP + levels** — rising-cost XP curve; fast early levels (endowed-progress).
3. **Ranks** — E → D → C → B → A → S, earned by level/consistency milestones.
4. **Streaks** — with **never-miss-twice** logic and a bounded penalty (not a
   wipe). No shame copy.
5. **System window** — local notification styled as a System panel, at the
   user's set time. The core UX moment.
6. **Core UI** — status screen (name, level, rank, XP bar), quest list, quest
   completion flow.
7. **Local storage** — offline, no account, no network. **On-device only.**
8. **Daily log** — mark complete / miss; the measurement effect is the product.

**Explicitly NOT in v1:** stats, jobs, HP/penalty zone, dungeon mode, shop,
titles, bestiary, analytics, shadow army, widgets, events, prestige. *(These are
v2–v20; architecture must not preclude them.)*

**Architecture rules for v1 (to protect the arc):**
- Data model built for extension: quest kinds, an event/achievement hook, and a
  monotonic XP ledger that later features (stats, gold, titles) can all derive
  from.
- Storage chosen once (on-device, relational or key-value) and abstracted so the
  UI never touches it directly.
- All "System" text lives in one place (copy table) so language/ethics rules are
  enforceable, not scattered.

---

## Milestones (build order)

1. **M0 — Scaffold**: Flutter project, package id, folder structure, lint/test
   config. Verify: `flutter analyze` + a trivial passing test.
2. **M1 — Domain**: quest/XP/level/rank models + pure logic, with unit tests for
   the XP curve, rank thresholds, and never-miss-twice. Verify: unit tests green.
3. **M2 — Persistence**: on-device store behind a repository interface.
   Verify: round-trip test.
4. **M3 — Core UI**: status screen + quest list + completion flow.
   Verify: widget test + manual run.
5. **M4 — System window**: scheduled local notification on the System-styled
   channel. Verify: notification fires on a real device/emulator.
6. **M5 — Polish + ethics pass**: copy table review against the red lines; full
   suite green.

*(Build order and exact commands recorded in the project README/AGENTS as work
proceeds.)*

---

## Open decisions

- **Package id**: `com.arise.system` proposed, not confirmed.
- **State management**: to be chosen at M0 (leaning Riverpod or Bloc).
- **Storage**: to be chosen at M0 (leaning Isar or Drift; both offline).
- **Working title**: "Arise" (final name TBD).
