# Arise — documentation index

Research and design documents for **Arise**, an offline, Android-first Flutter
app that turns habits, routines, and self-discipline into a Solo Leveling–style
**System**.

| Document | What it covers | Authority |
|---|---|---|
| [`../README.md`](../README.md) | Entry point: what this is, how to run and test it | — |
| [`../AGENTS.md`](../AGENTS.md) | Agent instructions: identity, scope, locked decisions, traps | — |
| [`../STATE.md`](../STATE.md) | Verified build status against HEAD | — |
| [`../CHANGELOG.md`](../CHANGELOG.md) | Append-only history | — |
| [`ROADMAP.md`](ROADMAP.md) | **Plan of record.** The v1-first decision, v1 scope + definition of done, milestones, the v1→v20 arc | **The plan** |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Modules, layers, data models, domain engines, storage/routing/notification decisions, testing | **How it is built** |
| [`FEATURE-SPEC.md`](FEATURE-SPEC.md) | Behavioural spec for each v1 feature + the v2–v20 registry and reserved hooks | **What each feature does** |
| [`UI-UX-HUD.md`](UI-UX-HUD.md) | Interface/HUD spec: palette, typography, glass panel, motion, components, screens, WCAG 2.2 AA, performance | **How it looks** |
| [`3D-IMMERSIVE-UI.md`](3D-IMMERSIVE-UI.md) | 3D/spatial UI: Flutter rendering options, three capability tiers, depth system, hero 3D moments, motion, performance budget, vestibular safety | **How it feels** |
| [`HABITS-ROUTINES-DEEP.md`](HABITS-ROUTINES-DEEP.md) | What a habit is, formation timelines, context/friction levers, keystone habits, chronotype, stacking, sleep anchors — each mapped to a feature | Reference |
| [`SYSTEM-RESEARCH.md`](SYSTEM-RESEARCH.md) | The Solo Leveling System's mechanics, quest taxonomy, stats, penalty zone, shop, titles — plus the IP boundary | Reference |
| [`SYSTEM-GENRE-DEEP.md`](SYSTEM-GENRE-DEEP.md) | The wider "System" genre and its game-design lineage (XP curves, stat allocation, gacha, quest taxonomy) | Reference |
| [`APP-LANDSCAPE.md`](APP-LANDSCAPE.md) | Competing apps: habit builders, quit/sobriety apps, blockers, gamified trackers (incl. ZFA) | Reference |
| [`PSYCHOLOGY.md`](PSYCHOLOGY.md) | Behavior-science field map, technique catalog, dark psychology, **12 red lines** | Reference |
| [`BEHAVIOR-SCIENCE-DEEP.md`](BEHAVIOR-SCIENCE-DEEP.md) | The science spec: each mechanic with its citation (four laws, stages of change, relapse prevention/AVE, HRT, self-monitoring, commitment devices, endowed progress, fresh start) | Reference |
| [`GAMIFICATION-ETHICS.md`](GAMIFICATION-ETHICS.md) | The persuasion-vs-manipulation line, dark patterns in games, and Arise's operational ethics rules | Reference |
| [`PORN-MASTURBATION-CONTROL.md`](PORN-MASTURBATION-CONTROL.md) | **Highest-stakes use case.** The contested science of porn compulsion, PIED, NoFap reboot/flatline, the recovery-book canon, clinical toolkit, and the domain's ethical guardrails | Reference |

Add a row for every new document, including any top-level `*.md` outside the
required set. A document that is not indexed here does not exist as far as the
next reader is concerned.

**When two documents disagree**, the one marked authoritative above wins, and
the disagreement is a bug to record — the domain spec (`FEATURE-SPEC.md`) and the
build spec (`ARCHITECTURE.md`) must agree, or one of them is wrong.
