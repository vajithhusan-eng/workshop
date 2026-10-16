# Gamification Ethics — Deep Reference

> Companion to `PSYCHOLOGY.md` Part 3. That doc listed the dark techniques and
> our red lines; this doc drills the **line itself** — what separates persuasion
> from manipulation in a product, and how Arise stays on the right side of it
> while still using powerful mechanics.
>
> This is a discipline app. Our users come to us vulnerable (that's what "want
> to quit a bad habit" means). Manipulating vulnerable users isn't just
> unethical — it destroys the trust the product runs on.

---

## 1. The definition that draws the line

**Fogg's test** (the founder of persuasive tech): persuasive technology is
*"a voluntary change of behaviour or attitude, without using coercion or
deception."* Two disqualifiers — **coercion** and **deception**. If either is
present, it is not persuasion.

**Manipulation** = *"imposing a hidden or covert influence on another person's
decision-making."* The key word is **hidden**. Persuasion is *legible*:
the user can see the influence and could reject it. Manipulation hides the
influence so the user can't.

**The operational test we apply to every feature:**
> *If the user could see exactly what this feature is doing and why, would they
> still endorse it — and would they endorse it for the next user too?*
> If yes → persuasion. If no → cut it.

## 2. Dark patterns (Brignull, 2010) — the taxonomy

Deliberate UI design that exploits cognitive biases to push users toward
decisions *against their own intentions*. The canonical set:

- **Roach motel** — easy in, hard out.
- **Confirmshaming** — "No thanks, I like failing."
- **Fake scarcity / urgency / FOMO** — countdowns that reset, "3 left!"
- **Fake social proof** — invented activity, fake testimonials.
- **Forced action** — do X to access Y.
- **Hidden costs** — revealed at the end.
- **Nagging** — repeated interruptions to convert.
- **Obstruction** — deliberately adding friction to a rival choice.
- **Preselection / sneaking** — defaulted opt-ins, added extras.
- **Trick wording** — double negatives, ambiguous buttons.
- **Comparison prevention** — make options hard to compare.
- **Privacy zuckering** — trick into over-sharing.

## 3. Dark patterns *in games* (and why it matters here)

Research on game-adapted dark patterns (Flankkumäki & Söderholm; arXiv 2401.06247;
SCITEPRESS 2025 "Dark Patterns in Games") shows the game industry is where the
worst practices live:

- **Daily-login streaks** that punish absence *by design* → the exact mechanic
  that makes habit streaks toxic.
- **Energy timers** — gate play behind waiting or paying.
- **Loot boxes / gacha** — variable-ratio reward schedules engineered as
  gambling, sometimes targeting minors.
- **Retention loops** ("exit dark patterns") that make quitting hard.
- Players are increasingly **aware** they're being manipulated, and awareness
  breeds resentment, not loyalty.

## 4. The gamification-darkness literature

**Nyström et al., "Exploring the Darkness of Gamification: You Want It Darker?"**
— a systematic review of ~191 papers on *negative* gamification outcomes. Core
findings:

- Gamification is a **neutral tool** — it can serve the user or exploit them.
  The intent, not the mechanic, decides.
- Dark gamification = design that benefits the **developer** at the expense of
  the user's best interest, via coercion, deception, or exploitation.
- Calls for **"gamification literacy"** — users should be able to recognise
  manipulative mechanics.
- Designers are frequently **using dark patterns unknowingly** — it's often
  incompetence or a copied engagement metric, not malice. Which means: *name the
  mechanic and its intent, on purpose, or you'll drift dark by default.*

## 5. The intrinsic-motivation risk (the subtlest one)

**Overjustification effect / motivation crowding** (Deci, Koestner & Ryan): heavy
*expected* extrinsic rewards can **undermine intrinsic motivation** for an
already-enjoyed activity. If you pay someone to do what they love, they may stop
loving it.

Gamification's honest brief (SDT): use extrinsic scaffolding to **bootstrap** the
first 60–90 days, then **fade it** as intrinsic motivation and habit automaticity
take over. A gamified system that never lets go becomes a treadmill — the reward
becomes the point, and the moment it stops, the behaviour dies.

**→ Arise**: the System must be able to **recede**. Maintenance-stage users
should be able to turn down the noise (fewer windows, log-free streaks, "quiet
mode") without losing their record. The goal is that the user doesn't *need* the
System forever.

## 6. Risks specific to *this* product

| Risk | Why it's acute here | Guardrail |
|---|---|---|
| **Streak shame** | Users come to fix a failure; a broken streak re-wounds them (AVE) | Never-miss-twice, bounded penalty, recovery path, situational copy |
| **Motivation crowding** | Habits must outlive the app | System can recede; fade extrinsic scaffolding |
| **Gacha gambling** | Genre pulls hard toward loot boxes | Capped, honest, no real money, no purchase |
| **Engagement-driven nudges** | "Re-engage" metrics vs the user's real goal | Notifications serve the *habit*, never the *DAU* |
| **Hidden progress / fake score** | The whole genre promise is *legible fairness* | Honest numbers only; XP = effort |
| **Vulnerable-user profiling** | Quit-apps know intimate failure data | On-device only, never sold, never used to target |
| **Dark retention** | "Roach motel" churn tricks | One-tap export and delete, always |

## 7. Our rules (operational)

1. **Legibility.** The user can always see what the System is doing and why.
2. **Voluntary.** Nothing is forced; every mechanic is opt-out-able.
3. **No deception.** Real numbers, real scarcity or none, no fake social proof.
4. **Honest loss.** Loss aversion may be used, but the user *chose* the stake.
5. **No real-money stakes.** Commitment is in in-app currency only.
6. **Capped randomness.** Anticipation without gambling; odds implicit, never sold.
7. **Serve the habit, not the metric.** Notifications exist to help the user
   act on *their* goal, never to bump engagement.
8. **Local-only data.** No account, no upload, no profiling, no ads.
9. **Leave cleanly.** Full export + delete, one tap, always.
10. **Let it go.** The System can recede as the habit automates.
11. **Attribute to situation, never to self.** No shame copy, ever (AVE).
12. **Name the mechanic.** Every dark-adjacent technique we use is documented
    in `PSYCHOLOGY.md` Part 3 *with its intent* — literacy as a design habit.

---

## Sources

- B.J. Fogg — persuasive technology definition (voluntary, no coercion/deception).
- Brignull, H. (2010) — dark patterns taxonomy (deceptive.design).
- Nyström, T. et al. — *Exploring the Darkness of Gamification: You Want It
  Darker?*
- *Dark Patterns in Games: An Empirical Study of Their Harmfulness* (SCITEPRESS,
  2025); *Player Beware: Game-Adapted Dark Patterns* (arXiv 2401.06247).
- Deci, Koestner & Ryan — overjustification / motivation crowding.
- The Decision Lab — ethical gamification.
