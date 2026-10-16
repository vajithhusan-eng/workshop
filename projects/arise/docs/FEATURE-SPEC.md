# Arise — Feature Specification

> What each feature *does*, its rules, and its acceptance criteria. This is the
> behavioural contract; `docs/ARCHITECTURE.md` says how it is built and
> `docs/UI-UX-HUD.md` says how it looks.
>
> Each feature is tagged **[v1]** (in the first release) or **[vN]** (the arc).

---

## F1. Awakening / Onboarding **[v1]**

The first-run experience. Its job: acquire the user, learn their *stage*, and
produce one winnable quest.

**Flow**
1. **Acquisition screen** — the System speaks: *"You have acquired the
   qualifications to be a Player."* One primary action. (Genre homage; original
   wording — no Solo Leveling terms.)
2. **Name** — what should the System call you?
3. **Stage select** (`StageSelectCard`) — Transtheoretical-model aware. Asks
   *"Where are you right now?"* with plain-language options (just thinking about
   it / getting ready / doing it already / back after a break). **Most arrivals
   are in Contemplation** — the app must not assume Action stage.
4. **First quest** — offer a **2-minute-winnable** starter (Two-Minute Rule) so
   the first XP is immediate.
5. **Cue time** — when should the System check in?
6. **Notification permission** — asked *in context*, with an honest reason.
7. **Done** — the Status screen, with the first quest ready.

**Rules**
- Never more than 7 steps; always skippable back to a default.
- No account, no email, no network — ever.
- If a user declines notifications, the app still works fully (notifications are
  a convenience, never a gate).

**Acceptance:** a new user reaches the Status screen with ≥1 active quest and a
scheduled reminder, in under 60 seconds of interaction, offline.

---

## F2. Quests **[v1]**

The core loop. A **quest template** is a habit you're building (or a bad habit
you're breaking); a **quest instance** is today's occurrence.

**Types**
- **Daily** — materialises every day at the local day boundary.
- **Weekly** — a target count per week (e.g. 3×/week); completes when the target
  is met.
- **Custom** — one-off or user-scheduled.

**Fields:** title, optional description, type, domain (neutral / bad-habit), XP
value, optional minimum minutes (Two-Minute Rule floor), optional cue time.

**Completion**
- Completing an instance: `status → done`, award XP, append an `XpEvent`, update
  streak, show the XP animation.
- **No confirmation dialog** for a normal completion (only destructive actions
  confirm).
- **Un-complete** within a short window is allowed (mistakes happen) and reverses
  the `XpEvent` by appending a compensating event — never by deleting history.

**Missed**
- A missed instance becomes `skipped` at day roll-over. It feeds the streak
  engine (never-miss-twice) and shows a bounded penalty notice — never red, never
  a wiped streak, never shame.

**Creation**
- Quick-add from prefilled templates (curated packs: Movement, Sleep, Study,
  Mindfulness, Bad-habit recovery).
- Full editor for custom quests.

**Acceptance:** create a daily quest with a cue time; it appears each day; completing
it awards exactly its XP and updates the streak; missing one day is tolerated,
missing two is handled per F3.

---

## F3. Streaks (never-miss-twice) **[v1]**

**Rule** (from `BEHAVIOR-SCIENCE-DEEP.md` §A — Clear; and Marlatt §C):
- Missing **one** day does **not** break the streak; it consumes a **shield**
  (a "freeze"). The user gets a visible *"The System notes your absence"* notice.
- Missing **two consecutive** days resets `current` to 0.
- **`longest`, `totalCompletions`, and `totalAttempts` are never lost.** The
  record of every attempt is permanent. This is the AVE defence — a reset is
  never an erasure.

**Shields:** a small stock, regenerated slowly (e.g. one per N consecutive
completions). Honest, visible, never purchasable (no real money — red line).

**Acceptance:** a unit test proves: miss-1 keeps streak + decrements shield;
miss-2 resets current but preserves longest/totals; no code path can zero the
historical totals.

---

## F4. XP, Levels & Ranks **[v1]**

**XP** — earned from quest completion (value set per quest), recovery quests, and
milestones. A bounded penalty may subtract (floored at 0).

**Levels** — rising-cost curve `xpToNext = base * level^exp` (start 100, ~1.5),
tuned so early levels are fast. On level-up: `LevelUpOverlay`, stat allocator
arrives in v2.

**Ranks** — E 1–9 · D 10–19 · C 20–34 · B 35–49 · A 50–69 · S 70+. On rank-up:
`RankUpOverlay` + a permanent `Title` slot (titles ship v6, slot reserved now).

**Ledger** — every XP change is an appended `XpEvent`; `xpTotal`/`level`/`rank`
are derived caches. History is append-only.

**Acceptance:** a table-driven test covers the curve across levels 1–100; rank
boundaries are exact; the ledger reconstructs `xpTotal` from events alone.

---

## F5. System Notifications **[v1]**

- A local notification at the user's **cue time**, rendered as a System window
  (title = System line from the catalog, body = quest summary).
- Tapping deep-links to `/quests`.
- **Honest reminders only** — no engagement bait, no guilt/fear copy, no
  "you're about to lose your streak". If the user has done their quests, no
  nagging.
- Android 13+: `POST_NOTIFICATIONS` runtime ask. Android 12+: exact alarms
  (`SCHEDULE_EXACT_ALARM`); if denied, fall back to inexact and **tell the user**.

**Acceptance:** a scheduled reminder fires offline at the cue time; the payload
renders on the notification tray with System styling; denying permission never
breaks the app.

---

## F6. Daily Log / Chronicle **[v1]**

- One `DailyLog` per day: auto-filled counts (planned/done) + an optional note.
- The list view is the seed of v15's "The Archive" — a read-your-own-story log.

**Acceptance:** the log records planned/done accurately; notes persist; the list
scrolls back through history.

---

## F7. Bad-habit recovery (domain) **[v1, scoped]**

*v1 ships the mechanic narrow; the depth ships with the domain work.*

- A **bad-habit quest** has a `badHabit` domain: it counts **clean days**, not
  completions.
- **Urge Surf panel** — name the urge, a ~10-minute timer while the wave crests,
  then log resisted (XP) or lapsed (no punishment).
- **Recovery panel (AVE-safe)** — a lapse is a *stumble*: attribute to
  *situation*, immediately offer a recovery quest and a Fresh Start reset;
  **never reset the total record**.
- **Guardrails** (`PORN-MASTURBATION-CONTROL.md`): screen for impairment, not
  frequency or guilt; build the off-ramp; always signpost professional help.

**Acceptance:** the lapse flow never zeroes history; the off-ramp is reachable
and honest; no copy path attributes a lapse to the self.

---

## F8. Settings & data ownership **[v1]**

- Notifications & cue times; sound toggle (default muted); reduced-motion
  override; high-contrast (blur-off) toggle; export/import (JSON artifact);
  About; **Ethics** page; reset (with a clear, non-coercive confirmation).

**Acceptance:** export produces a JSON file that re-imports to the same state;
every toggle takes effect immediately.

---

## F9. The arc (specified later, one slice each)

| vN | Feature | One-line intent |
|---|---|---|
| v2 | **Stats & Job** | Habits map to STR/AGI/VIT/INT/PER; stat points on level-up; choose a Job at level 10 |
| v3 | **HP & Penalty zone** | Failure has bounded teeth; a "penalty quest" recovery |
| v4 | **Dungeon (focus)** | Timed deep-work sessions as gates; bosses = weekly goals |
| v5 | **Inventory & Shop** | Gold from quests; spend on *self-defined real rewards* |
| v6 | **Titles & Bestiary** | Equippable achievements with passive flavour; conquered habits as "shadows" |
| v7 | **System Log (analytics)** | Completion rate, stat growth, rank projection — all local |
| v8 | **Awakening (prestige)** | Prestige with retained titles; endgame |
| v9 | **Quest Builder** | Conditional/custom quest chains; auto-scaling difficulty |
| v10 | **Shadow Army** | Personal dashboard as a force; life-RPG mode |
| v11+ | **Guild / seasons / Pantheon / Chronicle / Habit-DNA** | Local-multiplayer, events, permanent records, life-story engine |

Each vN is **one new feature slice** plus, at most, additive schema — never a
rewrite (guaranteed by `ARCHITECTURE.md` §1).

---

## F10. Future modules & models (registry)

**Modules (slices):** `stats` · `jobs` · `hp` · `dungeon` · `inventory` · `shop`
· `titles` · `bestiary` · `analytics` · `shadow-army` · `events` · `prestige` ·
`guild` · `chronicle` · `habit-dna`.

**Models to add:** `Stat`, `JobClass`, `HpEvent`, `Item`, `InventoryEntry`,
`Title`, `Achievement`, `DungeonSession`, `EventPack`, `ChronicleEntry`.

**Reserved hooks in v1** so nothing forces a rewrite:
- `Player.classId` (nullable) — v2 jobs.
- `XpSource.penalty` / `.recovery` — v3 HP/recovery accounts for them.
- `QuestDomain.badHabit` — F7 domain.
- Append-only ledger — v7 analytics, v8 prestige, v10 army, v15 chronicle all
  read it.

**Acceptance (for this doc):** every future module maps to an existing v1 hook;
if one doesn't, the v1 model is wrong and this doc is where we fix it *before*
coding.
