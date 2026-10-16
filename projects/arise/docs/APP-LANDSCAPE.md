# App Landscape — Habit, Quit & Blocker Apps (Teardown)

Competitive research for **Arise**. What the space looks like in 2026, what each
category does well, what fails, and where our opening is.

---

## 1. The four categories

| Category | Job it does | Examples | Core mechanic |
|---|---|---|---|
| **A. Habit builders** | Build good habits | Streaks, Habitify, Loop, Way of Life, Atoms, Finch, Habitica | Streak/chain tracking |
| **B. Quit/sobriety apps** | Break bad habits/addictions | I Am Sober, Nomo, Quitzilla, Sober Time, Reframe, QuitNow | Day counter + pledge + milestones |
| **C. Blockers** | Prevent access to the bad habit | one sec, Opal, ScreenZen, Cold Turkey, BlockSite, BlockerX/BlockerPlus, Forge | Friction/blocking + bypass resistance |
| **D. Gamified/RPG** | Make discipline feel like a game | Habitica, ZFA (*Zero Faulty Habits*), Solo-Leveling clones, Atoms | Avatar progression + quests |

Our app sits at the intersection of **B + D** (quit behavior + RPG system), with
optional light **C** (friction) — the combination almost nobody does well.

## 2. Category A — Habit builders

### What they do well
- **Streaks / "don't break the chain"** — Seinfeld method. Loss aversion on a
  visual chain (see PSYCHOLOGY.md §3.1). Duolingo's internal data: users who
  reach a 7-day streak show ~3.6× 30-day retention.
- **Zero-friction check-in** — Streaks: "the best tracker is the one that takes
  less time to use than the habit itself." One tap, done.
- **Skip-don't-break** — **Way of Life** lets you mark "skip" instead of
  "missed", so chains survive a bad week. Explicitly designed to reduce the
  quit-after-one-miss spiral.
- **Widget-first** — Streaks/Habitify live on the home screen; the app is
  secondary to the widget.
- **Routine timers** — Routinery times the *steps inside* a session rather than
  a day-level checkbox.

### What fails
- **The day-14 collapse.** Multiple sources: trackers "feel motivating on day 3
  and punishing on day 14." One slip resets to zero → app becomes a guilt
  source → uninstall.
- **Reddit quotes (r/getdisciplined):** *"The streak apps were the worst. Break
  the streak once and the whole system collapsed, and I'd come back angrier at
  myself than before."* and *"breaking a streak felt worse than never starting."*
- **Extrinsic burnout** — points/badges work 30–90 days (Hamari 2014), then
  collapse if the behavior hasn't become intrinsically rewarding (Deci & Ryan).

### Our read
Streaks are the strongest retention mechanic in consumer apps **and** the
biggest source of user self-hatred. The fix is architectural: our **HP + streak-
freeze** model (from SYSTEM-RESEARCH.md) gives loss-aversion *without* total
reset. Way of Life's skip pattern proves the demand.

## 3. Category B — Quit / sobriety apps (closest to our "bad habit" side)

The user specifically pointed at this category. Shared feature set:

| Feature | What it is | Seen in |
|---|---|---|
| **Day counter / visual clock** | Days clean since quit date | I Am Sober, Nomo, Quitzilla |
| **Daily pledge + evening review** | Morning commitment, evening reflection | I Am Sober (the "heart" of the app), Nomo (optional) |
| **Milestones** | Auto-triggered time badges (1 day → years) | All |
| **Money-saved tracker** | Converts abstinence into cash | Quitzilla, Nomo, I Am Sober (free) |
| **Custom rewards** | Spend saved money on a self-defined treat | Quitzilla |
| **Panic / craving button** | Raise support at the moment of urge | ZFA "Crisis Shield", Forge "Craving SOS", I Am Sober |
| **Journal/notes** | Daily reflection, often private | I Am Sober, ZFA "Daily Chronicles" |
| **Community** | Wall by addiction type/milestone, or 1:1 partner | I Am Sober (large), Nomo (private partners) |

### Key finding — the "mental-first" lesson
ZFA's best review (from a user quitting porn, who had tried paid blockers):

> *"I've tried the paid apps with blockers and they didn't stop me... with this
> addiction there are endless ways of messing up, and it made looking for ways
> to circumvent the blockers an addiction itself. I love this app because it
> starts with the mind. As long as that changes, the rest will follow."*

**This is the single most important insight in this document.** Blocking fails
because the user games the block; the bypass hunt becomes its own compulsion.
The durable lever is **identity + consequence + reflection**, not the wall.

### Also important — the hidden-reward trick
Another ZFA review: *"it's great that you can't see the badges until you've
reached the days! Keeps me wanting to stay clean."* Locked, revealed-on-reach
milestones create a curiosity gap. Cheap to build, strong effect.

## 4. Category C — Blockers

### Mechanism & strictness ladder (low → high bypass resistance)
1. **one sec** — forces a breath/pause before opening an app, then asks "still
   want to open?" Reports ~57% social-media reduction at 6 weeks. Reversible.
2. **ScreenZen** — per-app limits + scheduled "Zen time".
3. **Opal** — focus sessions, locked distractors, friction dial; designed well.
4. **Cold Turkey / BlockSite / BlockerX / BlockerPlus / HelpMeFocus** —
   hard blocklists, app + browser.
5. **Forge** — blockers + streak + "phase-aware" coaching + Craving SOS
   (blocker with a behavior-change layer).

### What fails
- **Bypass.** Every blocker is beatable (uninstall, disable Shortcut, safe mode,
  new browser). Enforcement rated "easy" for most.
- **The circumvention paradox** (ZFA review above) — for some, the blocker
  *becomes* the game.
- **No mechanism for "why".** A block with no skill-building just creates a wall
  to climb.

### Our read
Offer friction as an **opt-in tool inside the System**, never as the product.
Frame it in-fiction (e.g. a "gate" you must consciously step through), and pair
every block with a *substitute action* so the urge has somewhere to go.

## 5. Category D — Gamified / RPG

### Habitica
- Full RPG: avatar, XP, gold, HP, quests, parties, pets, guilds.
- **Skip a habit → avatar takes damage.** Recoverable setback, not a reset —
  users report it's more sustainable than Streaks *for that reason*.
- Weakness: interface density; busy for aesthetic-first users.

### ZFA — *Zero Faulty Habits* (the app the user named)
- Dev: Goxr3plus Studio (solo, Greece). Free, ad-supported. 50K+ installs, 833
  reviews, rated 12+ (mild language).
- **Heroic/RPG dressing** over quit-habit tools:
  - *Victory Tracker* (day count) · *Epic Milestones* (locked until reached)
  - *Crisis Shield* (panic button) · *Daily Chronicles* (journal)
  - *Heroic Fellowship* (community/Discord) · *Habit Forge* (build/replace)
  - *Daily Inspiration* (wallpapers) · *Legendary Monthly Challenges*
- Strengths: free, no ads on core, "starts with the mind", hidden badges.
- Weaknesses: navigation is confusing (dev admits it), sign-in friction,
  thin data/analytics, no real progression system (it's a themed quit counter).

### Solo Leveling clones
- Numerous ad-hoc "System" habit trackers exist (Notion templates, simple apps).
- Most **borrow the blue-window aesthetic** and stop there — a themed checklist,
  no real mechanics. Nobody has built the full stat/rank/quest/penalty economy.
  **That gap is our opening.**

## 6. Cross-cutting lessons → Arise design principles

| # | Lesson | Source | Our move |
|---|---|---|---|
| 1 | Pure streaks cause shame spirals | Way of Life, r/getdisciplined | HP + freezes; never reset to zero |
| 2 | Skipping should be first-class | Way of Life | "Protected" misses, limited per month |
| 3 | Identity beats blocking | ZFA review | Identity/title system; friction is opt-in |
| 4 | Badges hidden until earned | ZFA review | Locked titles/shadows revealed on reach |
| 5 | Recoverable damage > account reset | Habitica, Penalty Zone | Penalty = time cost, never wipe |
| 6 | The widget is the product | Streaks | System-widget-first UI |
| 7 | Friction needs a substitute | Blockers | Every urge gets a redirect action |
| 8 | Free + no-ads core wins trust | ZFA | Offline, no account, no ads |
| 9 | Themed checklists are common; real economies are not | clones | Build the full economy |
| 10 | Daily pledge + evening review = ritual | I Am Sober | Morning quest-accept + night report |

## 7. Positioning statement

> Most habit apps count. Most quit apps wait. Most blockers block.
> **Arise** turns discipline into a System: a daily quest, real consequences,
> visible stats, earned titles, and a record of who you're becoming — fully
> offline, no account, no ads, no shame.
