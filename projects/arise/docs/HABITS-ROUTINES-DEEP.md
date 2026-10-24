# Habits & Routines — Deep Knowledge Base

> The user asked for *every kind of knowledge* on habits and routines from the
> web, understood *before* we build. This is that knowledge, organised for
> engineering: each finding is paired with what it changes in Arise.
>
> Companions: `BEHAVIOR-SCIENCE-DEEP.md` (the intervention mechanics and their
> citations) and `PORN-MASTURBATION-CONTROL.md` (the compulsive-use case).

---

## 1. What a habit actually is

A **habit** is a learned, context-cued response that runs with minimal
deliberation. It is not a decision you repeat; it is a *memory* that the context
retrieves for you.

- **Dual-process**: deliberate goal pursuit (slow, effortful, prefrontal) vs
  habitual response (fast, automatic, striatal). Most of daily behaviour is the
  second — Wood & Neal put it near **43%** of behaviour performed habitually in
  the same context.
- **Habit memory is non-conscious.** You can hold a strong habit and be unaware
  of it (Wendy Wood, 2024). This is why "just decide to change" fails: the
  decision never meets the cue.
- **Habit ≠ routine ≠ ritual.**
  | Term | What it is | Driven by |
  |---|---|---|
  | **Habit** | single automatic response to a cue | context + reward history |
  | **Routine** | an ordered *sequence* of behaviours, often partly deliberate | a script/anchor + repetition |
  | **Ritual** | a sequence invested with meaning/identity | symbol + emotion |

  A morning routine is a *routine* — a chain of habits anchored to each other.
  Arise models **quests** (habits) and **routines** (ordered chains) separately.

## 2. The loop

**Duhigg**: cue → routine → reward, and the thing that actually drives it is the
**craving** (the anticipation of the reward). **Clear's four laws** are the
engineering form:

| Law | Build a good habit | Break a bad one |
|---|---|---|
| **Cue** | make it obvious | make it invisible |
| **Craving** | make it attractive | make it unattractive |
| **Response** | make it easy | make it difficult |
| **Reward** | make it satisfying | make it unsatisfying |

Arise encodes the *build* side as the quest lifecycle, and the *break* side as
friction + cue-disruption (see §4).

## 3. How long it takes (and why the number matters)

- **Lally et al. 2010**: automaticity reached in **18–254 days**, **median ~66**.
  The "21 days" figure is a myth. **One missed day does not derail formation.**
- **Fournier et al. 2016/2017**: **morning** habits reached automaticity in
  ~**106 days**; **evening** habits ~**154 days** — mediated by **cortisol**
  (peaks on waking, nadir at bedtime). *Morning habits form faster.*
- **Johns Hopkins 2026**: the transition to habitual action happens **faster than
  long believed**, and a specific brain region appears to gate it.

> **Design consequence:** never promise "21 days". Show a *real* formation
> window, and let the System's language reflect that early repetitions are
> "training", not "failing to be automatic yet". Morning-anchored quests get a
> formation bonus in the copy (not in XP — fairness).

## 4. Context is the lever, not motivation (the most important finding)

**Wendy Wood, 2024** (*Current Directions in Psychological Science*, "Habits,
Goals, and Effective Behavior Change"):

- Habit activation **does not depend strongly on motivation**.
- Changing intentions has **limited impact** on habit memory.
- Interventions that work act **on the behaviour and its context**:
  1. **Reward systems** that build the new habit,
  2. **Disrupting context cues** so the old habit isn't triggered,
  3. **Friction** — make the habitual response hard and the alternative easy.
- People **wrongly believe** their own habits are goal-driven.
- **Life changes** (moving, a breakup, a new job) disrupt context — a rare
  window when habits are malleable. **Old routines re-emerge when the context
  returns.**

> **Design consequence:** Arise is a **context engine**, not a motivation app.
> Every quest carries a *cue* (time + place + preceding action). Onboarding asks
> for the cue, not the reason. When the user travels or moves, the System offers a
> **"context reset"** — re-anchor cues before old routines return.

## 5. Keystone habits

**Duhigg**: some habits cascade. **Exercise** is the best-documented keystone —
starting it is associated with less impulsive spending, less procrastination,
better eating, earlier dishwashing.

> **Design consequence:** the onboarding "seed quest" is a **keystone quest**
> (movement, sleep anchor, or a 2-minute tidy) because one win should spill over.
> The System should *name* the cascade ("This is a keystone — expect ripples").

## 6. Routine architecture — the daily scaffold

### 6.1 Morning
- **Light first**: bright outdoor light within **30–60 min** of waking (even
  overcast) — the strongest circadian anchor.
- **Hydrate** before caffeine.
- **Delay caffeine 90–120 min** after waking to avoid the afternoon crash.
- **Movement** early; optional cold exposure.
- Morning is when **cortisol** is high → **habits form faster** here (§3).

### 6.2 Evening / wind-down
- **Dim artificial light** in the last 1–2 hours; reduce screens.
- A **consistent wind-down sequence** + consistent bedtime is a standard
  circadian intervention.
- **Anchor sleep**: a regular **4-hour core sleep block** anchors the circadian
  rhythm to 24h even when the rest is irregular.

### 6.3 Chronotype
- Three types: **Morning / Evening / Neither** (extremes + moderates). It is a
  **stable trait**, not a preference.
- **Synchrony effect**: morning types peak in the morning; evening types peak
  **~12:00–16:00** and are worse in the morning. Evening types also carry more
  **sleep debt, caffeine, later meals, breakfast skipping**.
- Scheduling a habit against chronotype is a predictable failure.

> **Design consequence:** onboarding includes a **short chronotype check**
> (3–5 questions, not a 19-item MEQ). The System then *suggests* cue times in the
> user's peak window and *warns* — gently, once — when a quest is scheduled
> against type. Never blocks; the user owns the choice.

## 7. Building the chain

- **Habit stacking** ("After [CURRENT], I will [NEW]"): the existing habit is the
  cue. Chains are how routines form.
- **Implementation intentions** (Gollwitzer): "When [situation], I will
  [behaviour]" — ~**d≈0.65**, roughly double the success rate. This is the single
  cheapest, best-evidenced addition to a habit app.
- **Two-Minute Rule**: shrink the entry action to ≤2 minutes; expand later.
- **Start absurdly small** (one push-up) — the *identity* vote matters more than
  the volume.

> **Design consequence:** Arise's quest builder makes the **cue** a required
> field and offers a **"stack onto…"** picker. Routines are first-class: an
> ordered chain with a single anchor cue at the top.

## 8. Friction design (the break side)

- **Make the bad habit hard**: add steps, distance, delay. (This is why blockers
  partly work — until the user learns to route around them, the *circumvention
  paradox* from `APP-LANDSCAPE.md`.)
- **Make the good habit easy**: reduce steps to zero-ish; pre-commit the
  environment (lay out clothes, put the book on the pillow).
- **Cue disruption beats willpower**: change the context so the cue doesn't fire.

> **Design consequence:** every *bad-habit* quest in Arise has a **friction
> field** ("what makes this harder?") and a **cue-disruption field** ("what
> triggers it?"). Where the app can act on the device (notification-free windows,
> focus mode), it does; where it cannot, it prompts a physical change.

## 9. What actually predicts success

| Predictor | Strength | Arise response |
|---|---|---|
| Consistent **context/cue** | strong | cue required on every quest |
| **Implementation intention** written | strong (d≈0.65) | "When X, I will Y" field |
| **Self-monitoring** | strongest single strategy (Harkin 2016) | the daily log + status screen |
| **Never miss twice** | strong (AVE prevention) | streak shield logic |
| **Keystone first** | moderate-strong cascade | seeded keystone quest |
| Motivation at start | weak, decays | never the product's premise |
| Willpower/ego depletion | **contested** (replication failures) | never build on it |

> Note: **ego depletion is contested** — do not build a "willpower meter" that
> pretends a debunked resource model is real. (An HP system in v3 must be framed
> as *narrative stakes*, not as a scientific willpower reserve.)

## 10. Arise mapping — one table

| Finding | v1 | Later |
|---|---|---|
| Habit = context-cued memory | cue required per quest | context-reset flow (v2) |
| 66-day median, morning faster | formation copy, no day promises | formation curve in analytics (v7) |
| Wood 2024: disrupt cues + friction | friction/cue fields on bad habits | device-level focus windows (v4) |
| Keystone cascade | seeded keystone quest | keystone detection from logs (v7) |
| Chronotype/synchrony | 3–5 q check, suggested cue times | adaptive scheduling (v9) |
| Habit stacking | "stack onto…" picker | routine builder with chains (v9) |
| Implementation intentions | "When X, I will Y" field | conditional quests (v9) |
| Anchor sleep / wind-down | evening routine template | sleep-aware quests (v4) |
| Two-Minute Rule | `minMinutes` floor | adaptive difficulty (v9) |
| Self-monitoring | daily log | Habit DNA (v20) |

---

## Sources

- Wood, W. (2024). *Habits, Goals, and Effective Behavior Change.* Current
  Directions in Psychological Science.
- Wood, W. & Neal, D. (2007). A new look at habits and the habit–goal interface.
- Lally, P. et al. (2010). How are habits formed. *European Journal of Social
  Psychology*.
- Fournier, M. et al. (2016/2017). Morning vs evening habit formation; cortisol
  mediation (PubMed 28650196).
- Duhigg, C. *The Power of Habit* (keystone habits, habit loop).
- Clear, J. *Atomic Habits* (four laws, identity, Two-Minute Rule, stacking).
- Gollwitzer, P. (1999). Implementation intentions. *American Psychologist*.
- Harkin, B. et al. (2016). Self-monitoring meta-analysis (138 studies).
- Johns Hopkins (2026) — faster habit transitions; gating brain region.
- Huberman, A. — morning light/caffeine protocol; anchor sleep.
- Chronotype/synchrony literature (MEQ; synchrony effect).
