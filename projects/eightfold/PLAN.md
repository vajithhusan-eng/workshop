# Eightfold — plan of record

**Status:** PLAN DRAFT · **not approved** · nothing built
**Date:** 2026-10-29
**Approval gate:** the user says "build". Until then this document is a proposal,
and `PLAN DRAFT` is deliberately not `PLAN APPROVED` (`PROJECT-STANDARD.md` §4.7).

Claims in this document carry one of three marks:

- **cited** — comes from public reporting, source and date in [`docs/RESEARCH.md`](docs/RESEARCH.md).
- **[verify:M0]** — believed true, unproven, and named as a question the M0 spike must answer.
- **plain** — engineering reasoning from the two above; no external claim.

---

## §0 TL;DR

Eightfold is a **mobile-first PlayStation 3 emulator for Android**, aimed at
sustained playable framerates on flagship and near-flagship Arm phones rather than
at peak benchmark numbers on a cold device.

Four decisions define it, and every other section follows from them:

| # | Decision | Why |
|---|---|---|
| **D1** | **We do not write a PS3 emulator from scratch.** We build on the GPLv2 RPCS3 lineage, vendored as a tracked subtree. | The Cell is the hardest mainstream emulation target ever shipped to consumers. RPCS3 has spent ~15 years and a large contributor base getting to "most games boot". A from-scratch core is not a product plan, it is a decade. |
| **D2** | **The product is the mobile layer, not the core.** Thermal governor, zero-config per-game profiles, cold-start compile cache, honest compatibility data. | Every existing Android PS3 emulator is a desktop core with a touch overlay. They are hard to configure, they throttle, and they crash. That gap is the entire opportunity. |
| **D3** | **Open source, GPLv2, published per release.** | Forced by D1 (RPCS3 is GPLv2). Treated as a design constraint from day one, not a compliance chore discovered at launch. |
| **D4** | **One named hardware floor, stated up front, enforced at install time.** Snapdragon 8 Gen 2-class or better. | Physics, not positioning. See §1.4. A mid-range phone cannot emulate six SPEs on four performance cores, and an app that pretends otherwise earns one-star reviews. |

**The one honest sentence:** *PS3 emulation on a phone in 2026 is real but
selective.* Games that lean on the SPUs — which is most of the famous ones — will
not be playable on this hardware generation. Eightfold's claim is not "runs PS3
games". It is: **"boots a named, measured list of games, holds its framerate for
30 minutes, and never asks you to tune a setting."**

---

## §1 The machine we are emulating

Everything hard about this project traces to one page of hardware reality.

### §1.1 Cell Broadband Engine

| Unit | Spec | What it costs us |
|---|---|---|
| **PPE / PPU** | PowerPC 64-bit, 2-way SMT, 3.2 GHz, 512 KB L2 | Two guest threads on one host core. JIT-recompiled. The tractable part. |
| **SPEs** | 8 present, **6 usable** in games (one disabled for yield, one reserved by the OS), 3.2 GHz | Each is an independent 128-bit SIMD processor with **its own 256 KB private SRAM** and no direct view of main memory. Six of them means six recompiled code streams, six code caches, six host threads' worth of work. |
| **EIB ring bus** | ~200 GB/s on-die | Not emulated as hardware; emulated as *cost*. Every SPE↔memory transfer is a `memcpy` plus a scheduling decision. |
| **XDR main RAM** | 256 MB @ 25.6 GB/s | Guest-visible traffic we must actually service. |
| **RSX** | G70/G71-derived, 550 MHz, 256 MB GDDR3 @ ~22.4 GB/s, **no unified shaders, no geometry stage** | Fixed vertex/fragment split, big-endian vertex and texture data, and a 2006-era feature set that has to be mapped onto modern Vulkan. |

Total guest RAM: **512 MB**. Total guest bandwidth demand: **~48 GB/s** of
guest-visible traffic (25.6 + 22.4), out of a phone's roughly 60–90 GB/s *shared
with its own GPU*.

### §1.2 Four walls, in the order they will hurt

1. **SPU parallelism is bounded by performance cores, not by cores.** A PS3 game
   runs six SPEs concurrently because that is the hardware it was written for.
   Each SPE needs a host thread to recompile and run on. A Snapdragon 8 Gen 2 has
   **one prime + four performance cores**; the rest are efficiency cores that will
   run an SPE at a third of the speed. On a 4+4 mid-range SoC the arithmetic simply
   does not close. This is the single most important fact in the plan: **the
   hardware floor is a core-count fact, not a marketing choice.**
2. **Guest code is big-endian; the host is little-endian.** Every typed load, every
   vertex fetch, every texture decode crosses an endianness boundary. RPCS3 absorbs
   this in the JIT (byte-reversal in generated code) and in the GPU backend (format
   handling). Vulkan has no "swap this format" flag, so the GPU-side half becomes
   shader work or compute work. It is a permanent tax on a mobile GPU.
3. **Thermals convert peak into fiction.** A phone has a ~4–6 W sustained budget
   against a 65–125 W desktop. A cold benchmark measures a device that does not
   exist after minute eight. Any design that optimises peak fps is optimising the
   wrong number.
4. **Driver quality is the difference between 20 and 40 fps.** Adreno with the
   open-source **Turnip** driver is materially better than stock, and Turnip is
   Snapdragon-only. Mali (Arm's own GPU) is worse again. A cross-vendor promise
   is a promise to ship the bad path to half the audience.

### §1.3 Why the JIT path is LLVM-only on Arm — and why that is a product problem

RPCS3's PPU recompiler has two backends: an LLVM backend, and an **ASMJIT** fast
backend. ASMJIT is an x86/x64 assembler — it emits x86 machine code and nothing
else. [verify:M0] On an AArch64 build the fast path therefore does not exist and
the LLVM path carries the whole load.

LLVM compile latency is real latency: it is the "first boot stutters" and "shader
compilation" experience every user of every Arm emulator reports. On desktop it is
absorbed by a beefy CPU and a warm disk cache. On a phone it is a 3–20 second wait
per title the first time, and a visible hitch whenever a new code block is reached.

That is not a bug we can patch — it is the shape of the platform. It is also the
single clearest product opportunity in this plan, and it gets §8 and milestone M5
to itself.

### §1.4 The floor, stated once

| Tier | Hardware | Expectation |
|---|---|---|
| **Supported** | Snapdragon 8 Gen 2 / 8 Gen 3 / 8 Elite, 12 GB+, Adreno 730/740/750/830, Turnip recommended | Tier-1 list playable at 30 fps sustained |
| **Marginal** | Snapdragon 865/870-class, 8 GB | Light 2D and simple 3D titles only; documented, not promised |
| **Refused** | Anything below, anything with < 8 GB, any GPU without Vulkan 1.1+ | Not installable via Play device filtering; a clear in-app explanation if side-loaded |

Refusing hardware is a feature. Every negative review on the incumbents is a user
who installed this class of software on a phone that was never going to run it.

---

## §2 Market reality, October 2026

Read [`docs/RESEARCH.md`](docs/RESEARCH.md) for sources and dates. The summary
that shapes the plan:

- **RPCS3 itself will not come to Android.** Native Arm64 builds shipped in
  December 2024 (macOS, Linux, Windows-on-Arm), and the team has stated it has no
  intention of porting to Android or iOS — at least partly because of community
  behaviour and scam-app redistribution. Reaffirmed in 2026. **cited**
- **Arm64 performance improved sharply in 2026.** A contributor's six-month Arm64
  effort reported **+60% performance at −25% power**, much of it from a busy-wait
  that scaled with a hardware timer running at 19 MHz instead of GHz — one bug was
  worth ~25% on its own. Separately, RawSPU Arm64 MMIO handling made several
  hundred titles work. **cited**
- **Android is therefore served by forks, not upstream.** aPS3e (GPLv2, Arm64,
  Vulkan, Android 10+, on Play) and ARMSX3 (from the ARMSX2 team, proof-of-concept
  Aug 2026, on Play Oct 2026) are the two live options. Reported floors: aPS3e
  wants a flagship SoC; ARMSX3 states Snapdragon 865+/8 GB for lightweight titles
  and Snapdragon 8 Gen 2/12 GB as recommended. **cited**
- **Where they are weak — from their own users.** The recurring complaints are not
  "the emulation is wrong". They are: *"hard to use… so confusing to manually set
  all the settings"*, per-game config drift, "phone gets warm around 42–43 °C", and
  crashes on specific hardware. One ARMSX3 changelog is devoted almost entirely to
  *not wasting CPU while waiting* and to thermal behaviour. **cited**

Read that list again and the product thesis writes itself: **the emulation core is
no longer the bottleneck for the market — the mobile experience is.**

---

## §3 Decisions

**D1 — Fork the lineage, do not reimplement the core.**
Vendored at `core/` as an upstream-tracking subtree (not a submodule: we need to
patch it, and a submodule makes a reproducible Android build painful). Divergence
budget: **≤ 2% of upstream files touched per rebase**, enforced by a rebase report,
not by good intentions. Rebase cadence: monthly, plus immediately for Arm64 fixes.

**D2 — The mobile layer is the product.** §4. This is where the engineering hours
that differentiate us go.

**D3 — GPLv2, source published per release, automated.** §10. A release job that
forgets the source tarball is a licence violation; so the job builds the tarball.

**D4 — One hardware floor, enforced at install.** §1.4.

**D5 — Native Android UI (Kotlin + Jetpack Compose), not Flutter.**
The game surface must be a `SurfaceView`/`Vulkan` swapchain owned by the emulator
core, with zero copies and no intermediate texture. A cross-platform UI toolkit
would put a texture bridge and a frame of latency between the core and the screen,
for menus that are not the hard part. Compose handles the library, settings,
overlay controls and controller mapping perfectly well. **This is the one place in
this workspace where Flutter is the wrong answer, and the reason is the render
path, not taste.**

**D6 — Android only for v1. iOS is out of scope, permanently, not "later".**
A JIT-emitting emulator cannot run on iOS as a distributed third-party app. Saying
"iOS later" would be a lie with a roadmap attached.

**D7 — No network play, no PSN/RPCN, no PS1-classics mode in v1.** Each is a
subsystem with its own compatibility matrix. They are listed in §14 so their
absence is a decision rather than an oversight.

**D8 — Every performance claim is a measurement on a named device, produced by the
harness in §12.** No "up to", no synthetic peak, no first-minute fps.

**D9 — Firmware, keys and games are the user's.** We ship none. §10.

---

## §4 Product thesis — three pillars

The incumbents win on "it exists". We win on three things they measurably do not do.

### Pillar 1 — It configures itself

Today: the user is handed a settings tree with a hundred toggles and told to find
the combination that makes *their* game work on *their* phone. Reviews say so,
plainly.

Eightfold: identify the title (disc ID from `PARAM.SFO` / `PS3_DISC.SFB`), look up a
signed profile, apply it, launch. The user sees a game card with a measured
verdict — *"Playable · 30 fps · Snapdragon 8 Gen 2"* — or *"Not supported on this
device, and here is why"*. §7.

### Pillar 2 — It stays cool

Today: excellent first three minutes, then thermal throttle and a hot phone.

Eightfold: the framerate target is the contract, and resolution is the variable.
A governor reads Android's own thermal-headroom and performance-hint APIs, watches
frame-time percentiles, and trades render resolution and shader work to hold the
target instead of letting the device cook. §6.

### Pillar 3 — It boots fast, the second time

Today: first launch is a compile stall, and it happens again after every cache
clear.

Eightfold: a persisted recompiler cache per title, warmed in the background on
charger, plus a warm Vulkan pipeline cache. First run is a one-time cost that is
shown honestly with a progress bar; every run after it is fast. §8.

---

## §5 Architecture

Full detail, thread model and interfaces: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

```
┌──────────────────────────────────────────────────────────────┐
│ L3  Kotlin · Jetpack Compose          app/                   │
│     library · per-game screen · overlay pad · controller map │
│     compatibility browser · profile inspector · settings     │
└───────────────────────────┬──────────────────────────────────┘
                            │ AIDL/Binder service + JNI
┌───────────────────────────▼──────────────────────────────────┐
│ L2  Emulator host (C++17/20)          platform/              │
│     lifecycle · Vulkan surface · AAudio · input · SAF storage │
│     EmuHost facade ── governor ── profile store ── watchdog   │
└───────────────────────────┬──────────────────────────────────┘
                            │ narrow C++ facade, no UI types
┌───────────────────────────▼──────────────────────────────────┐
│ L1  Vendored core (GPLv2)             core/                  │
│     PPU JIT · SPU JIT ×6 · RSX→Vulkan · HLE kernel · loader  │
└──────────────────────────────────────────────────────────────┘
```

Three rules keep this honest:

1. **L1 is upstream-shaped.** We patch it; we do not redesign it. Every patch is a
   file in `patches/` with a reason and a tracked upstream status.
2. **L2 owns every Android API call.** The core never learns what a `Surface` is.
   That keeps the rebase cheap and makes the core testable on a desktop host.
3. **L3 owns no emulation state.** The UI can be killed and restarted; the game
   keeps running in the service.

**Thread inventory** (the thing that decides whether this is fast):

| Thread | Affinity | Notes |
|---|---|---|
| PPU ×1–2 (SMT) | prime core | Highest priority; the governor protects this first |
| SPU ×6 | performance cluster | The contention point. Grouped and yielded when DMA-blocked (§6.3) |
| RSX submit | any performance core | Must not block the PPU |
| Audio | efficiency core | AAudio low-latency, 48 kHz |
| Governor | efficiency core | 4 Hz sampling; must cost < 0.5% CPU |
| UI | main | Never touches emulation state |

That is nine runnable threads on a phone with four performance cores. The plan is
not to wish that away — it is to schedule it deliberately (§6.2) and to schedule it
*measurably* (§12).

---

## §6 Performance — the governor is the feature

### §6.1 Budgets (targets, not measurements — M0 replaces them with real numbers)

| Target | Frame budget | Core compute (PPU+SPU JIT) | GPU submit | Audio + host |
|---|---|---|---|---|
| 30 fps (default) | 33.3 ms | ≤ 23 ms | ≤ 8 ms | ≤ 2 ms |
| 60 fps (opt-in, light titles) | 16.7 ms | ≤ 11 ms | ≤ 4.5 ms | ≤ 1.2 ms |

Thermal contract: **sustained fps ≥ 90% of the first-minute median after 30
minutes**, at ≤ 43 °C skin temperature on the reference device. If the device
cannot hold it, the governor drops resolution — never silently drops the target
without telling the user.

### §6.2 Inputs the governor reads (all public Android APIs)

- `PowerManager.getThermalStatus()` and `getThermalHeadroom(seconds)` — official
  thermal signals, not `/sys` scraping.
- `PerformanceHintManager` (ADPF) — per-thread CPU hints, including a session for
  the emulation thread group so the scheduler knows the work is latency-critical.
- Frame-time percentiles from our own present path (p50 / p95 / p99), not averages.
- Battery current from `BatteryManager`, to distinguish "hot" from "hot and
  draining at 6 W".

### §6.3 What it is allowed to change, in order

1. **Render resolution scale** (100% → 85% → 70%), the cheapest and least
   noticeable lever on a phone screen.
2. **Shader/pipeline work**: skip redundant state transitions, lower precision where
   the game tolerates it.
3. **SPU scheduling policy**: group DMA-blocked SPEs onto fewer host threads and
   yield the freed core to the PPU.
4. **Frame target**: only as a last resort, only with an explicit on-screen notice,
   and only if the user has enabled "prefer smoothness" (default: on).

It is never allowed to: silently change a per-game config, drop audio, or reduce
the emulated clock (that changes game *logic*, not just speed).

### §6.4 The scheduling bet

The interesting R&D is §6.3 item 3. Six SPEs on four performance cores is
oversubscribed by construction. RPCS3 already detects and yields on SPU busy-waits
— the Arm64 effort's single biggest win was exactly such a fix. **Our bet is to go
further: a cooperative SPU scheduler that treats DMA-blocked SPEs as runnable
state rather than threads.** This is a research item with a kill criterion (M5), not
a promise.

---

## §7 Zero-config: game identity → profile → verdict

```
disc image ──► PARAM.SFO (title id, e.g. BLUS30109)  ──► hash
                                                    │
                          ┌─────────────────────────▼──────────────────┐
                          │ local profile store (versioned, signed)    │
                          │  · config keys the core actually accepts   │
                          │  · measured verdicts per SoC class         │
                          └─────────────────────────┬──────────────────┘
                                                    │ miss
                          ┌─────────────────────────▼──────────────────┐
                          │ OTA profile bundle (Ed25519-signed JSON)   │
                          │  fail-closed on bad signature → built-ins  │
                          └─────────────────────────┬──────────────────┘
                                                    │
                          verdict card: Playable 30 fps · Marginal · Unsupported
```

Rules that keep this from becoming a second settings app:

- **Profiles are data, not code.** A config key that the core does not actually
  accept must fail the profile at load time, in CI, not at runtime on a user's
  phone. The profile schema is generated from the core's config registry
  [verify:M1] so it cannot drift.
- **Every profile is signed**, and a bad signature fails *closed* to built-in
  defaults. OTA cannot become a remote-code vector.
- **Verdicts are per SoC class, not per device.** "Snapdragon 8 Gen 2" is a
  measurement; "your exact phone" is a support burden.
- **The user can still open the settings.** The difference is that they never have
  to.

Telemetry: **opt-in, off by default**, and limited to *what the governor already
measures* (frame-time percentiles, thermal status, SoC, title id) so that profile
tuning is possible. No game content, no save data, no play times. This is stated in
the UI in one sentence, not buried.

---

## §8 Cold start — the AArch64 compiler problem

This is the most interesting engineering in the project and the least glamorous.

**The problem.** With no ASMJIT on Arm (§1.3), the LLVM recompiler is the only path,
and LLVM is a compiler, not an assembler: it is tens of milliseconds per compiled
block, not microseconds. On first contact with a title, a phone spends a long,
visible, battery-burning period doing exactly one thing: compiling code it will
reuse forever afterwards.

**The plan, in order of cost:**

1. **Persist the module cache** per title, keyed by core build hash + profile hash.
   Invalidate correctly on rebase — a stale cache is a crash generator, so this is
   a correctness surface, not a cache.
2. **Warm it in the background**: on charger, screen off, after install or after a
   core update, run a bounded compile pass with the governor's permission. Never
   while the device is overheating.
3. **Warm the Vulkan pipeline cache** the same way. ARMSX3's changelog shows how
   much pain lives here — they removed a shader warning that fired on every compile,
   which means it fired a *lot*.
4. **Close the loop with the user.** First boot shows a real progress number from
   the compiler ("Compiling · 412 / 1,180 blocks"), not a spinner and a lie that it
   is "loading".

**M5 stretch, explicitly killable:** a lightweight AArch64 block compiler for cold
paths, emitting straight to machine code with a correctness oracle against LLVM.
If it cannot be proven equivalent, it does not ship. If it works, it is the single
biggest differentiator available on this platform.

---

## §9 Compatibility tiers and the launch list

No compatibility claim is ours until the harness in §12 produced it. The list below
is the **hypothesis** M0 must test — titles reported playable by others on Arm
hardware, chosen to cover the failure modes we care about. **cited**, unverified by
us.

| Tier | Meaning | Candidate titles (hypothesis) |
|---|---|---|
| **T1 — must hold 30 fps** | Simple geometry, light SPU use. Our floor. | 3D Dot Game Heroes · Catherine · Rayman Origins · Limbo · Dragon's Crown · Virtua Fighter 5 · Ridge Racer 7 |
| **T2 — should be playable** | Known-good on RPCS3 Arm, heavier. Our target. | Demon's Souls · Tekken 6 · Skate 3 · Mass Effect · Resident Evil 5 · Initial D Extreme Stage · Dante's Inferno |
| **T3 — measured, not promised** | SPU-heavy. Ships only if it holds. | inFamous · Gran Turismo 5/6 · Twisted Metal · Metal Gear Solid 4 |
| **T4 — documented unsupported** | We say so in the app, with the reason. | Anything requiring PSN, six-SPE-saturating titles on non-flagship SoCs, The Last of Us-class workloads |

The important behaviour is the last one: **a title we cannot run is listed as such,
with the reason**, instead of being silently bootable and broken. Users forgive a
limit. They do not forgive being lied to.

---

## §10 Legal and licensing

Non-negotiables, all of them consequences of D1, D3 and D9.

**GPLv2 (inherited from RPCS3).**
- The app is GPLv2. We publish complete corresponding source for each release.
- No proprietary blobs linked into the core. Vendor driver blobs are loaded at
  runtime by the OS, not linked, which is why custom drivers are a *user choice*.
- **No additional restrictions.** No anti-tamper, no licence check that prevents
  redistribution of modified versions, no App Store terms layered on top that
  contradict the licence.
- Selling the app is permitted by GPLv2; what is *not* permitted is shipping it
  without source. The release job in §11 M6 exists so this cannot be forgotten.
- Attribution: visible, in-app, naming RPCS3 and every other upstream we touch.

**Sony.**
- **No firmware.** RPCS3 requires the user to install PS3 system firmware. The PUP
  file is Sony's copyrighted work; it is user-supplied, never bundled, never
  downloaded by us.
- **No keys, no games.** We ship no decryption keys beyond what upstream already
  contains and no content of any kind. Disc images are the user's own dumps.
- **Trademark.** We never imply affiliation. The Play listing carries the same
  shape of disclaimer the incumbents use, and the app is named `Eightfold` —
  not "PS3 something" — precisely so the name is ours.
- **DMCA §1201 is residual risk we disclose rather than dismiss.** The project
  should get a legal read before a *public* launch (not before M0). Recorded as R5.

**Play Store.** Emulators are permitted on Play (both incumbents are there). Our
obligations: no linking to ROM sources, no bundled content, accurate device
filtering, and a listing that does not overclaim compatibility.

---

## §11 Milestones

Sequential, each with an exit condition. Durations assume one focused developer
plus agent assistance.

### M0 — Feasibility spike (**5 days**) · **KILL GATE**

Build the vendored core for Android (`arm64-v8a`, NDK r28, C++20, Vulkan) on the
reference device. Boot five titles. Measure. **Do not write UI.**

Exit conditions, all empirical:

1. Core builds for `arm64-v8a` with **< 500 lines** of divergence from upstream. More
   than that and the maintenance model in D1 is wrong — re-evaluate starting from an
   existing Android fork instead of upstream.
2. **≥ 3 of 5** candidate T1/T2 titles reach gameplay.
3. Sustained 30-minute run recorded: fps percentiles, skin temp, watts.
4. Turnip loads and measurably beats stock Adreno on at least one title.
5. [verify:M0] questions answered: LLVM-only path confirmed; ASMJIT absence
   confirmed; SPU thread contention quantified on a 4-performance-core SoC.
6. A written go/no-go with numbers.

**Kill criteria — write these down before starting, because at 2 a.m. everything
looks fixable:**
- < 3 of 5 titles reach gameplay → **stop**. Do not re-scope into a smaller promise
  without the user in the room.
- Sustained fps < 60% of first-minute fps on the best title → the thermal premise in
  §6 is wrong; §4 Pillar 2 needs rewriting before M1.
- Divergence > 500 lines or build not reproducible → re-baseline onto an existing
  GPLv2 Android fork and accept the maintenance trade-off.

### M1 — Platform bring-up (**2 weeks**)
Surface, AAudio, input (controller + touch overlay), SAF-based storage with
`fd`-backed ROM access (no copying 20 GB images), lifecycle (suspend/resume,
rotation, backgrounding), and a crash-safe service boundary.
**Exit:** play one title start to finish with a controller; 30-minute session with
no leak and no ANR.

### M2 — Zero-config engine (**2 weeks**)
Disc-ID detection, profile schema generated from the core config registry, signed
profile store, OTA bundle with fail-closed verification, verdict cards, opt-in
telemetry. **Exit:** a fresh install boots a T1 title with **zero** user settings.

### M3 — Sustained-performance governor (**2.5 weeks**)
ADPF hints, thermal-headroom loop, resolution scaling, frame pacing, per-SoC
presets, on-screen honest status. **Exit:** 30-minute run holds ≥ 90% of
first-minute median on the reference device; skin ≤ 43 °C.

### M4 — Cold start (**2 weeks**)
Persisted module cache with correct invalidation, background warm pass, pipeline
cache warm, first-boot progress UI. **Exit:** second launch to gameplay < 25% of
first-launch time, measured across 3 titles.

### M5 — AArch64 fast compiler (**3 weeks**) · **R&D, killable**
Correctness-oracle-gated block compiler for cold paths. **Exit:** passes the oracle
on the T1 corpus and cuts first-boot compile time ≥ 40%. Fails either → ship M4
alone and record the negative result.

### M6 — Release hardening (**2 weeks**)
Play listing with device filtering, automated GPL source publication, licence and
attribution screens, crash reporting with consent, closed beta (~100 users on
documented hardware), compatibility list published from harness data.

**Total: ~11.5 weeks to closed beta, contingent on M0.** M0 is 5 days of the 11.5
and it is allowed to end the project. Run it first and nothing else.

---

## §12 Proving "fast and stable" — the harness

Claims without this section are marketing. It ships in M0, not M6.

- **Deterministic input traces.** Recorded controller input replayed per title, so
  two runs are comparable.
- **Metrics:** frame-time p50/p95/p99, dropped-frame count, audio underruns, guest
  and host RSS, thermal headroom, battery watts, skin temperature if available.
- **Duration:** a 30-minute sustained run is the release gate, because a 3-minute
  run measures a phone that will not exist in the hands of a user.
- **Devices:** at minimum one 8 Gen 2 and one 8 Elite. Physical hardware, manual,
  **opt-in only, never in CI** (`PROJECT-STANDARD.md` §4.5).
- **Output:** a JSON result committed per core release, which becomes the numbers on
  the compatibility cards. One source of truth for "playable".

---

## §13 Risks

| # | Risk | Severity | Response |
|---|---|---|---|
| **R1** | Upstream RPCS3 will not accept mobile patches; we diverge and rot | High | Vendored subtree + monthly rebase + divergence budget enforced by a rebase report (D1) |
| **R2** | GPLv2 lets a better-funded fork take our work | Low | Accepted. Strategy is execution speed on the mobile layer, not secrecy |
| **R3** | Physics wins: sustained performance is not achievable on the target list | High | M0 kill gate; M3 exit condition; honest resolution scaling |
| **R4** | Turnip is Snapdragon-only; Mali users get a worse product | Medium | Published per-GPU compatibility, no cross-vendor promises |
| **R5** | Legal action (Sony) or DMCA §1201 exposure | Medium | No keys/firmware/games; legal read before public launch; disclaimer |
| **R6** | LLVM compile latency ruins the first-run experience | High | §8; M4 exit condition; M5 as the real fix |
| **R7** | OOM kills on 8 GB devices | Medium | Memory ceiling per device class; refuse rather than crash |
| **R8** | Scoped storage breaks fd-based ROM access for some formats | Medium | Prove in M1 with ISO/PKG/folder; fall back to managed copy with a progress bar |
| **R9** | Every incumbent is also improving, fast | Medium | Our moat is the mobile layer and measured honesty, not the core |
| **R10** | Scope creep into PSN, networking, PS1 classics | Medium | §14 is a list of decisions, not a wishlist |

---

## §14 Out of scope for v1 — decisions, not oversights

- **iOS.** D6. A JIT emulator cannot be distributed on iOS. Permanently out.
- **Online play / PSN / RPCN.** Its own compatibility matrix, its own support load.
- **PS1 classics** (which run through the PS3's own software emulator). RPCS3 added
  Arm64 support for this in 2026, but it is a second compatibility surface.
- **Wii U / Switch / PS4 emulation.** Different machines entirely.
- **A Windows-on-Android translation layer.** That is a different product.
- **Cloud streaming of games.** Different product, different legal posture.
- **"Runs everything" claims.** D8.
- **Custom driver bundling.** Guide the user to Turnip; do not redistribute blobs.

---

## §15 Open questions — answer before M0 starts

1. **Reference hardware.** M0 needs a physical Snapdragon 8 Gen 2 (or better) Android
   device with 12 GB RAM. Without one, the gate cannot be run and the project is
   blocked at step one. Which device is available?
2. **Distribution and money.** Free GPLv2 app, or a paid/Premium split as the
   incumbents do? GPLv2 permits both; the Play listing and the source-publication
   job differ.
3. **App identity.** `Eightfold` is a working name (eight SPEs in a Cell). Changing
   it later is cheap while nothing is published and expensive afterwards — confirm
   or replace before M1.
