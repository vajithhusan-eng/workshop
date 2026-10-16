# Psychology & Behavioral Design — Research + Ethics Policy

The behavioral science behind **Arise**, plus an explicit catalog of "dark
psychology" techniques so we know what they are, when they cross from persuasion
into manipulation, and which ones we refuse to ship.

> Framing rule for this whole document: **every technique here is
> double-edged.** The ethical question is never "do we use psychology?" (every
> app does) — it is *"does it serve the user's stated goal, or the app's?"*

---

## Part 1 — The science of behavior change

### 1. Habit formation fundamentals

**Wood & Neal 2007 (*Psychological Review*).** ~43% of daily behavior is
habitual — cue-triggered, not willpower-driven. Habits are context-dependent
(cue → behavior → reward). Change the context and the cue vanishes (why travel
and moving disrupt habits).

**Lally et al. 2010 (*Eur. J. Social Psychology*).** Tracked 96 people adopting
a daily behavior. Median time to *automaticity*: **66 days** (range 18–254,
depending on complexity). Two critical corollaries:
- The "21-day habit" rule is a **myth**. Apps that promise 21-day transformation
  set users up to quit on day 22.
- **Missing a single day does not derail formation.** "One bad day ruins it" is
  unsupported by the data.

**Design consequence:** set 60–90 day expectations, handle misses without drama.

### 2. The Fogg Behavior Model (B = MAT)

**BJ Fogg 2009 (Stanford Behavior Design Lab).** A behavior happens only when
**Motivation × Ability × Trigger** all converge above threshold. Missing any one
→ no behavior, regardless of the others.

- **Motivation** — pleasure/pain, hope/fear, social acceptance/rejection.
  Volatile; expensive to create. *Don't design for it.*
- **Ability** — time, money, physical effort, brain cycles, social deviance,
  non-routine. Every friction point lowers it. *Collapse these.*
- **Trigger** — the prompt (notification / cue). Types: *sparks* (low
  motivation), *facilitators* (low ability), *signals* (both fine).

**Practical law:** make the action trivially easy and fire the trigger at the
right moment; motivation then takes care of itself.

Fogg's "Tiny Habits" corollary: shrink the behavior until motivation is
irrelevant ("log just one thing today"). And — **emotion, not repetition, forms
habits**; celebration right after the behavior is the mechanism.

### 3. High-leverage interventions (by effect size)

| Technique | Source | Effect | Our use |
|---|---|---|---|
| **Implementation intentions** ("if X, then Y") | Gollwitzer 1999; meta d≈0.65 | ~2× completion | Onboarding wizard builds if-then triggers |
| **Habit stacking** (anchor to existing cue) | Wood 2007 | Strong | "right after your morning coffee" |
| **Tiny / minimum-viable action** | Fogg 2019 | Strong | Quest steps are one-tap |
| **Goal-setting theory** (specific, challenging, attainable) | Locke & Latham 2002 | Foundational | XP targets, rank thresholds |
| **Self-efficacy** (mastery experiences, small wins) | Bandura 1977 | Foundational | Early guaranteed wins |
| **Reflection/metacognition** | — | Moderate | Night report (§ tying to I Am Sober) |

### 4. Self-Determination Theory (Deci & Ryan 2000)

Three core needs: **Autonomy, Competence, Relatedness**. Intrinsic motivation
(durable) grows when these are met; extrinsic rewards can *crowd out* intrinsic
motivation if they feel controlling rather than informational.

**Design consequence:** gamification is **scaffolding for the first 60–90 days**,
then the intrinsic rewards (feeling stronger, calmer, in control) must take over.
An app that never weans off points/badges designs for engagement, not change.

---

## Part 2 — The technique catalog

40+ techniques across 7 categories (synthesized from the 2026 tracking-app
behavioral encyclopedia + primary sources). Rated on benefit vs. risk.

### 2.1 Gamification
Streaks · points/badges · levels/progression · leaderboards · challenges ·
daily quests.
- **Evidence:** small-to-moderate engagement gains (Hamari 2014); strong 60–90
  day retention.
- **Risk:** streak anxiety; extrinsic burnout; pay-to-progress.
- **Line:** tied to *real behavior* = fine. Tied to *time-in-app or upsell* =
  extractive.

### 2.2 Habit formation
Habit stacking · Fogg trigger (B=MAT) · tiny habits · implementation intentions ·
daily ritual anchoring · the 21-day myth vs. Lally's 66 days. (See Part 1.)

### 2.3 Behavioral economics
- **Loss aversion** — losses ~2× gains (Kahneman & Tversky 1979). Engine of
  streaks. Powerful; easily weaponized into anxiety.
- **Commitment devices** — pre-commit with stakes (Ashraf/Karlan/Yin 2006;
  stickK). Effective; punishment-based stakes harm relapse users.
- **Default bias** — people accept defaults (Johnson & Goldstein 2003). Use for
  good defaults; never for upsell defaults.
- **Present bias / hyperbolic discounting** — future rewards feel weak; apps
  compress the distance ("at this pace, goal in 6 weeks").
- **Anchoring** (Tversky & Kahneman 1974) — first number sways judgment.
  Goal-calibration yes; price-anchoring manipulation no.
- **Endowment effect** (Thaler 1980) — once progress feels "yours," you resist
  losing it. Deepens commitment; also the subscription-trap lever.

### 2.4 Social psychology
Social proof (Cialdini 1984) · peer comparison (Festinger 1954) ·
accountability partners · family/couples tracking · group challenges ·
testimonials/narrative transportation.
- Accountability partners have strong evidence; peer comparison is *mixed* and
  risky for vulnerable users. → **opt-in, private cohorts only.**

### 2.5 Nudge theory (Thaler & Sunstein 2008)
Nudges, framing, choice architecture, salience, simplification.
- Preserve autonomy, don't restrict choice. The abuse mode is "sludge" —
  friction against the user's own interest (e.g. cancellation).

### 2.6 JITAI — Just-In-Time Adaptive Interventions (Nahum-Shani 2018)
Contextual notifications · adaptive reminder timing · stress-moment alerts ·
pre-action intention prompts · post-action reflection.
- **The ethical gold standard for notifications:** fire when behavioral signals
  suggest the user would *benefit*, not when engagement metrics dip.
- **Make the rationale visible** ("you usually do this around now") to keep the
  user in control.

### 2.7 Motivation & reward
- **Variable reinforcement** (Skinner 1957) — unpredictable rewards produce the
  strongest conditioning. *This is the slot-machine / social-feed engine — the
  single most addictive mechanism on the list.*
- Progress visualization (progress triggers dopaminergic advancement signals).
- Celebrations / personal records (reward-prediction error).
- Goal-setting theory, self-efficacy (see Part 1).

---

## Part 3 — "Dark psychology": the manipulation catalog

The user asked specifically about dark psychology. Below is the honest catalog —
both the **interpersonal** manipulation toolkit and the **product** dark
patterns — followed by our hard red lines.

### 3.1 Interpersonal persuasion vs. manipulation (Cialdini and beyond)

**Cialdini's six principles** (1984) — persuasion's base layer:
reciprocity, scarcity, authority, consistency/commitment, liking, social proof.

The **darker** extensions (used to control rather than inform):
- **Foot-in-the-door** — small ask first, escalation later.
- **Door-in-the-face** — absurd ask, then the "reasonable" one.
- **Lowball** — get agreement, then change the terms.
- **Bait-and-switch** — promise one thing, deliver another.
- **FUD** (fear, uncertainty, doubt) — manufacture threat to force compliance.
- **Fear-then-relief** — spike anxiety, then sell the relief.
- **Guilt / shame / obligation** — leverage self-image to coerce.
- **Gaslighting** — erode someone's trust in their own perception.
- **Love-bombing** — overwhelming warmth to create dependency.
- **Identity manipulation** — "you're the kind of person who…" (identity is the
  single strongest influencer — usable for good *or* coercion).
- **Pre-commitment / public commitment** — bind the person to a position before
  they've weighed it.
- **Manufactured urgency/scarcity** — "only 3 left", countdown pressure.
- **False social proof** — fabricated popularity/testimonials.
- **NLP framing tricks** — presupposition, anchoring, mirroring.
- **Isolation** — cut off alternative support so you're the only source.

Every one of these appears in the wild in *habit, gambling, and self-improvement
apps*, often aimed at the user's wallet.

### 3.2 Product dark patterns (Brignull / deceptive.design taxonomy)

| Pattern | What it does |
|---|---|
| **Roach Motel** | Easy to sign up, hard to cancel |
| **Confirmshaming** | Guilt copy on decline ("No thanks, I'd rather fail") |
| **Fake scarcity / urgency / FOMO** | Manufactured pressure |
| **Fake social proof** | Invented users/testimonials |
| **Forced action** | Must do X to get Y |
| **Hidden costs** | Fees appear late |
| **Nagging** | Repeated intrusive prompts |
| **Obstruction** | Deliberately blocks a task |
| **Preselection** | Expensive option pre-chosen |
| **Sneaking** | Item added without consent |
| **Trick wording / visual interference** | Misleading copy or layout |
| **Comparison prevention** | Prices/features impossible to compare |
| **Currency confusion** | Obfuscated value (gems, coins) |
| **Privacy zuckering** | Over-sharing by design |
| **Addictive design** | Exploits vulnerabilities into compulsion |
| **AI-driven climactic dark patterns** | Personalised exploitation at scale |

The Center for Humane Technology (Tristan Harris) flags the tracking-app
crossings specifically: **streak-shame pop-ups**, **slot-machine variable
rewards**, **hard-to-cancel subscriptions**, **social comparison feeds harmful
to vulnerable users**, and **engagement-maximising notifications**.

### 3.3 The line: persuasion vs. manipulation

| | Persuasion | Manipulation |
|---|---|---|
| **Transparency** | Tells you what it's doing and why | Conceals the mechanism |
| **Beneficiary** | The user's stated goal | The app's metric/upsell |
| **Autonomy** | Opt-in, easy exit, reversible | Forced, hard to leave |
| **Emotion** | Motivation to act well | Guilt, shame, fear to coerce |
| **Timing** | When it helps the user | When engagement is low |

**Test question for every feature:** *does this help the user accomplish the goal
they chose, or does it help us accomplish ours at their expense?*

### 3.4 Our dark techniques — explicit red lines (we do NOT ship)

1. **No streak-shame.** Breaking a streak is handled neutrally ("protection
   engaged"), never "are you giving up?".
2. **No slot-machine variable rewards on health behavior.** Loot boxes are
   deterministic-plus-cosmetic, not compulsion-engineered.
3. **No fake scarcity/urgency/social proof.** Ever. Nothing is manufactured.
4. **No confirmshaming, no forced action, no roach motel.** One-tap everything.
5. **No guilt/shame/fear copy.** The System is strict, never cruel.
6. **No engagement-driven notifications.** All notifications are JITAI or
   user-scheduled, with visible rationale.
7. **No infinite feeds.** All screens have a natural end.
8. **No ads, no account, no data harvesting.** Offline by design (see
   SYSTEM-RESEARCH.md §offline constraint).
9. **No punishment that destroys progress.** Penalty = recoverable time cost.
10. **No identity coercion.** Titles reflect *what you did*, they don't
    shame *who you are*.
11. **No hidden costs / currency confusion.** If we ever monetise: one price,
    one tap to cancel, no gem economy.
12. **No exploiting vulnerability profiling.** Personalisation uses *your*
    declared goals and history only.

### 3.5 Dark techniques we DO borrow — transparently, for the user

We're not naive: some "dark" mechanics are genuinely useful **when the intent is
flipped**. Documented here so it's deliberate, not accidental.

| Technique | Dark use | Our ethical use |
|---|---|---|
| **Loss aversion** | Streak shame | HP/consequence that *motivates without shaming* |
| **Variable reward** | Slot machine | Deterministic loot tier + occasional cosmetic surprise, capped |
| **Commitment device** | Lock-in | User-authored quest contract *they control* |
| **Identity framing** | Coercion | Titles that *celebrate* earned identity |
| **Scarcity** | Fake FOMO | Real, honest time-limits on *self-imposed* challenges |
| **Social proof** | Fake popularity | Opt-in, private, honest cohort stats |
| **Anchoring** | Price games | Honest goal calibration |
| **Endowment** | Subscription trap | Ownership of *your own* progress, exportable |

---

## Part 4 — Arise master design rules (the synthesis)

1. **Ability first.** Collapse friction; one-tap everything (Fogg).
2. **Trigger at the right moment.** JITAI, transparent rationale, opt-in.
3. **If-then at onboarding.** Implementation intentions (2× effect).
4. **66-day honesty.** Never promise transformation in 21 days.
5. **Consequence without catastrophe.** HP/freeze model, never a reset.
6. **Reflection loop.** Morning quest-accept → evening report (I Am Sober).
7. **Hidden-until-earned reveals.** Curiosity gap in milestone design.
8. **Identity over restriction.** Titles and progression, not guilt.
9. **Scaffold then release.** Extrinsic rewards fade as intrinsic ones grow.
10. **Privacy is a feature.** Offline, no account, no ads, user-owned.
11. **Every urge gets a redirect.** Blocks pair with substitute actions.
12. **The System is strict, never cruel.** Tone: authoritative, never abusive.

---

## Part 5 — Key researchers (quick reference)

| Name | Work | Concept |
|---|---|---|
| BJ Fogg | 2009, 2019 | B=MAT; Tiny Habits |
| Wendy Wood | Wood & Neal 2007 | Cue-based habits; 43% automatic |
| Phillippa Lally | 2010 | 66-day automaticity; 21-day myth |
| Gollwitzer | 1999 / 2006 | Implementation intentions (d≈0.65) |
| Kahneman & Tversky | 1979, 1981, 1974 | Loss aversion; framing; anchoring |
| Thaler & Sunstein | 1980, 2008 | Endowment; Nudge |
| Deci & Ryan | 1985, 2000 | Self-Determination Theory |
| Nahum-Shani | 2018 | JITAI |
| Locke & Latham | 2002 | Goal-setting theory |
| Bandura | 1977 | Self-efficacy |
| Cialdini | 1984 | Influence; 6 principles |
| Skinner | 1957 | Operant conditioning; variable reinforcement |
| Duhigg | 2012 | The Power of Habit (cue-routine-reward) |
| Brignull | — | Dark patterns taxonomy |

## Part 6 — Sources

- Nutrola, "Every Psychology Technique in Calorie Tracking Apps: The Complete
  2026 Encyclopedia" (40+ techniques, research table, ethics axis)
- BJ Fogg — Stanford GSB interview + behaviormodel.org + Tiny Habits
- Lally et al. 2010; Wood & Neal 2007; Gollwitzer 1999/2006 (primary citations)
- CBR / Fandom — Solo Leveling quest & penalty behavior (see SYSTEM-RESEARCH.md)
- deceptive.design (Brignull) + Edin. open-course dark-patterns lecture
- Center for Humane Technology (Tristan Harris) — flagged manipulation patterns
- App sources: ZFA Play listing + reviews, iamsober.com, quitzilla.com,
  sobrmate.app, app-blocker roundups

---
*Status: research complete — feeds `docs/SYSTEM-DESIGN.md` and the app's ethics policy.*
