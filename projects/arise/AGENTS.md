# Arise — project instructions

Android-first **Flutter** app that turns habit-building and discipline into a
Solo Leveling–style **"System"**: daily quests, XP, levels, E→S ranks, and
System-styled notifications — for **habits, routines, and self-discipline**.

**Offline-only by design.** No account, no server, no network. The discipline
data never leaves the device. Tagline: *"The System belongs to you."*

## Identity in one line

Arise is **not a habit tracker with a manhwa theme** — it is a genuine
alternate-progression layer over the user's real life, with the psychology of
behaviour change underneath and the System aesthetic on top.

## The premise — read this before touching the System

The genre's emotional core maps exactly onto a discipline app: the user feels
stuck and unseen; the System makes real effort **visible, fair, and rising**.
Two consequences that are structural, not cosmetic:

- **Legible fairness is the product.** XP must equal effort. No pay-to-win, no
  fake score. Break that and the whole fantasy collapses.
- **Failure must always have a comeback path.** In the genre the protagonist
  always rises. The Abstinence Violation Effect (AVE) is the mechanism that turns
  one missed day into quitting — and it is an *identity* event, which a System
  can control. Never shame. Never wipe. (See `docs/BEHAVIOR-SCIENCE-DEEP.md` §C.)

## Authority

| Doc | Role |
|---|---|
| `docs/ROADMAP.md` | **The plan of record** — v1 scope, definition of done, milestones, the v1→v20 arc |
| `docs/BEHAVIOR-SCIENCE-DEEP.md` | The science spec; each mechanic cites its paper |
| `docs/PSYCHOLOGY.md` | The field map + **12 red lines** |
| `docs/GAMIFICATION-ETHICS.md` | Persuasion-vs-manipulation line; our operational rules |
| `docs/SYSTEM-RESEARCH.md` | Solo Leveling System mechanics + IP boundary |
| `docs/SYSTEM-GENRE-DEEP.md` | The genre + game-design lineage |
| `docs/APP-LANDSCAPE.md` | Competitor landscape (ZFA, Habitica, quit-apps, blockers) |
| `STATE.md` | Derived build state — regenerate via `project-orientation` |

## Locked decisions

1. **Build v1 properly, not v20 at once** (decided 2026-10-17). The v20 arc is
   the north star; each version ships *complete and offline* before the next.
2. **Offline-only, on-device.** No account, no upload, no network, no ads, no
   analytics phone-home. Local-only data is a red line, not a feature.
3. **Flutter, Android-first.** iOS deferred.
4. **No gamification dark patterns.** The 12 red lines in `PSYCHOLOGY.md` are
   binding. Streak shame, slot-machine rewards, fake scarcity/social proof,
   confirmshaming, guilt/fear copy, engagement-driven notifications, real-money
   stakes, vulnerable-user profiling — all forbidden.
5. **Borrow genre mechanics, rename all expression.** Mechanics are not
   protectable; names, titles, and trade dress are. No "Solo Leveling" terms.
6. **v1 architecture must not preclude v2–v20** (stats, jobs, HP, shop, titles,
   prestige).

## Scope

**In (v1 — "The Awakening"):** daily/weekly/custom quests with cue times and
optional 2-minute minimums; XP with a rising-cost curve; E→S ranks; streaks with
never-miss-twice logic and a bounded penalty; a System-styled local notification;
status screen; quest list + completion flow; on-device storage; daily log.

**Out (v1):** stats, job classes, HP/penalty zone, dungeon mode, shop/inventory,
titles, bestiary, analytics dashboard, shadow army, widgets, seasonal events,
prestige/Awakening. *(These are v2–v20 — see `docs/ROADMAP.md`.)*

## Conventions

- **Run the real command and read the output** — `flutter analyze`, `flutter test`.
  No green claim without observed output.
- **Every new mechanic cites its paper** in the deep-science doc, and every
  dark-adjacent technique is documented *with its intent*.
- **All System copy lives in one table** so the ethics rules are enforceable,
  not scattered through widgets.
- **Storage stays behind a repository interface** — UI never touches it directly,
  so v2+ can extend the schema without a rewrite.

## Open decisions

- **Package id**: `com.arise.system` proposed, unconfirmed.
- **Working title**: "Arise" — final name TBD (trademark check before branding).
- **State management**: leaning Riverpod; decide at M0.
- **Storage**: leaning Drift or Isar (both offline); decide at M0.

## Current state

**Planning + research only. Zero code.** `projects/arise/` holds `docs/` (7
research docs) and the orientation files. No Flutter project scaffolded yet.
Next: M0 (scaffold). See `docs/ROADMAP.md` milestones and `STATE.md`.
