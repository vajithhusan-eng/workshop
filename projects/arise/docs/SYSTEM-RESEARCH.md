# The System — Behavioral & Mechanical Research (Solo Leveling)

Research compiled from the Solo Leveling manhwa/webtoon, light novel, and the
official Solo Leveling Wiki (solo-leveling.fandom.com) as the source of truth
for how "the System" behaves. This document is the design reference for the
habit/routine/discipline app (working name **Arise**).

**Purpose:** capture the *mechanics* faithfully so we can rebuild their
psychological effect with original content. See §12 — IP boundary.

---

## 1. Player acquisition

- The System selects a single **Player** — chosen from a self-sacrificing act
  (Jinwoo stayed behind in the Double Dungeon so his party could escape).
- Greeting: *"Congratulations on becoming a Player."*
- System status messages are terse, imperative, and formal:
  - *"The system is designed to assist the development of the Player."*
  - *"Failure to comply with the system may result in a penalty."*
  - *"The rewards have been delivered."*
- Only the Player can see the interface. Nobody else.
- Underlying lore (relevant only as *tone*): the System is a game-like wrapper
  built so a human could understand its rules without confusion — **the game
  metaphor is deliberate design, not decoration.**

## 2. Status window (the core screen)

Fields shown:

| Field | Notes |
|---|---|
| Name | Player identity |
| Level | 1 → 100 cap |
| Job | Locked until Job Change Quest; evolves afterward |
| Title | Equipped achievement label, grants passive effect |
| HP | Hit points (health/durability) |
| MP | Mana points (skill fuel) |
| Fatigue | Separate indicator — recovery matters, not just HP |
| Stats | STR / AGI / VIT / INT / PER (see §3) |
| Ability points | Unspent allocation points |

**Design note:** HP and *Fatigue* are separate. Rest is a distinct resource from
health — directly mappable to a habit app's "recovery" concept.

## 3. The five stats

| Stat | Effect in-system | Real-life habit mapping (ours) |
|---|---|---|
| **Strength** | Physical power, attack, speed | Exercise / physical habits |
| **Agility** | Dynamic vision, reaction speed, evasion | Consistency / speed of showing up |
| **Vitality (Stamina)** | Max HP + recovery speed | Sleep, health, recovery habits |
| **Intelligence** | Max MP + MP recovery | Study / learning habits |
| **Perception (Sense)** | Sharpens 5 senses, danger sense | Mindfulness / awareness habits |

Key rules:
- **Every level-up: all stats +1 automatically** (baseline growth is free).
- **Daily quest completion: +3 stat points** to allocate freely (player agency).

## 4. Leveling

- XP gained from quests, combat, and training.
- Level-up effects: **all stats +1, full recovery from damage/fatigue.**
- Ability points come from two sources: leveling up, and daily quest rewards.
- Level cap: **100** (canonical — at level 100 the System's endgame triggers).
- Ranks are *not* levels — see §9.

## 5. Quest taxonomy (the heart of the app)

### 5.1 Daily Quest — *"The Preparation to Become Powerful"*

| Field | Value |
|---|---|
| Goal | 100 Push-Ups · 100 Sit-Ups · 100 Squats · 10 km Run |
| Time limit | **24 hours**, shown as a circular countdown |
| Rewards | 1) **Status Recovery** (full heal) · 2) **+3 stat points** · 3) **Random loot box** |
| Penalty on failure | **Penalty Zone** (§6) |

Behavioral details worth copying:
- Fixed, non-negotiable, *small* task set — no daily decision fatigue.
- Countdown always visible → deadline pressure.
- Three-part reward: *relief* (full recovery), *agency* (+3 points to spend),
  *surprise* (loot box — variable reward schedule).
- Failure warning printed under the list: *"Failure to complete the daily quest
  will result in an appropriate penalty."*

### 5.2 Main Quests
- Larger objectives, **massive rewards**, typically no explicit penalty.
- Persist until completed (story progression).

### 5.3 Urgent / Emergency Quests
- Triggered when a genuine lethal threat is detected (e.g. an assassination
  attempt), or as the penalty-quest override.
- Forced activation — the player cannot decline.
- **Failure = death** (no System protection inside an Emergency Quest).
- Rewards: **Rune Stones** — absorbing one grants a skill permanently
  (source of Stealth, Bloodlust, etc.).

### 5.4 Job Change Quest
- Received at **level 40**.
- Instruction: *"The Job Change Quest will now begin. You will accumulate more
  points the longer you stay alive. These points are needed to advance to a
  higher-ranking class. Good luck."*
- Goal: **last as long as possible** in a bespoke instance dungeon.
- Rewards: Job class (Necromancer → hidden class **Shadow Monarch**),
  Title *Conqueror of Adversity*, skills *Shadow Extraction* & *Save Shadow*,
  bonus stats.
- Penalty: presumably death; failing locks the job skill tree.

### 5.5 Secret Quests
- Rare; triggered by special behavior (e.g. genuine bravery), not by schedule.

### 5.6 Reward/penalty matrix (canonical)

| Quest type | Success reward | Failure penalty |
|---|---|---|
| Daily | Status Recovery, +3 stat points, loot box | Penalty Zone: 4 hours, giant centipedes |
| Story/Main | Class items, abilities, titles, unique equipment | Stays incomplete; no explicit penalty |
| Job Change | Class assignment (+evolution if threshold met) | No class; skill tree locked |
| Emergency/Urgent | Rune Stones → permanent skill | Death |

## 6. The Penalty Zone

- Trigger: Daily Quest not completed within 24 hours.
- Message: *"The daily quest could not be completed. Move to the 'penalty
  zone' for a set time."*
- **Duration: 4 hours fixed — no early exit.**
- Environment: endless desert; no wind, no sun, no moon, no stars; sky like
  black ink — yet visibility is clear.
- Threat: **Poison-fanged Giant Sand Centipedes.**
- **Anti-exploit:** the Zone's difficulty readjusts if the Player tries to *hunt*
  inside it — you cannot farm the penalty for gain.
- Escape condition: survive the full 4 hours.

**Psychology:** the penalty is *harsh but survivable and finite*. It never
deletes progress permanently — it costs time and comfort. That's the model for
our penalty design: consequence without demotivation.

## 7. System Shop & Inventory

### Shop (Store)
- Currency: **gold** — earned by completing quests, defeating monsters, or
  selling items.
- Unlocks at higher level (sources indicate ~level 40).
- Sells: consumables (HP/MP/stamina recovery), equipment, weapons
  (e.g. *Knight Killer* dagger), and loot boxes.
- Stock **scales to the Player's current level.**
- Special boxes:
  - **Blessed Random Box** — grants an item the Player *wants*.
  - **Cursed Random Box** — grants an item the Player *needs*.

### Inventory
- A pocket dimension — **unlimited capacity**.
- Items cannot be forcibly taken from the Player.
- Some items are non-transferable; transactions with non-Players are impossible.
- On pickup, an item-detail window appears automatically.

## 8. Skills & Titles

### Skills
- Categories: **Active** (manual activation, costs MP/cooldown), **Passive**
  (always on), **Unique** (rare, special individuals).
- Skills **level up with use/player level** and evolve into enhanced versions.
- Typically cost Mana; a few don't.
- Acquisition: Rune Stones (permanent), Job class skill tree, quest rewards.

### Titles
- Earned by achievement; **one is equipped at a time** and grants a passive.
- Canonical examples:
  - **Wolf Slayer** — all stats +40% vs. beast-type monsters.
  - **The One Who Overcame Adversity** — early-game default; replaced as new
    titles are earned (titles *supersede* each other).
  - **Courage of the Weak** — *Will to Recover* (restores damaged body parts),
    *Health and Longevity* (immunity to disease/poison/abnormal status,
    greatly enhanced regeneration during sleep).
  - **Conqueror of Adversity** — awarded for the Job Change Quest.

**Pattern:** titles are *identity labels with mechanical weight*. The right
title equipped = a real passive bonus. (Maps to our "equipped achievement"
system.)

## 9. Ranks & classes

- Hunter ranks: **E → D → C → B → A → S**, plus unofficial **National-level**
  above S.
- Rank is assigned **at awakening** by measured magical power and normally
  **never changes for life** — Jinwoo is the sole exception (the Player who can
  level).
- Class types (six official): **Fighter, Mage, Healer, Tanker, Ranger,
  Assassin.**
- Difficulty colors on enemies/names are *relative to the Player's current
  power* — an orange (dangerous) name turns white once you outgrow it.

**This last point is the single best feedback mechanic in the series:** the
world doesn't get easier objectively — *your progress is visualized by things
that used to be scary turning white.*

## 10. Interface voice & UX cues

- Translucent blue System windows; panels snap into view; circular countdowns.
- Messages arrive as *notifications the player didn't ask for* — the System
  initiates.
- Failure notices precede consequences (warned, then punished).
- Reward delivery is announced explicitly ("The rewards have been delivered").
- The System **protects the Player**: warns of murderous intent, activates
  passives in danger, forces emergency quests — its rules are strict but its
  orientation is *keep the player alive and growing*.

## 11. Behavioral design principles (extracted)

| # | Mechanic | Psychology | Habit-app application |
|---|---|---|---|
| 1 | Fixed 4-item daily, 24h countdown | No decision fatigue; deadline urgency | Pre-set daily quest templates, visible timer |
| 2 | Full recovery + 3 free points + loot box | Relief · agency · variable reward | Streak heal + stat allocation + random reward |
| 3 | Penalty = 4h survivable ordeal | Loss aversion without progress wipe | Timed penalty quest, never delete the save |
| 4 | Anti-exploit difficulty adjust | Stops gaming the system | No farming penalties for rewards |
| 5 | Level-up: all stats +1 free | Baseline growth feels automatic | Passive growth alongside choices |
| 6 | Titles with passive bonuses | Identity-based habits | Equipable achievements with real effects |
| 7 | Enemy color = relative to you | Progress visualization | Difficulty/colors recalibrate to your level |
| 8 | HP vs Fatigue as separate bars | Rest ≠ health | Recovery tracked distinctly |
| 9 | Level cap (100) | Achievable endgame | Known goalpost, then prestige content |
| 10 | System initiates, you respond | Authority + commitment | Notification as the System speaking |
| 11 | Fixed non-negotiable core quests | Minimum viable discipline | Non-editable "core dailies" + custom quests |
| 12 | Shop scales with your level | Rewards stay relevant | Rewards escalate with progression |

## 12. IP boundary (important)

Solo Leveling's **mechanics are not protectable** — daily quests, penalties,
stats, ranks, titles, loot boxes are ideas/systems, and gamified habit tracking
exists independently (Habitica, etc.).

**What we must NOT ship:** copyrighted *expression* — character names (Sung
Jinwoo), the title "Solo Leveling," skill names (Shadow Extraction, Ruler's
Hand), item names (Kasaka's Venom Fang, Knight Killer), location names
(Penalty Zone as-is, Cartenon Temple), monster names (Poison-fanged Giant Sand
Centipede), and the specific trade dress of the manhwa's blue windows.

**Rule for the app:** copy the *behavioral structure* (12 principles above),
rename everything. Original flavor suggestions live in
`docs/NAMING.md`. "Arise" as a working name is evocative without being the
phrase's sole owner, but final naming needs a trademark-style sanity check.

## 13. Sources

- solo-leveling.fandom.com — pages: *System*, *Quests*, *Penalty Zone*,
  *The Preparation To Become Powerful*, *Job Change Quest*, *Skills*
  (retrieved via MediaWiki API, Oct 2026)
- CBR — "Solo Leveling's Quest Log, Explained" (quest reward structure, stat
  table level 1–2)
- Solo Leveling wiki/system video explainers (4h penalty, shop level gate,
  status window fields, level cap 100)
- Solo Leveling (webtoon) chapters 10–11, 41, 101, 130, 163 — canonical
  behavior references

---
*Status: research complete — ready to feed into system design (`docs/SYSTEM-DESIGN.md`).*
