# Behavior Science — Deep Layer

> Companion to `PSYCHOLOGY.md`. That doc maps the *field*; this one drills the
> specific, citable mechanics we will actually build into the System. Every
> section ends with **→ Arise** — the concrete design consequence.
>
> Rule of this doc: no technique ships unless we can name the paper and the
> mechanism. This is the engineering spec, not the inspiration board.

---

## A. The Four Laws as an engineering spec (Clear, *Atomic Habits*, 2018)

Every habit runs a four-step loop: **Cue → Craving → Response → Reward**. Clear
turns each step into a law you can *design against*.

| Stage | Build a habit | Break a habit |
|---|---|---|
| Cue | Make it **obvious** | Make it **invisible** |
| Craving | Make it **attractive** | Make it **unattractive** |
| Response | Make it **easy** | Make it **difficult** |
| Reward | Make it **satisfying** | Make it **unsatisfying** |

Supporting claims Clear leans on:
- **1% compounding**: 1% better daily ≈ 37× over a year. Framing device, not a
  law — but it's the mental model users arrive with.
- **Identity is the deepest layer**: "Every action is a vote for the type of
  person you wish to become." Behaviour change that sticks is identity change.
- **Environment beats willpower**: people with high self-control structure their
  lives to *need* less of it.
- **Two-Minute Rule**: shrink any new habit to a ≤2-minute version to establish
  the cue→response link before optimising.
- **Habit stacking**: `After [CURRENT HABIT], I will [NEW HABIT].`
- **Never miss twice**: "Missing once is an accident. Missing twice is the start
  of a new habit." ← this is the single most important line for our streak design.

**→ Arise**
- Encode the loop explicitly. Every quest has a **cue** (the System window at a
  set time), a **craving** (the rank/XP promise), a **response** (the marked
  action), and a **reward** (immediate, visible).
- Ship a **two-minute version** of every quest at creation ("minimum viable
  quest"). Marking the 2-minute version must still count — kills all-or-nothing.
- **Habit stacking becomes "chained quests"**: `After [Quest A], then [Quest B]`.
- Build identity into ranks: `You are becoming a Hunter who trains daily.`
- **Never-miss-twice is a first-class rule**: a single miss costs HP; the *second*
  consecutive miss is where the penalty escalates. (Details in ROADMAP.)

---

## B. Stages of Change — match the intervention to readiness (Prochaska & DiClemente)

Also called the **Transtheoretical Model (TTM)**. Behaviour change is a *process*
through stages, and the right tool depends on which stage the person is in.
Forcing "Action"-stage interventions on a "Contemplation"-stage person causes
reactance and churn.

| Stage | What it looks like | What actually helps |
|---|---|---|
| **Precontemplation** | No intention to change in next 6 months | Raise awareness; don't push. Provide *info*, not demands |
| **Contemplation** | Aware, intends to change within 6 months | Decisional balance (pros/cons); build self-efficacy |
| **Preparation** | Intends to act within 30 days; early steps | Concrete plan, start date, commitment device |
| **Action** | Behaviour changed < 6 months | Cues, rewards, removal of friction, social support |
| **Maintenance** | Behaviour sustained > 6 months | Relapse prevention, habit automaticity, identity |
| **Termination** | No temptation to return | (Rare; most stay in Maintenance) |

- **10 Processes of Change** (cognitive: consciousness raising, self-re-evaluation,
  environmental re-evaluation, dramatic relief, self-liberation; behavioural:
  counter-conditioning, helping relationships, reinforcement management,
  stimulus control, social liberation). Cognitive ones drive early stages;
  behavioural ones drive Action/Maintenance.
- **Rule of thumb** for at-risk populations: ~**40% precontemplation, 40%
  contemplation, 20% preparation** — most people who need the app aren't ready
  to "just start."
- **Relapse is a stage, not a failure.** Modern TTM loops back rather than
  ending.

**→ Arise**
- **Onboarding must stage-detect, not assume.** Ask "how ready are you?" and
  route: a Contemplation user gets a lightweight "witness" mode (track without
  commitment); a Preparation user gets a starting ritual + first commitment;
  an Action user gets the full System immediately.
- Never shame the not-ready. The System *waits* — it doesn't punish someone who
  hasn't committed.
- A relapse returns the player to the appropriate stage with a **shortened**
  climb, not a wipe. (See §C — this is the AVE guard.)

---

## C. Relapse Prevention — lapse vs relapse, AVE, and urge surfing (Marlatt & Gordon, 1985)

The clinical model underneath every serious quit-app. Four moving parts:

1. **High-risk situations** — negative emotional states (stress, anger,
   loneliness), interpersonal conflict, social pressure, exposure to cues.
2. **Coping skills** ← the hinge. Without them, self-efficacy drops.
3. **Decreased self-efficacy** → higher probability of a lapse.
4. **Abstinence Violation Effect (AVE)** — after a lapse, attributing it to
   *personal failure* produces guilt/shame, which predicts a full **relapse**.
   Attributing it to a *situational learning experience* predicts re-engagement.

> "A lapse becomes dangerous when it is translated into identity, not when it
> happens." → The AVE is an **identity event**, and identity events are exactly
> what a System can control.

**Urge surfing** (Marlatt & Kristeller): visualise the craving as a **wave** —
it crests and washes out. Observe it without acting. Cravings peak and *subside
quickly* if not fed. Also the base of Mindfulness-Based Relapse Prevention (MBRP).

**Lapse ≠ Relapse**. `Lapse` = a slip, then return. `Relapse` = uncontrolled
return to prior severity.

**→ Arise** 🎯 *This is our single most important clinical input.*
- **Design the AVE out.** A missed day must never be framed as identity failure.
  Copy must attribute to *situation* ("the trigger won"), never to *self*
  ("you're weak"). This directly serves our no-shame red line.
- **Miss = HP loss + a "Recovery Quest", never a wipe.** The streak mechanic is
  the highest-risk shame generator in any habit app (see APP-LANDSCAPE §streaks);
  we defuse it with a *bounded* penalty and an explicit path back.
- **Ship "Urge Surf" as a real in-app tool** — the Crisis Shield that ZFA users
  praised. A timed screen: name the urge, watch it crest and fall (~10 min),
  then either log resistance (+) or log a lapse without shame.
- **Distinguish the words in the UI**: "stumble" (lapse) vs "collapse"
  (relapse). The System's language shapes the identity reading.

---

## D. Habit Reversal Training — the clinical method for *removing* a bad habit (Azrin & Nunn, 1973)

The evidence-based procedure when the goal is to *stop* something (nail-biting,
tics, trichotillomania, skin-picking, stuttering, face-touching). Five components:

1. **Awareness training** — describe the habit's *topography* in detail; learn to
   catch the *earliest* component. (Response description, with mirror if useful.)
2. **Competing response training** — perform a behaviour physically incompatible
   with the habit; hold it ≥1–3 min each time the urge hits *and* each time you
   catch yourself doing it. It need not be anatomically "opposite" to work.
3. **Contingency management** — social/self-reinforcement for success.
4. **Relaxation training** — lower baseline arousal (often the habit's trigger).
5. **Generalization training** — practise across contexts until it holds.

Azrin & Nunn reported ~95% reduction after 1 day, ~99% after 3 weeks from a
single session (self-report). Meta-analytic support (Bate et al., 2011).

**→ Arise**
- For "bad habit" quests, don't just track absence — build a **competing
  response**: when the urge fires, the System prompts a named replacement action.
- **Awareness training = trigger mapping.** Ask the user to log the *earliest*
  cue ("what was happening 30 seconds before?"). Store it; surface it later as a
  pattern ("your urge fires most on weekday evenings").
- **Relaxation** is a legit quest type: breathwork, walk, cold water — the
  physiological off-ramp.

---

## E. Self-Monitoring & the Measurement Effect — and its dark side

- **Harkin et al. (2016)**, meta-analysis of 138 studies: **self-monitoring is
  the single most effective self-regulation strategy** for goal attainment, and
  it held across health, academic, financial, and productivity domains. This is
  the strongest single citation we have for *why the app works at all*.
- Mechanism: **reactivity** — merely observing a behaviour changes it ("That
  which is measured improves"; part Hawthorne effect, part dopamine feedback,
  part cognitive offloading).
- **The dark side** (Etkin; Burke et al.): tracking can make an *enjoyable*
  activity feel like **work**, reducing enjoyment and continued engagement.
  Users describe tracking as "oppressive and 'punishy'." Over-tracking can
  suppress the very behaviour it measures.

**→ Arise**
- **Tracking is the product.** Being measured daily *is* the core intervention —
  not a side feature. Invest in making the log feel meaningful, not clerical.
- **Don't over-track.** Cap logging to what a real decision needs. Explicitly
  *avoid* making fun activities feel like chores — do not force a log on things
  the user enjoys.
- Offer a **"log-free streak"** for maintenance-stage users so the System can
  recede as the habit automates. Tracking is scaffolding, not a cage.

---

## F. Commitment Devices — hard vs soft (Bryan, Karlan & Nelson, 2010)

A commitment device = any arrangement you *voluntarily* enter to make quitting
more expensive than continuing. Two ends of one spectrum:

- **Hard**: real, irreversible cost — money, public exposure (stickK-style
  stakes; forfeit to a charity, or an *anti-charity* for extra bite).
- **Soft**: low-stakes nudge — **a visible streak you don't want to reset.**

Key findings:
- **Loss aversion ≈ 2×**: losing hurts ~twice as much as the equivalent gain
  feels good (Kahneman & Tversky). This is the engine behind soft commitments.
- **Mixed beats single**: stickK data (Lee, Kim, Hong & Lee, 2021, CHI) — financial
  stakes **+ social accountability** outperformed either alone.
- **Longer > shorter**: NBER RCT — people nudged toward *longer* contracts were
  more likely to hit goals.
- **Caveats**: zero-dollar wagers strip the mechanism; gains often fade after the
  contract ends; self-selection inflates observed success rates.

**→ Arise**
- **A streak is already a soft commitment device** — treat it as load-bearing
  infrastructure, and understand it runs on loss aversion. This is *why* streaks
  work, and also *why* they can wound (see §C).
- Offer a **Honest Stake** feature: the user pledges their *own* in-app currency
  (gold) — not real money — to a goal. Fail → the gold is gone. Hard-ish, zero
  exploitation, no dark-pattern anti-charity.
- **Encourage a social layer** (accountability partner) *on top of* the personal
  one — mixed settings are the evidence-backed configuration.
- **Endow the start** (see §G) so day one already has a "stake" to lose.

---

## G. Progress Illusion — endowed progress & the goal-gradient effect

- **Goal-gradient effect (Hull, 1932)**: effort rises as the goal gets *closer*.
- **Endowed progress effect (Nunes & Drèze, 2006)**: give people a **head start**
  and they work harder to finish. Car-wash card A: 8 stamps from empty → **19%**
  redemption. Card B: 10 stamps with **2 pre-filled** → **34%** redemption. Same
  real work; different perception.
  - **Moderator**: the head start must have a *reason* ("welcome bonus") or the
    effect disappears. An unexplained gift reads as a glitch.

**→ Arise**
- Every new player starts at **Level 1 with a small, justified head start** — the
  System grants a "First Awakening" bonus with a reason, so the first bar is
  already part-filled. (Make it *honest*: it's a genuine onboarding grant, not a
  fake number — our honesty rule.)
- Show **progress bars everywhere**, and accelerate the *perceived* pace near
  completion (the last 10% should animate faster — it mirrors real motivation).

---

## H. The Fresh Start Effect (Dai, Milkman & Riis, 2014)

Aspirational behaviour spikes after **temporal landmarks** — new week, month,
year, birthday, semester, holiday. Mechanism: a landmark creates **psychological
segregation** from your "past inferior self," which lets you act on better
intentions without the drag of recent failure.

- Effects vary by landmark size: New Year > Monday > Tuesday > … The effect
  **decays fast** if not followed up within the window.

**→ Arise**
- **Seasonal resets are core UX, not decoration.** The "Winter Trials" etc. from
  the v20 arc are the fresh-start effect, productised.
- Offer a **"Fresh Start Quest"** on Monday / 1st-of-month / after a relapse —
  frame it as the System "re-instancing" the player, explicitly severing the past
  self. This doubles as our AVE fix.
- **Follow up inside the window** — the day-after-landmark is when motivation is
  highest and when the first quest must land.

---

## I. Temptation Bundling (Milkman, Minson & Volpp)

Bundle something you *should* do with something you *want* to do: only listen to
your favourite podcast while at the gym. Raises the appeal of the hard behaviour
by pairing it with an immediate reward.

**→ Arise**
- Let the user attach a **"bundle"** to a hard quest — an audiobook, a show, a
  coffee they only get during that quest. The System displays it as loot attached
  to the quest, not a separate reward.

---

## J. One-page build spec (what these produce)

| Mechanic | Science it implements | Guardrail |
|---|---|---|
| System window at set time | Cue (A), stimulus control (B) | User sets time; no engagement-driven timing |
| 2-minute minimum quest | Two-Minute Rule (A) | Marking minimum still counts |
| Never-miss-twice penalty | Clear (A) + AVE guard (C) | Bounded; never a wipe |
| Recovery Quest | AVE / RP (C) | Situational attribution, zero shame copy |
| Urge Surf screen | MBRP / urge surfing (C) | Logs resistance *and* lapses without judgement |
| Trigger mapping on bad habits | HRT awareness (D) | User-owned data; surfaced as insight |
| Competing-response prompt | HRT (D) | Replacement is user-chosen |
| Daily log | Measurement effect (E) | Cap it; don't over-track; fun stays fun |
| Streak as commitment device | Loss aversion (F) | Never designed to wound; freeze exists |
| Honest Stake (in-app gold) | Commitment device (F) | In-app currency only; no real money |
| First-Awakening head start | Endowed progress (G) | Must have a stated reason |
| Seasonal Trials / Fresh Start | Fresh start effect (H) | Follow up inside the window |
| Bundle a hard quest to a treat | Temptation bundling (I) | User-defined; System only displays it |
| Stage-detected onboarding | TTM (B) | Never push a not-ready user |

---

## Sources

- Clear, J. *Atomic Habits* (2018) — four laws, never-miss-twice, identity.
- Prochaska & DiClemente — Transtheoretical Model / Stages of Change; Prochaska &
  Velicer (1997), *Am J Health Promot* 12(1):38–48.
- Marlatt & Gordon, *Relapse Prevention* (1985); Marlatt & Kristeller, urge
  surfing; Witkiewitz & Marlatt (2004) dynamic model; MBRP literature.
- Azrin & Nunn (1973), *Behav Res Ther* 11:619–628, habit-reversal; Bate et al.
  (2011) meta-analysis, *Clin Psychol Rev* 31:865–871.
- Harkin et al. (2016) self-monitoring meta-analysis (138 studies); Etkin (2016)
  on tracking reducing enjoyment; Burke et al. on "oppressive and 'punishy'".
- Bryan, Karlan & Nelson (2010), *Annual Review of Economics* 2:671–698; Lee, Kim,
  Hong & Lee (2021, CHI) stickK dataset; NBER WP 21406 (contract length).
- Nunes & Drèze (2006), *J Consumer Research* 32(4):504–512 (endowed progress);
  Hull (1932) (goal gradient).
- Dai, Milkman & Riis (2014), *Management Science* 60(10):2563–2582 (fresh start).
- Milkman, Minson & Volpp — temptation bundling.
