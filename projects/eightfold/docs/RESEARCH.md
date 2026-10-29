# Eightfold — research record

What was actually checked, when, and what remains a belief. `PLAN.md` cites this
file; it does not replace it.

**Compiled:** 2026-10-29. Re-check before relying on any line older than a quarter —
this field moves monthly.

Two grades of claim appear here:

- **Checked** — read from a named source on the date shown. The source may still be
  wrong; we are not the origin of the claim.
- **Believed** — engineering knowledge not re-verified during this research pass.
  Anything in this grade that a decision depends on is promoted to a `[verify:M0]`
  question in `PLAN.md`.

---

## 1. Upstream: RPCS3 will not come to mobile

| Claim | Grade | Source |
|---|---|---|
| Native Arm64 builds for macOS / Linux / Windows-on-Arm shipped Dec 2024 | Checked | Android Authority, 2024-12-10 |
| The team explicitly declined to port to Android or iOS, citing community toxicity, GPL-violating redistributions, and scam apps on Play | Checked | Android Authority, 2024-12-10 |
| Position unchanged in 2026: no mobile ports, no separate console emulators; warns about fake "RPCS2" downloads | Checked | LavX News, 2026-08-18 |

**Consequence for us:** every Android PS3 emulator is a fork. There is no upstream
to depend on, which makes rebase discipline (R1) a first-class engineering concern
rather than housekeeping.

## 2. Arm64 performance, 2026

| Claim | Grade | Source |
|---|---|---|
| +60% emulation performance at −25% power across six months of Arm64 optimisation work | Checked | POCG 2026-08-07; Time Extension 2026-08-06 |
| The largest single win was a busy-wait whose wait duration assumed a GHz-rate hardware timer; on Arm the timer ran at **19 MHz**, making the function ~150× slower. Fixing it alone: ~+25% average, ~10% power | Checked | POCG 2026-08-07; Time Extension 2026-08-06 |
| One Arm64 change "fixes several hundred games", incl. the Ratchet & Clank series | Checked | VideoCardz 2026-08-02 |
| RawSPU Arm64 MMIO handling made many RawSPU titles and the PS1-classics path work on Arm64 | Checked | VideoCardz 2026-08-02 |
| Reference device for that work was an AYN Odin 2 (Snapdragon 8 Gen 2 class) running Linux | Checked | Time Extension 2026-08-06 |
| Cell recompilation backends are **LLVM** and **ASMJIT** | Checked | Tom's Hardware, 2026-04-05 |
| SPU emulation is the largest CPU bottleneck; each SPU is recompiled and executed on a host CPU thread | Checked | Tom's Hardware, 2026-04-05 |
| ASMJIT emits x86/x64 only, so AArch64 builds have no fast-assembler backend | **Believed** | `[verify:M0]` — confirmed by inspecting the vendored build config, not by reading ASMJIT docs in this pass |

The last row matters more than its grade suggests: it is the entire premise of
`PLAN.md` §8 and milestone M5. **Verify it on day one of M0.**

## 3. What exists on Android, and what its users say

| Project | Facts | Grade | Source |
|---|---|---|---|
| **aPS3e** | GPLv2, Arm64, Vulkan, Android 10+, PKG/ISO/folder, LLVM recompilation, LLE/HLE choice, per-game config, Play listing updated 2026-08-26 | Checked | Play listing; GitHub `aenu1/aps3e` (748★, created 2025-06-03) |
| **ARMSX3** | From the ARMSX2 team; PoC Aug 2026, Play Store Oct 2026, 122 MB; **min** Snapdragon 865 / Adreno 650 / Mali-G57 / 8 GB; **recommended** Snapdragon 8 Gen 2 / Adreno 740 / 12 GB; **optimal** 8 Elite / Adreno 830 / 12 GB + active cooling | Checked | Android Authority 2026-08-07 and 2026-10-09 |
| ARMSX3 early results | Skate 3 20–30 fps on 8 Gen 2; Catherine ~22 fps; 3D Dot Game Heroes mid-teens | Checked | Android Authority 2026-08-07 |
| ARMSX3 0.9.7 | Fixed cores spinning at full speed during waits on 8 Elite-class devices; removed pointless texture-state transitions; stopped a shader warning flooding the log on every compile | Checked | GenerationAmiga, 2026-09-07 |
| aPS3e v2.42 | Added Mali-G57 / Valhall support | Checked | EmuCR, 2026-08-31 |
| aPS3e user reviews | "Hard to use… so confusing to manually set all the settings"; "phone gets warm around 42–43 °C"; "getting 30 fps in Demon's Souls is playable… had to tweak so many settings" | Checked (user-generated, indicative not authoritative) | Play listing reviews, 2025–2026 |
| 2025 precursor controversy | The first aPS3e release was reported to be a Termux-wrapped Linux build rather than native; the repo disappeared and returned; there was a request for payment to open the source | Checked | Android Central 2025-03-03; Android Authority 2025-02-20 |
| A public PS3-on-Android fork's changelog | Documents RSX FIFO desync crashes on Adreno/Turnip under fast FIFO accuracy, and an Adreno performance regression affecting every Android device; both had to be fixed retroactively | Checked | `ouroboros420/rpcsx` CHANGELOG, v1.2.0–v1.3.0 |

**Consequence for us:** two of the three differentiators in `PLAN.md` §4 (zero-config,
thermal behaviour) are literally items the incumbents are patching as bugs in their
changelogs. That is the market telling us where the product is.

## 4. Hardware reference values

These are standard published figures, **not re-verified against datasheets during
this pass**. They are used for order-of-magnitude reasoning only; if a design
decision hinges on one, check the datasheet.

| Item | Value | Grade |
|---|---|---|
| Cell PPE | PowerPC 64-bit, 2-way SMT, 3.2 GHz, 512 KB L2 | Believed |
| Cell SPEs | 8 present, 7 addressable by the OS, **6 usable by games**; 3.2 GHz; 128-bit SIMD; **256 KB private local store**; no direct main-memory access (DMA via MFC) | Believed |
| XDR main RAM | 256 MB, 25.6 GB/s | Believed |
| RSX | G70/G71-derived, 550 MHz, 256 MB GDDR3, ~22.4 GB/s, **separate vertex and fragment pipelines, no geometry stage, no unified shaders** | Believed |
| Total guest RAM | 512 MB | Believed |
| Snapdragon 8 Gen 2 | 1 prime + 4 performance + 3 efficiency cores; Adreno 740; LPDDR5X | Believed — **the core-count split is the load-bearing number for §1.2(1)** |
| Snapdragon 8 Elite | 2 prime + 6 performance (Oryon); Adreno 830; LPDDR5X | Believed |

The one figure to double-check before quoting it externally is the 8 Gen 2 core
split, because `PLAN.md` §1.4's hardware floor is derived from it.

## 5. Open questions the M0 spike must close

| # | Question | Why it matters |
|---|---|---|
| Q1 | Is ASMJIT truly unavailable on the AArch64 build, leaving LLVM as the only PPU backend? | Premise of §8 and M5 |
| Q2 | How much upstream divergence does an Android NDK build actually need? | `PLAN.md` M0 exit condition 1 / R1 |
| Q3 | Per frame, how much time is each SPE runnable vs. DMA-blocked on a 4-performance-core device? | Decides whether §6.4 stage 2 or 3 is needed |
| Q4 | Is Turnip measurably faster than stock Adreno on the T1 corpus? | Decides how loudly we can recommend it |
| Q5 | Do folder-format titles work through SAF traversal, or do they need an import index? | M1 scope / R8 |
| Q6 | Correct thermal and sustained numbers for 5 candidate titles over 30 minutes | Replaces every budget in §6.1 with a measurement |

---

## 6. What is deliberately not researched yet

Reason: it is downstream of the M0 gate, and researching it now would be a way to
feel productive while the gate stays unrun.

- Per-title config values — meaningless until a build boots a title.
- Profile OTA hosting and key custody — a two-hour decision after M2.
- Play Store listing copy and device-filter rules — M6.
- Legal review — before public launch, not before M0.
