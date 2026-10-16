# CleanTube

[![Platform](https://img.shields.io/badge/platform-Android%20first-3DDC84?logo=android&logoColor=white)](PLAN.md)
[![Status](https://img.shields.io/badge/status-design%20only%20%C2%B7%20no%20code-orange)](PLAN.md)
[![Feasibility gate](https://img.shields.io/badge/M0%20feasibility%20gate-not%20yet%20run-critical)](PLAN.md)
[![Approach](https://img.shields.io/badge/approach-ask%20for%20no%20ads-informational)](#the-idea-that-makes-this-work)

An Android-first Flutter **ad blocker** whose headline target is YouTube.

> **Status: design only.** `PLAN.md` is the sole design document and is
> research-verified. **No code exists yet.** `PLAN.md` §5 **M0 is a feasibility
> gate** — it is designed to be able to kill this project, and it has not been run.

## The idea that makes this work

You do not need to *block* YouTube ads. You need to **not ask for them.**

YouTube serves ads to clients that request them. The web InnerTube client makes
no `adPlaybackContext` request, so there is nothing to strip: the native client
plays a stream that never carried an ad in the first place. Blocking is the hard,
brittle problem; not asking is a small one. Everything else in the plan follows
from taking that seriously.

## Three engines, one app

| Engine | What it is | Where it ships |
|---|---|---|
| **1 · Ad-Free Browser** | An Android WebView shell with a real blocking engine and filter lists | Play + F-Droid |
| **2 · YouTube Client** | A bespoke InnerTube client — no WebView in the playback path | Play + F-Droid |
| **3 · DNS Sinkhole** | A system-wide blocker via our own Kotlin `VpnService` | **F-Droid only** — Play policy forbids it |

Plus **Rule Kits**: Ed25519-signed JSON filter bundles delivered over the air, so
a filter fix never waits for a store release.

## What is deliberately not attempted

`PLAN.md` §2 lists what is impossible on a non-rooted phone, with sources: root /
LSPosed / Shizuku hooks, TLS interception, stripping ad byte-ranges out of DASH
video (ads and content are served from the same hosts, so it cannot be done), and
arbitrary `$replace` / scriptlet rules delivered by an OTA bundle — that last one
is remote code execution by design.

## Licensing — a budgeted cost, not a footnote

| Upstream | Licence | What that means for us |
|---|---|---|
| yt-dlp | Unlicense | Can be ported directly. The single most valuable reference here. |
| NewPipe / NewPipeExtractor | GPL-3.0 | **Read, do not copy** — hence the InnerTube client is a reimplementation. |
| uBlock Origin engine, AdGuard Content Blocker | GPL-3.0 | Read, do not copy. |
| HaGeZi filter lists | GPL-3.0 | Read, do not copy. |

The closed-source-vs-GPL decision is a blocker for M3.

## Milestones

M0 feasibility spike (4–5 days, **the gate**) → M1 rule engine (1 week) → M2
ad-free browser (2 weeks) → M3 YouTube client (2–3 weeks, highest risk) → M4 VPN
filter (2 weeks, F-Droid build only) → M5 release hardening (1.5 weeks). Roughly
11 weeks to a closed beta, contingent on M0 passing.

## Blockers before any code is written

1. **Distribution decision** — Play-only, F-Droid-only, or both. Blocks M4.
2. **Play developer account + D-U-N-S verification.** `PLAN.md` §2.5b records that
   the *30 September 2026* enforcement date has already passed.
3. **Rule Kit hosting** — a domain, and custody of the Ed25519 signing key.
4. **Legal review** for the EU (`PLAN.md` §6 R8/R15).

## Documentation

`PLAN.md` is the plan of record. Start at [`docs/README.md`](docs/README.md),
then read `PLAN.md` §0 (TL;DR) and §2 (the hard truth) before anything else.

> The name is provisional. "CleanTube" centres the whole product on YouTube when
> two of the three engines are general-purpose; `PLAN.md` §9 keeps alternatives
> open.
