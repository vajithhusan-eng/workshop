# Eightfold — architecture

Companion to [`../PLAN.md`](../PLAN.md). `PLAN.md` decides *what* and *why*; this
document decides *how*, at the level where implementation arguments actually happen.

**Status:** design only. Nothing here has been built. Every interface below is a
proposal until M0 proves the core builds.

---

## 1. Repository layout

```
eightfold/
├── app/                       Kotlin · Compose · Gradle module
│   ├── src/main/kotlin/dev/eightfold/
│   │   ├── ui/                library, game screen, overlay, settings
│   │   ├── service/           EmulatorService (foreground, bound)
│   │   ├── profile/           profile store, verdicts, OTA client
│   │   └── governor/          Kotlin-side thermal bridge + UI mirror
│   └── src/main/cpp/          JNI glue only — no logic
├── platform/                  C++17/20 — the mobile layer (our code)
│   ├── emuhost/               lifecycle, facade into the core
│   ├── gfx/                   ANativeWindow/Vulkan surface, swapchain
│   ├── audio/                 AAudio sink
│   ├── input/                 Android input → core pad state
│   ├── storage/               SAF/ParcelFileDescriptor → seekable streams
│   ├── governor/              thermal + frame-time control loop
│   └── profile/               profile apply/validate (C++ side of schema)
├── core/                      vendored GPLv2 emulator core — PATCHED, not ours
├── patches/                   every divergence from core/, one file each
├── bench/                     input traces + harness scripts (manual, opt-in)
├── docs/                      this directory
└── tools/                     rebase report, profile schema generator
```

**Divergence discipline.** `core/` is a subtree of our fork of the upstream core.
Every change lives in `patches/NNNN-slug.patch` with a header comment stating: what
it does, why upstream cannot take it as-is, and its upstream status
(`sent` / `merged` / `carried`). `tools/rebase_report.py` prints carried-patch
count, touched-file ratio and conflict list after each rebase. **> 2% touched files
or > 20 carried patches is a stop-and-fix, not a number to note.**

---

## 2. Process and service model

```
┌───────────────┐   bind    ┌──────────────────────────────────────────┐
│  app (UI)     │◄─────────►│  EmulatorService  (foreground service)   │
│  Compose      │  AIDL     │  ┌────────────────────────────────────┐  │
└───────────────┘           │  │ EmulatorHost (C++)                 │  │
        ▲                   │  │  ├─ Governor        (4 Hz loop)    │  │
        │ SurfaceView       │  │  ├─ ProfileStore                   │  │
        │ (zero-copy)       │  │  ├─ Watchdog        (per-thread)   │  │
        └───────────────────┤  └─────────────┬──────────────────────┘  │
                            │                │ narrow C++ facade       │
                            │  ┌─────────────▼──────────────────────┐  │
                            │  │ core/  (PPU, SPU×6, RSX→Vulkan)    │  │
                            │  └────────────────────────────────────┘  │
                            └──────────────────────────────────────────┘
```

Why a foreground service: the game must survive the UI being destroyed, a rotation,
a backgrounding, and Android's activity-recreation behaviour. The UI is a client, not
an owner. This is also what makes "suspend and resume a title mid-session" possible
without a save state — the emulation state never left the process.

**Surface ownership.** The `SurfaceView`'s `Surface` is passed down once at attach
and handed to the core as a Vulkan surface. No `TextureView`, no `Bitmap` readback,
no compositor copy. This is the whole reason D5 rejects Flutter.

---

## 3. The facade (`platform/emuhost/EmuHost.h`)

The core knows nothing about Android. The facade is deliberately small — a wide
facade is a facade that has to change on every rebase.

```cpp
struct EmuHost {
  // lifecycle
  Result  boot(const GameRef&, const Profile&, ANativeWindow*);
  void    pause();                       // guest time stops, state stays resident
  void    resume();
  Result  shutdown();                    // flushed, cached, joined

  // control
  void    set_target_fps(int hz);
  void    set_resolution_scale(float);   // governor's main lever
  Profile live_profile() const;          // what is actually in effect

  // observability — everything the governor and the bench harness read
  FrameStats  frame_stats() const;       // p50/p95/p99, drops, jitter
  CompileStat compile_stats() const;     // blocks queued/compiled, cache hits
  void        on_thermal(ThermalState);
};
```

`GameRef` carries the resolved disc ID and an `fd`-backed file handle — not a path.
Scoped storage means paths are a lie; the `fd` is the truth (§5).

---

## 4. Thread model

| Thread | Created by | Affinity | Priority | Rationale |
|---|---|---|---|---|
| PPU (1–2) | core | prime core | high | Instruction throughput is latency-critical; SMT pairs share it |
| SPU (6) | core | performance cluster | high | The contention point; see §4.1 |
| RSX submit | core | performance core | normal | Must never block the PPU |
| Audio | platform | efficiency core | urgent-ish | AAudio low-latency, 48 kHz, own ring buffer |
| Governor | platform | efficiency core | low | 4 Hz sampling, < 0.5% CPU |
| Watchdog | platform | efficiency core | low | Heartbeat per emulation thread |
| UI | Android | — | — | Never touches the facade on the frame path |

Affinity is set with `sched_setaffinity` on our own threads (permitted) and
augmented with `PerformanceHintManager` sessions so the platform scheduler knows
these threads are latency-critical rather than background work.

### §4.1 SPU scheduling — the central problem

Six SPEs, four performance cores. The naive mapping oversubscribes by 1.5× and the
result is that *every* SPE runs slower than the game expects, which manifests as
audio crackle and slow-motion physics rather than a clean frame drop.

Three stages, increasing in ambition:

1. **Yield on spin.** Detect SPE busy-wait loops (waiting on a channel/mailbox) and
   deschedule instead of burning. This is the pattern that produced a large share of
   RPCS3's Arm64 gain; we inherit it and must not regress it.
2. **Group on DMA block.** An SPE blocked on an MFC transfer holds no useful state
   beyond its local store. Park it and lend the core to the PPU.
3. **Cooperative scheduler (M5 R&D).** A single thread interleaving N parked SPEs
   with a shared code cache, trading per-SPE throughput for reduced context
   switching. Only if (1) and (2) do not close the gap on the T1 corpus.

**Measurement before code:** M0 must produce, on a 4-performance-core device, the
per-frame distribution of time each SPE spends runnable vs. blocked. Without that
number stages 2 and 3 are speculation.

---

## 5. Storage

PS3 disc images are 5–50 GB. Copying them into app-private storage is unacceptable,
and on many devices impossible.

- The user grants a folder via **SAF** (`ACTION_OPEN_DOCUMENT_TREE`), we take a
  persisted URI permission.
- Each image is opened to a `ParcelFileDescriptor`, and the `fd` is handed to the
  core, which does `fdopen` + seek/read. **No path strings, no copies.**
- PKG/RAP handling mirrors the existing user workflow (firmware `exdata`), because
  users already know it and fighting it buys nothing.
- Folder-format titles (`PS3_GAME/`) need directory enumeration, which SAF does not
  do efficiently; [verify:M1] whether `DocumentsContract` traversal is fast enough
  or whether folder titles require a metadata index built on first import.

---

## 6. Governor

A small, boring state machine. Boring is the point: a clever governor that oscillates
is worse than a fixed setting.

```
        ┌────────┐  p99 > target for 2s   ┌─────────┐
        │ NORMAL │───────────────────────►│  THROTTLING │
        │ 100%   │◄───────────────────────│  85% → 70%  │
        └────────┘  p99 < 90% of target   └─────────┘
             │        for 20s (hysteresis)
             │ thermal headroom < 2s
             ▼
        ┌────────┐
        │ SAVING │  drop scale to floor, notify user once, never below 60%
        └────────┘
```

- **Hysteresis everywhere.** 2 s down, 20 s up. Asymmetric on purpose: dropping is
  cheap, thrashing is not.
- **Never changes game-affecting config.** Resolution and shader work only. Emulated
  clocks are off-limits because they change game logic (a game that runs its
  physics off the SPU clock will behave differently, not merely slower).
- **One notification, not a stream.** The user is told once that the device is
  thermal-limited, in plain language, with the option to cap at 30 fps.

---

## 7. Profile schema (draft)

Data, not code. Validated at load; an unknown key is a hard failure in CI.

```json
{
  "schema": 1,
  "title_id": "BLUS30109",
  "title": "Demon's Souls",
  "profile_version": 7,
  "settings": {
    "spu.threads": 6,
    "spu.loop_detection": true,
    "rsx.resolution_scale": 0.85,
    "rsx.write_color_buffers": false,
    "ppu.decoder": "llvm",
    "audio.buffer_ms": 32
  },
  "verdicts": {
    "soc:snapdragon-8-gen-2": { "state": "playable", "fps": 30, "evidence": "bench:2026-11-xx" },
    "soc:snapdragon-8-elite": { "state": "playable", "fps": 45, "evidence": "bench:2026-11-xx" }
  },
  "signature": "ed25519:…"
}
```

`settings` keys are **not hand-written**. `tools/gen_profile_schema.py` extracts the
core's real config registry and emits the allowed key set, so a profile that names a
setting the core no longer has fails in CI instead of silently doing nothing —

> **Trap, recorded in advance:** a settings key that no longer exists is the most
> expensive kind of bug in this product, because it looks like "the emulator is slow"
> and not like "the config was ignored". This is why the schema is generated.

---

## 8. Build

- **Gradle + CMake**, `arm64-v8a` only for v1. `x86_64` exists only as a desktop/emulator
  test target, never shipped — a phone does not need it and it doubles build time.
- **NDK r28, clang 20, C++20.** Runtime baseline `armv8.2-a+dotprod+fp16`; optional
  paths dispatched at runtime rather than baked into a per-SoC ABI [verify:M0 which
  dispatch points pay].
- **minSdk 29** (Android 10): Vulkan, AAudio, ADPF, scoped storage — all present and
  stable. Going lower buys users who cannot run this anyway.
- **APK size:** the incumbents ship ~120 MB. We do not chase a smaller number; native
  debug symbols are stripped and uploaded separately for crash triage.
- **Release job** (M6): build AAB + signed APK, emit the GPL source tarball, publish
  both. The tarball step is in the same job because a licence obligation that depends
  on a human remembering is a licence violation on a schedule.

---

## 9. Testing

| Layer | What | How |
|---|---|---|
| `platform/` | governor state machine, profile validation, fd storage | Host-side C++ unit tests, no device |
| `app/` | profile store, verdict rendering, OTA fail-closed | JVM unit tests + Compose UI tests |
| Profile schema | every shipped profile validates against the generated registry | CI, blocking |
| `core/` | upstream's own test suite survives our patches | CI, blocking |
| Emulation correctness | golden-frame comparison on T1 corpus (fixed input trace → frame hash) | Manual, opt-in, physical device |
| Performance | 30-minute sustained harness (§12 of PLAN) | Manual, opt-in, physical device |

**Never in CI:** anything needing a physical device, a GPU driver, or a game image.
`PROJECT-STANDARD.md` §4.5, and the practical reason: a CI runner cannot produce a
thermal number that means anything.

---

## 10. Failure modes we design for, not around

| Failure | Design response |
|---|---|
| RSX command FIFO desync | Recover the FIFO and continue with a rendered warning, rather than segfaulting — the pattern the incumbents' changelogs show they had to retrofit |
| Thermal runaway | Governor floors resolution and notifies; never silently drops the target |
| Process death mid-session | Background saves flushed on a timer; on restart, offer resume from last checkpoint |
| Stale compile cache after core update | Cache key includes the core build hash; mismatch = discard, never reuse |
| OOM on 8 GB device | Memory ceiling per device class; refuse the title with a reason instead of dying mid-level |
| Audio underrun | Report it in the stats; it is a governor input, not just a glitch |
