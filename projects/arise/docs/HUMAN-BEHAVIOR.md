# Human Behaviour — The Model Arise Designs Against

> "Learn about all human behaviour." This doc is the working model: a small
> number of layers that explain most of what people do, each with what it means
> for the app and what the app refuses to do with it.
>
> It is a *design* model, not a textbook. Where the science is contested, it says
> so — an honest model with a seam in it beats a confident one that is wrong.

---

## 1. Why a model at all

A habit app without a model of behaviour ends up optimising whatever is
measurable: sessions, streaks, taps. That is how habit apps become slot machines.

The model's job is to answer one question repeatedly: **at which layer is this
person actually stuck?** A user who "lacks discipline" is usually stuck at
layer 1 (sleeping badly), layer 7 (their environment is rigged), or layer 3 (the
cue fires forty times a day). Telling them to try harder is a layer-4 answer to
a layer-1 problem.

---

## 2. The seven layers

```
  7  ENVIRONMENT & AFFORDANCES   what the world makes easy
  6  SOCIAL                      who is watching, who is doing it too
  5  IDENTITY & NARRATIVE        the story you tell about who you are
  4  MOTIVATION                  autonomy · competence · relatedness
  3  HABIT                       cue → response, without deliberation
  2  REWARD LEARNING             dopamine, prediction error, wanting
  1  BIOLOGY                     sleep · light · food · movement · stress
```

Read bottom-up: each layer constrains the ones above it. You cannot motivate
your way out of a sleep deficit (layer 1 caps layer 4). You cannot out-discipline
a cue that fires hourly (layer 3 caps layer 4). Most advice fails because it
tries to fix a low layer with a high-layer intervention.

### 2.1 Layer 1 — Biology
Sleep, circadian phase, light, food, movement, pain, illness, and stress load.
The body sets the *capacity* for everything above.

- **Sleep loss degrades goal-directed control and increases habitual control**
  (Chen et al. 2017, *J Neurosci*): a tired person is not choosing, they are
  running scripts.
- Circadian phase shapes mood, attention, and impulse control across the day;
  chronotype moderates when effort is cheapest (see `HABITS-ROUTINES-DEEP.md` §6.3).
- **Stress → habit is plausible but unproven** — the famous Schwabe & Wolf
  findings failed exact preregistered replication (Smeets et al. 2023) and a 2025
  *PLOS ONE* study found no effect. Treat as heuristic, never as fact.

**For Arise:** sleep and light are *foundation quests*, not side content. On a
low-sleep day the System lowers demand instead of pushing. Never moralise
tiredness.

### 2.2 Layer 2 — Reward learning
Dopamine encodes **prediction error** and **incentive salience** — *wanting*, not
*liking* (Berridge). This distinction matters more than any other in this doc:

- **Wanting ≠ liking.** You can crave something you do not enjoy. That is why
  "just notice you don't actually enjoy it" fails as advice.
- **Anticipation is where the drive is**, so the *cue* (not the reward) is the
  leverage point.
- **Variable-ratio reinforcement** (unpredictable reward) is the most
  persistence-inducing schedule known. It is the slot-machine mechanism, and it
  is forbidden here (red line 2).
- **Reward prediction error** means rewards must be *earned and legible*; an
  unearned bonus teaches nothing and devalues the earned ones.

**For Arise:** rewards are deterministic and proportional. No loot boxes, no
random drops, no "lucky" anything. Predictability is not a limitation — it is
the mechanism that makes the progression trustworthy.

### 2.3 Layer 3 — Habit
Cue → response, retrieved by context. See `HABITS-ROUTINES-DEEP.md`.

- Habit memory is non-conscious; you can hold a habit and not know it.
- **Context is the retrieval key** — so context change (moving, a new job,
  travel) is both the biggest risk to a good habit and the biggest opportunity
  to drop a bad one.
- Habits are not "unthinking" in the sense of being weak; they are *efficient*,
  which is why they outcompete intentions under load.

**For Arise:** the cue is a required field on every quest. Arise is a context
engine before it is a motivation engine.

### 2.4 Layer 4 — Motivation
**Self-determination theory** (Deci & Ryan): behaviour is sustained by
**autonomy, competence, relatedness**. Undermine any of the three and you get
compliance that evaporates.

- **Autonomy**: imposed goals are short-lived. A user-authored quest beats a
  System-issued one, even when the content is identical.
- **Competence**: the need this category serves *worst* — see the gamification
  meta-analysis (Li/Hew/Du 2024) where autonomy and relatedness rose but
  competence barely moved.
- **Relatedness**: for a *private* app this is the hard one. We cannot ship a
  social feed (red lines 5, 7). So relatedness must come from somewhere honest:
  a named companion, the sense of being on a path others have walked, or
  optional, user-initiated export. **Be honest that this is the weakest layer
  in Arise, and do not fake it.**
- **The overjustification effect** (Deci, Koestner & Ryan 1999): rewarding
  something already intrinsically motivated can *reduce* it. Never award XP for
  what the user already loves doing.

**For Arise:** optional quests, editable everywhere, and XP that never pays for
something the user already enjoys.

### 2.5 Layer 5 — Identity & narrative
People act to stay consistent with the story they tell about themselves
(narrative identity; cognitive dissonance).

- **"I'm the kind of person who…"** is a stronger predictor of persistence than
  any goal statement.
- Identity change is slow, and it is built from **evidence**, not affirmation.
  You do not become a runner by declaring it; you become one by accumulating
  runs you cannot explain away.
- **The AVE is an identity event**: "I'm a failure" is a *global, stable,
  internal* attribution, and it rewrites the story. Preventing that rewrite is
  most of relapse prevention (`HABIT-CONTROL-AND-DETOX.md` §6).

**For Arise:** the System is the *witness*, not the judge. It accumulates
evidence ("you have done this 40 times") and lets the user draw the identity
conclusion themselves. Never assert one for them.

### 2.6 Layer 6 — Social
Descriptive norms (what people do) and injunctive norms (what people approve)
shape behaviour, often more than attitudes do. Modelling and accountability work.

- **Loneliness and isolation increase compulsive use** — the behaviour is often
  a substitute for connection, not a preference.
- **Accountability works only when voluntary and non-shaming.** Coerced
  accountability becomes surveillance and triggers reactance.

**For Arise:** no leaderboards, no guilds, no public profiles (red lines 5, 7).
Where relatedness is offered it is **opt-in and private**: an accountability
partner the user chooses, with what they can see controlled by the user.

### 2.7 Layer 7 — Environment & affordances
What the world makes easy wins. This is the highest-leverage layer and the one
habit apps touch least, because it is not in the app.

- **Friction and defaults** decide behaviour more reliably than intentions.
- **Supernormal stimuli**: modern products are engineered to capture. A failure
  to resist is often a normal brain in a hostile environment — true, and
  relieving.
- **The hot–cold empathy gap** (Loewenstein): in a cold state you cannot
  accurately predict your hot-state preferences, which is exactly why
  **precommitment** works and resolve does not.

**For Arise:** precommitment is a first-class feature (commitment devices,
quiet hours, friction). The app must be able to act on the *environment*, or it
is just a diary.

---

## 3. The integration: COM-B

**Michie et al.'s Behaviour Change Wheel** is the cleanest way to check the model
is not just targeting motivation:

```
B = f( Capability · Opportunity · Motivation )
```

| Component | Question | If absent, the fix is |
|---|---|---|
| **Capability** | do they know how, and are they able? | instruction, skill, planning |
| **Opportunity** | does the world allow it? | environment, cue change, time |
| **Motivation** | do they want to, reflectively and automatically? | autonomy, meaning, reward |

**The audit:** every v1 feature should name which of C/O/M it acts on. Today the
spec is heavily M-weighted — which is the classic failure of this whole category.

### 3.1 The intention–behaviour gap
Intentions account for only a modest share of behaviour variance (Sheeran's
meta-analysis puts it around **28%**). So a product that only builds intent —
"set a goal, feel inspired" — is addressing less than a third of the problem.
The other two-thirds live in capability and opportunity, i.e. **layers 3 and 7**.

This is the single most important number for product strategy: **Arise must be
an opportunity-and-capability product with a motivation skin**, not the reverse.

---

## 4. Dual process — and why "willpower" is the wrong frame

Behaviour emerges from two interacting systems: a fast, associative, cue-driven
one and a slow, deliberate, effortful one (Lyngs et al. 2019 apply this to
digital self-control). Practical consequences:

- Much behaviour is initiated **before** deliberation, so reflective appeals
  arrive late.
- The expected value of control depends on **expected payoff, delay, and effort** —
  which is why *delay* and *friction* are the two cheapest levers.
- **"Willpower as fuel" is unsupported** (ego depletion has failed replication)
  and belief-dependent (Job, Dweck & Walton 2010). Never build a meter for it.

---

## 5. The needs underneath

What people are usually trying to get when they do something they regret:

| Need | Healthy route | The shortcut that hijacks it |
|---|---|---|
| **Competence** | mastery, visible progress | easy wins, fake levels |
| **Autonomy** | self-authored goals | "do this or lose your streak" |
| **Relatedness** | real connection | parasocial feeds, porn |
| **Status** | earned regard | leaderboards, badge inflation |
| **Certainty** | routine, predictability | doomscrolling, checking |
| **Arousal/escape** | play, novelty, exercise | bingeing, gambling mechanics |
| **Soothing** | rest, warmth, company | junk food, alcohol, scrolling |

**The pattern:** every compulsive behaviour is a *working* solution to a real
need, executed badly. Which means the correct intervention is usually not
removal — it is **substitution with something that meets the same need**.

### 5.1 Emotion regulation is the hidden variable
Most "bad habits" are not pleasure-seeking. They are **state-changing**: escape
from anxiety, numbing of boredom, relief from loneliness, blotting out shame.

- This is why willpower fails — you are not fighting a preference, you are
  fighting a coping strategy that is currently doing a job.
- This is why abstinence alone often fails — you removed the coping strategy and
  left the distress.
- **The therapeutic move is to name the state and offer a competing response for
  that state**, which is precisely what habit reversal training does clinically.

**For Arise:** when a user logs an urge, the app asks *"what were you feeling?"*
before *"what did you do?"*. That single reordering is the difference between a
tracker and a therapeutic tool. And it gives the substitution engine something
real to match against.

---

## 6. What Arise refuses to exploit

Every layer has a profitable exploit. This table is the contract.

| Layer | The exploit | Arise's refusal |
|---|---|---|
| Biology | sell sleep-deprived users stimulation; push harder when they're exhausted | lower demand on low-sleep days |
| Reward | variable-ratio drops, loot boxes, "lucky" bonuses | deterministic, proportional rewards |
| Habit | manufacture cues (notifications engineered to fire) | cues the user set; no engagement notifications |
| Motivation | extrinsic rewards for things already loved; guilt as fuel | never pay for intrinsic joy; no shame copy |
| Identity | flatter the user with unearned ranks | rank reflects logged effort only |
| Social | public comparison, fake social proof, loss-framed sharing | no public ranks, no leaderboards, no fake proof |
| Environment | dark patterns, confirmshaming, roach-motel uninstall | one-tap export and delete; no dark patterns |

**The test for any new feature:** which layer does it act on, and does it meet
the need honestly or hijack it?

---

## 7. The model in practice — a diagnostic

When something is not working, walk the layers top-down and stop at the first
honest answer:

1. **Environment** — is the cue even avoidable? (fix: friction, quiet hours)
2. **Social** — is anyone making it harder or easier? (fix: opt-in partner)
3. **Identity** — does the user believe they are the kind of person who can?
   (fix: evidence, not affirmation)
4. **Motivation** — is the quest theirs? is competence visible? (fix: autonomy,
   better feedback)
5. **Habit** — is there a cue and a context? (fix: cue design, stacking)
6. **Reward** — is the payoff legible and earned? (fix: proportional XP)
7. **Biology** — is the user sleeping, eating, moving? (fix: foundation quests)

Almost every "the user is lazy" diagnosis resolves to layer 7 or layer 1.

---

## 8. Design rules that fall out

1. **Diagnose before you motivate.** Ask which layer; never assume motivation.
2. **Lower demand when capacity is low.** Tiredness is a biology signal, not a
   character verdict.
3. **Rewards must be earned and predictable.** Legibility is the product.
4. **Ask about the state before the behaviour.** Emotion regulation is the
   hidden variable.
5. **Substitute, don't just remove.** Every removed coping strategy needs a
   replacement or it returns.
6. **Act on opportunity, not just intention.** Friction and cue design beat
   encouragement.
7. **Never build a willpower meter.** The model is unsupported and the metaphor
   is harmful.
8. **Be honest about the weak layer.** Relatedness is Arise's weakest; do not
   fake it with a feed.
9. **Identity is inferred, never assigned.** Show evidence; let the user conclude.
10. **Where the science is contested, say so in the copy and in the docs.**

---

## Sources

- Berridge, K. & Robinson, T. — incentive salience; wanting vs liking.
- Deci, E. & Ryan, R. — self-determination theory; basic psychological needs.
- Deci, E., Koestner, R., & Ryan, R. (1999). A meta-analytic review of
  experiments examining the effects of extrinsic rewards on intrinsic
  motivation. *Psychological Bulletin.*
- Michie, S. et al. — COM-B and the Behaviour Change Wheel.
- Fogg, B.J. — B=MAP (motivation × ability × prompt).
- Sheeran, P. (2002). Intention–behaviour relations: a conceptual and empirical
  review. *European Review of Social Psychology.*
- Loewenstein, G. — hot–cold empathy gap; precommitment.
- Chen, J. et al. (2017). Sleep deprivation promotes habitual control.
  *Journal of Neuroscience* 37(49):11979.
- Schwabe, L. & Wolf, O. (2009); Smeets, T. et al. (2023) failed replication;
  *PLOS ONE* (2025) no effect — see `HABIT-CONTROL-AND-DETOX.md` §7.2.
- Job, V., Dweck, C., & Walton, G. (2010). *Psychological Science* 21(11):1686.
- Lyngs, U. et al. (2019). Self-control in cyberspace. *CHI 2019.*
- Li, C., Hew, K.F., & Du, J. (2024). Gamification meta-analysis.
- McAdams, D. — narrative identity.
- Neff, K. — self-compassion.
- Marlatt, G. & Gordon, J. (1985) — abstinence violation effect.
