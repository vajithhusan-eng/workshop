# Arise

*An offline, Android-first Flutter app that turns habits, routines, and self-discipline into a Solo Leveling–style **System**.*

**Status:** Plan only · research + design complete (10 docs); no code yet — M0 scaffold not started.

## What this is

Arise is **not a habit tracker with a manhwa theme**. It is a genuine
alternate-progression layer over the user's real life: daily quests, XP, levels,
E→S ranks, and System-styled notifications — with the psychology of behaviour
change underneath and the System aesthetic on top.

**Offline-only by design.** No account, no server, no network, no ads, no
analytics phone-home. The discipline data never leaves the device.
*"The System belongs to you."*

The v1 release ("The Awakening") is deliberately small — quests, XP, levels,
ranks, streaks, System notifications, local storage. Later versions add stats,
job classes, HP/penalty, dungeons, shop, titles, and prestige. See
[`docs/ROADMAP.md`](docs/ROADMAP.md) for the full v1→v20 arc.

## Run it

No runnable app yet — the Flutter project has not been scaffolded (milestone M0).
Once it exists:

```bash
flutter pub get
flutter run
```

## Test it

No tests yet — there is no code to test. Once M1 lands:

```bash
flutter analyze
flutter test
```

## Layout

```
projects/arise/
├── README.md            this file
├── AGENTS.md            instructions for an agent (scope, locked decisions, traps)
├── STATE.md             verified build status (pinned to a commit)
├── CHANGELOG.md         append-only history, newest first
└── docs/                research + design documents (see docs/README.md)
```

## Documentation

[`docs/README.md`](docs/README.md) indexes every document in this project and
names the authoritative one. When documents disagree, the authoritative one wins
and the disagreement is recorded as a bug.
