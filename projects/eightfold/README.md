# Eightfold

*A mobile-first PlayStation 3 emulator for Android that stays cool, boots fast, and configures itself.*

**Status:** Plan only · design complete, **no code** — `PLAN.md` is a draft awaiting approval, and its M0 feasibility gate has not been run

## What this is

An Android PS3 emulator aimed at the thing the existing ones are worst at: **playing
for thirty minutes on a phone without cooking it or asking you to tune a hundred
settings.**

Three claims, and no others:

1. **It configures itself.** Identify the disc, apply a signed per-game profile,
   show a measured verdict. No settings tree on first run.
2. **It stays cool.** The framerate target is the contract; render resolution is the
   variable. A governor reads Android's own thermal APIs and holds the target
   instead of letting the device throttle into slow motion.
3. **It boots fast the second time.** A persisted recompiler cache per title, warmed
   in the background on charger.

It does **not** claim to run every PS3 game. On current phone hardware that claim
would be false — see below.

## Why this is a plan and not code

An emulator that already exists is not a good reason to write a new one. `PLAN.md`
§3 D1 makes the case explicitly: we do **not** reimplement the Cell Broadband Engine
core. Writing one is a decade of work, and RPCS3's Arm64 backend is already good and
improving quickly. What is missing on Android is the *mobile layer*: thermals,
configuration, cold-start, and honest compatibility data.

So this project is a GPLv2 Android product built on the existing core lineage, and
its engineering effort goes where the incumbents' changelogs say the pain is.

## The hardware floor is real

The PS3's Cell has **six usable SPEs**, and games run all six. Each needs a host
core. A flagship phone has two to four *performance* cores. That arithmetic — not
marketing — is why this targets Snapdragon 8 Gen 2-class hardware and refuses to
install below it. A mid-range phone cannot be made to do this, and an app that says
otherwise earns one-star reviews from people it misled.

## Read next

- [`PLAN.md`](PLAN.md) — the plan of record: hardware, decisions, milestones, legal.
- [`docs/RESEARCH.md`](docs/RESEARCH.md) — what was verified, from where, and what is
  still believed rather than known.
- [`docs/README.md`](docs/README.md) — the index and the reading order.
- [`STATE.md`](STATE.md) — verified build status. Today it says: nothing has been run.

## How to run it

Nothing to run. There is no source tree yet — the M0 feasibility spike is the first
thing that creates one, and only after the plan is approved.

## Provisional name

`Eightfold` refers to the eight SPEs in a Cell processor. It avoids the trademark
trap of naming the app after the console, which matters if this is ever published.
The name is easy to change now and expensive later — `PLAN.md` §15 asks for
confirmation before M1.
