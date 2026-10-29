# Changelog

Append-only, newest first. Format: `## <YYYY-MM-DD> — <one-line summary>`.

## 2026-10-29 — Plan of record drafted: hardware floor, four decisions, M0 kill gate

Created the project from `scripts/new_project.py --kind docs --plan` and wrote the
full design. **No code.** `PLAN.md` is `PLAN DRAFT`, not approved.

What the design decided, and why it matters:

- **D1 — build on the GPLv2 RPCS3 lineage, not from scratch.** The Cell has six
  usable SPEs; a from-scratch core is a decade. The differentiated work is the
  mobile layer.
- **D2 — the mobile layer is the product.** Zero-config profiles, a thermal
  governor, a persisted recompile cache. Two of those three appear as *bugs being
  fixed* in the incumbents' own changelogs (`docs/RESEARCH.md` §3), which is the
  market pointing at the gap.
- **D4 — a hardware floor derived from core count**, not from positioning: six
  guest SPEs, two-to-four host performance cores, therefore Snapdragon 8 Gen 2-class
  and up, enforced by Play device filtering.
- **M0 is a 5-day kill gate** with written kill criteria, including "if fewer than 3
  of 5 titles reach gameplay, stop".

Three unverified beliefs are recorded rather than hidden, because the plan leans on
them: the absence of the ASMJIT fast backend on AArch64 (`PLAN.md` §8 and M5 depend
on it), the divergence budget for the Android NDK build, and the 8 Gen 2 core split
behind the hardware floor. All three are `[verify:M0]` in `STATE.md`.

Toolchain note: `scripts/new_project.py --kind docs` leaves unsubstituted markers in
the generated `STATE.md`/`AGENTS.md`/`docs/README.md` (e.g. `Skeleton | @AREA_Plan
only@`, and the convention sentence injected mid-word into other sentences). Every
generated file was rewritten by hand here, so it affected no output — but the next
project created with `--kind docs` will hit it. The script's lower-case marker
aliases (`@status@`, `@convention@`, …) collide with the upper-case ones it writes.
