# Eightfold — project instructions

An Android-first PlayStation 3 emulator built on the GPLv2 RPCS3 lineage, where the
product is the **mobile layer** — thermal behaviour, zero-config per-game profiles,
cold-start compile cache, honest compatibility data — not the emulation core.

## Authority

- `PLAN.md` — **Status: PLAN DRAFT, not approved.** Binding only after the user says
  "build". Read §0 (four decisions) and §1 (hardware) before proposing anything.
- `docs/RESEARCH.md` — authoritative on evidence. A performance claim with no source
  there and no committed benchmark behind it does not exist.
- `docs/ARCHITECTURE.md` — how. Subordinate to `PLAN.md`; if it contradicts the plan,
  the plan wins and the contradiction is a bug to record.
- `STATE.md` — derived build status. Never hand-edit the pin.

## Identity

Emulating the Cell Broadband Engine is the hardest consumer-facing emulation problem
shipped. This project's whole editorial position is **honesty about limits**: six
usable SPEs on phones with two to four performance cores is a physical constraint,
not a tuning problem, and the app says so in the store listing and on the game card.

## Scope

**In:** Android (arm64-v8a), Vulkan, Snapdragon 8 Gen 2-class and above; per-game
profile system; thermal governor; recompiler cache; compatibility measurement.

**Out — do not build, and do not "just add" later without reopening `PLAN.md` §14:**

- **iOS.** A JIT emulator cannot ship on iOS as a third-party app. Not "later" — out.
- **Writing the emulation core.** D1. We vendor and patch it; we do not replace it.
- **Flutter or any UI toolkit in the render path.** D5 — the game surface is a
  zero-copy `SurfaceView`/Vulkan swapchain. Compose for menus only.
- **Online play, PSN, RPCN, PS1-classics mode, PS4/Switch/Wii U emulation.** Each is
  a separate compatibility surface.
- **Bundled firmware, keys, or games.** D9 and §10.
- **"Runs everything" claims, peak-fps marketing, first-minute benchmarks.** D8.
- **Bundled custom drivers.** Point the user at Turnip; do not redistribute blobs.

## Locked decisions (`PLAN.md` §3)

Changing any of these is a plan amendment, not a refactor.

| # | Decision |
|---|---|
| **D1** | Fork the GPLv2 RPCS3 lineage as a vendored subtree. Divergence budget: ≤ 2% of upstream files, ≤ 20 carried patches. |
| **D2** | The mobile layer is the product. |
| **D3** | GPLv2; complete source published with every release, by an automated job. |
| **D4** | One hardware floor (Snapdragon 8 Gen 2-class, 12 GB), enforced at install time. |
| **D5** | Kotlin + Compose UI; C++17/20 platform layer; no Flutter in the render path. |
| **D6** | Android only. iOS out permanently. |
| **D7** | No networking, no PS1 classics, in v1. |
| **D8** | Every performance claim is a named-device measurement from the §12 harness. |
| **D9** | No firmware, no keys, no games. User-supplied, always. |

## Conventions

- **`core/` is not ours.** Patch it in `patches/NNNN-slug.patch`, one reason per
  patch, each with an upstream status. Never reformat vendored code — a whitespace
  diff inside `core/` is a rebase conflict forever.
- **The core never sees an Android type.** No `ANativeWindow`, no `JNIEnv`, no
  `Surface` above the `platform/` boundary.
- **`minSdk 29`, `arm64-v8a` only.** Do not add ABIs "for completeness"; they
  double build time and ship to nobody.
- **Emulated clocks are off-limits to the governor.** Resolution and shader work
  only — changing guest clock speed changes game logic, not just framerate.
- **Profile settings keys are generated, never hand-written** (`tools/gen_profile_schema.py`).
  A stale key looks like "the emulator is slow", which is the most expensive bug
  class in this product.
- **Fail closed.** A bad profile signature falls back to built-in defaults.
- **Record contradictions** between `PLAN.md`, this file and the code rather than
  working around them silently.

## Commands

```bash
# nothing to run yet — no source tree exists
make projects-check        # from the repo root: document set is well-formed
make docs-check            # from the repo root: STATE.md pin resolves
```

When code exists, the entry points will be `./gradlew :app:assembleDebug`,
`./gradlew :app:testDebugUnitTest`, and `bench/run.sh <title> <minutes>` on a
physical device. **None of these exist yet — do not cite them as if they do.**

## Known traps

1. **A "faster" build that only moves the first-minute number.** The failure mode of
   this whole project is optimising peak fps on a cold device. The gate is a
   30-minute sustained run, always.
2. **Treating the incumbents as static.** aPS3e and ARMSX3 ship frequently and are
   patching exactly the things this plan calls differentiators. Re-read
   `docs/RESEARCH.md` §3 before claiming a gap.
3. **Assuming an x86 fast-recompiler path exists on Arm.** The fast backend is an x86
   assembler. `[verify:M0]` — and if it is confirmed, §8 and M5 are load-bearing.
4. **Confusing "boots" with "playable".** A title that reaches a menu has proven
   almost nothing. Playable means: held 30 fps for 30 minutes with audio intact.
5. **A settings key that the core silently ignores.** It renders as "slow", not as
   "misconfigured". Hence the generated schema.
6. **Committing an ISO, a firmware PUP, or a decryption key.** Any of these turns the
   project into a legal problem in one commit. Never, in any fixture, ever.

## Standing constraints

- **Never claim more than the evidence supports.** `STATE.md` records commands that
  were run, not files that exist.
- **Claim a file before editing it** — `python3 scripts/devsup.py claim <path> --note "why"`.
  A refused claim means coordinate, not overwrite.
- **Never push.** `git commit` stays local; publishing needs `ALLOW_PUSH=1` and the
  user's explicit agreement in the session.
- **Physical-device tests are manual and opt-in.** No emulator benchmarks in CI.
- **Leave no stub standing in for finished work** without saying so in `STATE.md`.
