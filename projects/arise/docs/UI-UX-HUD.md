# Arise — Interface, HUD & UX Spec

> The System is the product's interface. This doc defines its art direction,
> motion, components, screens, and the accessibility and performance rules that
> keep a "cool dark HUD" from becoming an unreadable, janky one.
>
> Read with `docs/ARCHITECTURE.md` (how it is built) and `docs/FEATURE-SPEC.md`
> (what each feature does).

---

## 1. Design thesis

**"Diegetic in aesthetic, non-diegetic in affordance."**

In games, a *diegetic* UI exists inside the fiction (Dead Space's spine-mounted
health bar); a *non-diegetic* HUD is chrome pasted over the world. Studies
(Fagerholt & Lorentzon 2009; Peacocke et al. 2018) find diegetic = more
immersion, non-diegetic = more clarity and awareness. A discipline tool needs
**both**: the System window must *feel* like it exists in the user's world
(immersion = motivation), but every control must be *instantly legible*
(usability = the user actually completes quests).

Three rules that follow:

1. **Effort→reward must be instant and visible.** Legible fairness is the
   product (`AGENTS.md`). The XP bar reacts the moment a quest is completed.
2. **The System window is the emotional peak.** It is where the budget goes —
   more polish here than anywhere else, because it is the moment the user *feels*
   acknowledged.
3. **Never a dead end.** Every screen has a way forward; every failure has a
   comeback path. No shame states, no grey-out-punishment screens.

## 2. Art direction — visual language

### 2.1 Palette (dark-only, by intent)

Arise is **dark-only** (a legitimate choice for immersive media per Apple HIG).
One palette; no light mode. Tokens live in `lib/core/theme/` as a
`ThemeExtension`.

| Token | Value | Use |
|---|---|---|
| `void` | `#05070D` | App background (near-black navy) |
| `abyss` | `#0A0E1A` | Deep gradient stop |
| `surfaceGlass` | `#FFFFFF` @ 4–8% | Glass panel fill over gradient |
| `systemBlue` | `#35B6FF` | Primary accent — System text, XP, borders |
| `systemBlueGlow` | `#00C2FF` @ 40% | Glow/shadow |
| `arcane` | `#7C5CFF` | Secondary/violet — high-tier ranks, rare |
| `success` | `#4ADE80` | Quest complete confirmation |
| `warning` | `#FFB020` | Bounded penalty, "the System notes…" |
| `danger` | `#FF4D6D` | HP/urgent (future), destructive confirm |
| `textPrimary` | `#E8F1FF` | Body text on glass |
| `textSecondary` | `#93A4C0` | Labels, meta |

**Rank colors** (E→S) — always paired with a letter/word, never color alone:

| Rank | Color |
|---|---|
| E | `#8A94A6` grey |
| D | `#4ADE80` green |
| C | `#35B6FF` blue |
| B | `#7C5CFF` violet |
| A | `#FFC65C` gold |
| S | `#FF4D6D` crimson |

> **Contrast rule:** every text/background pair must clear WCAG AA — **4.5:1**
> body, **3:1** large text and UI/graphic boundaries. System blue on `void`
> passes for body; verify each token pair in a one-time contrast test, not by eye.

### 2.2 Typography

- **System voice** (headings, labels, numbers): a geometric techno face —
  candidates **Orbitron**, **Chakra Petch**, **Rajdhani**, **Saira**. Use
  *sparingly*; all-caps with letter-spacing for the System's "spoken" lines.
- **Product voice** (quest text, notes, settings, help): a clean humanist sans —
  **Inter** or the platform default. This is where readability wins.
- **Numerals**: tabular figures everywhere (stats must align).
- **Offline rule:** fonts are **bundled as assets and vendored** — `google_fonts`
  may *not* fetch at runtime (no network). Ship the `.ttf` files.

### 2.3 The glass panel (signature component)

```
BackdropFilter(blur σ 10–20)
  → Container(fill surfaceGlass, 1px border, radius 12–16)
  → light-catcher border: top/left edge brighter than bottom/right
  → corner brackets (CustomPainter, 4 corners, systemBlue)
  → inner glow (BoxShadow, systemBlueGlow @ low opacity)
  → optional scanline overlay / entrance sweep
```

Blur is **GPU-expensive** and must not be nested or animated in radius. See §7.

### 2.4 Iconography

Outline, thin-stroke, sci-fi geometry; corner-bracket framing for emphasis.
Ship as SVG (`flutter_svg`, bundled). Decorative brackets are **excluded from
semantics** (screen readers must not announce them).

## 3. Motion design

| Moment | Motion | Duration / curve |
|---|---|---|
| System window appears | scale 0.92→1.0 + fade + scanline sweep | 220–300 ms, easeOutCubic |
| Quest complete | checkbox fill + XP bar surge + light haptic | 200 ms + 300 ms bar |
| XP gained | floating `+XP` numeral rises & fades | 500 ms |
| Level up | full-screen overlay: bar fills → burst → title reveal | ~1.2 s, skippable |
| Rank up | banner slide + rank sigil morph + stronger sting | ~1.4 s, skippable |
| Milestone reveal | card flip / unfurl from locked silhouette | 400 ms |
| Screen transitions | fade + subtle shared-element on the System window | 250 ms |

**Principles**

- Animation supports intent; it is never decoration for its own sake.
- **Compositor-friendly only**: animate `opacity` and `transform` — **never blur
  radius**, never layout-affecting properties in a loop.
- **Haptics**: light impact on complete; medium + success pattern on level/rank up.
- **Sound**: short digital stings via `audioplayers`, **bundled offline**, muted
  by default with a visible toggle in Settings. Every audio cue has a visual
  parity (deaf/HoH).

## 4. Component inventory (Flutter widgets)

All in `lib/core/widgets/` (shared) or the owning feature's `presentation/`.

| Component | Purpose |
|---|---|
| `SystemWindow` | The glass panel primitive (brackets, glow, blur) |
| `SystemButton` | Primary/secondary/danger buttons in System style |
| `StatusWindow` | Name, level, rank, XP bar, streak — the hero card |
| `XpBar` | Animated progress with tabular numerals |
| `RankBadge` | Rank letter + color + sigil (colorblind-safe) |
| `StreakCounter` | Current/longest, with a "never-miss-twice" shield indicator |
| `QuestCard` | Title, cue time, XP value, complete control |
| `QuestSection` | Daily / Weekly / Custom grouping |
| `QuestList` | Scrollable list with empty state |
| `SystemToast` / `SystemDialog` | Notification-styled transient & modal |
| `LevelUpOverlay` | Full-screen level-up celebration |
| `RankUpOverlay` | Full-screen rank-up celebration |
| `MilestoneReveal` | Unlocks a hidden achievement (ZFA's curiosity gap) |
| `EmptyState` | First-run / nothing-today, always with a next action |
| `CueTimePicker` | Set the daily trigger time |
| `StageSelectCard` | Onboarding: readiness/stage (TTM-aware) |
| `UrgeSurfPanel` *(domain)* | 10-min urge-surf timer + resistance/lapse log |
| `RecoveryPanel` *(domain)* | AVE-safe lapse→comeback flow |
| `DungeonTimer` *(v4)* | Focus-session timer |

## 5. Screens & information architecture (v1)

**Navigation:** bottom navigation, 4 tabs max, large tap targets, one-hand
reachable. A FAB (System-styled) creates a quest.

| Screen | Contents |
|---|---|
| **Onboarding** | Acquisition screen ("You have acquired the qualifications…") → name → stage-select → first quest → cue time → notification permission → done |
| **Status** (home) | `StatusWindow` hero + today's quests + streak + a single System line |
| **Quests** | All quests, grouped; create/edit/archive |
| **Log** | Daily log / chronicle entry list; add today's note |
| **Settings** | Notifications & cue times, sound toggle, high-contrast toggle, reduced-motion override, data export/import, About + **Ethics** page, reset |
| **Modal flows** | `LevelUpOverlay`, `RankUpOverlay`, `MilestoneReveal`, bounded-penalty notice, `RecoveryPanel` (lapse), `UrgeSurfPanel` (urge) |

**Key flows**

1. **First-run** — the "awakening"; stage-aware (don't assume Action stage —
   most arrivals are contemplating). Ends with one 2-minute-winnable quest.
2. **Daily loop** — notification → open → quest list → complete → XP → done.
   Target: ≤3 taps from notification to first completion.
3. **Completion** — tap → instant XP animation → status updates; no confirmation
   dialog for a normal quest (confirmation only for destructive acts).
4. **Missed day** — never-miss-twice: *"The System notes your absence."* Offer a
   recovery quest. Never red, never a wiped streak, never shame.
5. **Level / rank up** — overlay, skippable.
6. **Lapse (domain)** — `RecoveryPanel`: attribute to *situation*, offer a
   comeback quest and a Fresh Start; never reset the total record.

## 6. Accessibility (WCAG 2.2 AA minimum)

| Requirement | Implementation |
|---|---|
| **Contrast** | 4.5:1 body / 3:1 large + UI. Token pairs verified by an automated contrast test. |
| **Not color alone** | Rank = color **and** letter **and** sigil. Warnings = color **and** icon **and** text. |
| **Reduced motion** | Respect OS setting (`MediaQuery.disableAnimations` / `accessibleNavigation`); honor a "require reduced motion" override in Settings. Reduced = fade/opacity only, no scale/sweep/particles. |
| **Semantics** | Glass panels labelled; `XpBar` exposes a progress semantics value; quest complete is a checkbox role; decorative brackets excluded. System copy is real text, never ASCII-art. |
| **Tap targets** | ≥ 48×48 dp. |
| **Text scaling** | Up to 200% without clipping — glass panels grow; no fixed-height text. |
| **High contrast** | A Settings toggle that **bypasses blur** and raises border/text contrast (also the low-end-device fallback). |
| **Flashes** | Nothing flashes > 3×/second (WCAG 2.3.1). |
| **Audio** | Never the sole carrier of meaning; visible parity for all stings. |

## 7. Performance

- `BackdropFilter`/`ImageFilter.blur` is GPU-expensive. **One focal glass element
  per screen**; background panels use a cheaper treatment (flat translucent fill,
  no blur).
- **Never nest** glass elements; **never animate** blur radius.
- Prefer **Impeller**; avoid gratuitous custom shaders.
- "Premium apps use animations selectively — not everywhere."
- Ship a low-end fallback: high-contrast/flat mode disables blur entirely.

## 8. Flutter implementation notes

| Concern | Choice |
|---|---|
| Declarative motion | `flutter_animate` |
| Fonts | **Bundled** `.ttf` (offline) — Orbitron/Chakra Petch + Inter |
| Icons/graphics | `flutter_svg` (bundled) |
| Glass | native `BackdropFilter` + `ClipRRect` (never filter unclipped) |
| Brackets/scanlines/radar | `CustomPainter` |
| Hero animations *(later)* | `rive`/`lottie` only if **bundled** — no runtime fetch |
| Charts *(later)* | `fl_chart` |
| Haptics | `flutter/services` `HapticFeedback` |
| Audio | `audioplayers`, bundled assets, muted by default |
| Design tokens | one `ThemeExtension` (`SystemColors`, `SystemTypography`, `SystemMotion`, `SystemGlass`) |

## 9. Copy system

**All System copy lives in one catalog** (`lib/core/copy/system_messages.dart`)
as data, so the `GAMIFICATION-ETHICS.md` rules are enforceable and reviewable —
and so tone is consistent and localizable later. No hardcoded System strings in
widgets. The catalog is where the "no shame" rule is actually enforced.

## 10. UX principles (the checklist every screen must pass)

1. **Legible fairness** — effort is instantly visible as XP.
2. **Comeback path** — no dead ends, no shame states, ever.
3. **≤3 taps** from notification to first quest completion.
4. **One-hand reachable** — primary actions in the thumb zone.
5. **Offline calm** — no spinners, no "syncing", no network errors (there is no
   network).
6. **Progressive disclosure** — v1 hides empty stats/jobs entirely; the System
   reveals complexity over time (the genre's own pacing).
7. **The window is the peak** — spend the polish budget on the System window.
8. **Honest** — never show a number that isn't real.

---

## Sources

- Fagerholt & Lorentzon, *Beyond the HUD* (Chalmers, 2009); Peacocke et al.,
  *An empirical comparison of FPS information displays* (Entertainment Computing,
  2018); Visceral Games, *Dead Space* diegetic UI (GDC 2013); Unity, *Immersion
  through UI* (2022).
- WCAG 2.2 SC 1.4.3/1.4.6/1.4.11, 2.2.2, 2.3.1/2.3.3; Casto, *Reduced motion*;
  MDN color-contrast; Apple HIG *Dark Mode*.
- Flutter: `BackdropFilter` glassmorphism guidance (Flutter Gems, 2026);
  *7 Flutter UI Packages* (2026); `liquid_glass_widgets` (Impeller/shaders).
- Habit-app UX patterns: *7 UI patterns from a habit-tracking app* (UX Collective);
  habit-tracker case studies (2020–2026).
