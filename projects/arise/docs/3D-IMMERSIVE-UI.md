# Arise — 3D, Motion & Immersive UI

> The mandate: Arise's graphics, animation, UI and UX must be **3D** and feel
> like a game — flawless, offline, private. This doc is the engineering answer to
> that: what 3D is actually possible on Flutter/Android in 2026, how far we take
> it, and the rules that stop "3D everywhere" from becoming "janky everywhere".
>
> Read with `UI-UX-HUD.md` (the 2D visual system this extends).

---

## 1. The design thesis — the System is a place

Flat habit apps feel like a spreadsheet. Arise should feel like a **place you
step into**: a dark chamber where the System's windows float in space, a sigil
turns above your status, and a gate waits for you.

Spatial metaphor (fixed, three planes):

| Plane | Depth | Contents |
|---|---|---|
| **World** | far (z −2) | gradient void, drifting particles, distant geometry, the Gate |
| **System** | mid (z 0) | glass panels, windows, quest cards — the readable layer |
| **You** | near (z +1) | the focal hero object (rank sigil / monolith), foreground light |

Depth must **communicate hierarchy**, not decorate it. The System plane is where
the user reads; the world plane sets mood; the near plane gives one focal point.

## 2. The hard constraint — what "3D" means on Flutter today

This is the honest technical lay of the land (researched 2026):

### 2.1 Real 3D: `flutter_scene`
- A realtime 3D engine on **Flutter GPU + Impeller**, shipped as vanilla Flutter
  (no platform views, no forks, no second graphics context). Works on Android.
- glTF/GLB import, PBR materials, animation, instancing, LODs, Gaussian splatting.
- Renders into a `SceneView` widget; **ordinary Flutter widgets can float on
  top** — which is exactly the "3D world + glass System windows" composition we
  want.
- On Flutter 3.47 Impeller is the default renderer on native platforms, so this
  no longer needs `--enable-flutter-gpu` (historically it did).

### 2.2 Real 3D alternative: `flame_3d`
- 3D for the Flame game engine, built on Flutter GPU. **Experimental.** Android
  ✅, but Windows ❌ / Linux ❌ / Web ⚠️, and needs the Flutter GPU flag.
- Use only if `flutter_scene` proves unsuitable; it drags in the Flame runtime.

### 2.3 Pseudo-3D: 2.5D on the 2D canvas
- `vector_math` + `Transform` (matrix4 perspective) + `CustomPainter` for depth,
  parallax, and extruded geometry; `BackdropFilter` for depth-of-field blur.
- **Runs everywhere at 120 fps**, no GPU flags, no experimental dependency.

### 2.4 Rejected
- **Unity / Unreal as a platform view**: one at a time, a second engine, a second
  graphics context, huge APK, not offline-friendly. Rejected outright.

## 3. The decision — layered 3D, not "3D everywhere"

**Default: 2.5D depth. Upgrade: real 3D on the hero moment.** Three capability
tiers, chosen at runtime:

| Tier | When | Rendering |
|---|---|---|
| **A — Immersive** | capable GPU (Impeller, decent SoC), animations enabled | `flutter_scene` hero object + 2.5D panels + particles |
| **B — Depth** | mid devices, or A disabled by the user | 2.5D parallax + perspective panels + blur; no mesh rendering |
| **C — Flat** | high-contrast mode, reduced motion, low-end, or old Android | flat translucent panels, no blur, no parallax, no 3D |

Tier is detected once (Impeller availability + a measured frame-time probe on the
first animation) and is **user-overridable** in Settings. Tier C is a first-class
experience, not a degraded one — it is the accessibility path.

> **Why not full 3D everywhere:** 2026 performance reality — 10k-particle stress
> tests OOM mobile SoCs, overdraw and tessellation dominate cost, blur is
> expensive. A discipline app that stutters on a mid-range phone has failed at
> its one job. "Flawless" beats "maximal".

## 4. The hero moments (where real 3D earns its place)

**Rule: one focal depth moment per screen. If everything floats, nothing floats.**

| Moment | Tier A | Tier B/C |
|---|---|---|
| **Awakening** (first run) | full-screen gate opening; camera dolly through | panel reveal + depth slide |
| **Status screen** | slowly rotating **rank sigil** (crystalline polyhedron, PBR metal) | 2.5D rotating sigil (skewed layers) |
| **Level up** | sigil fractures → reforms brighter; light burst | scale + glow + particles |
| **Rank up** | sigil morphs to the new rank geometry; material shifts | 2.5D morph + color shift |
| **Dungeon gate** (v4) | real 3D gate/monolith, depth-lit | 2.5D doorway |
| **Shadow army** (v10) | instanced 3D silhouettes | formation of 2.5D icons |

Everything else — quest cards, lists, settings — is **Tier B 2.5D at most**.

## 5. Depth system (the 2.5D rules that make it feel 3D)

1. **Perspective on panels**: a subtle `Matrix4` perspective tilt (±3–5°) that
   responds to touch/scroll. Reverts to flat on Tier C.
2. **Parallax between planes**: world plane moves ~0.2×, System plane ~0.5×,
   near plane ~1.0× of the input. **Never full-screen parallax** (NN/g: causes
   disorientation, vestibular discomfort, missed navigation) — cap total travel
   at a few px.
3. **Depth-of-field**: far plane gets a light blur; near plane sharper. One blur
   element per screen (see `UI-UX-HUD.md` §7).
4. **Lighting**: one consistent light direction across the whole app — top-left
   key light. Every shadow and specular highlight agrees with it.
5. **Z-translation on interaction**: ~4 px hover/press translate, 150 ms
   ease-out. Beyond ~8 px reads as a toy.
6. **Noise + gradient borders + soft shadow** on glass (the 2026 glassmorphism
   recipe) to sell material without visual noise.
7. **Occlusion cues**: a near element may cast a soft shadow onto the System
   plane — the cheapest, most convincing depth cue.

## 6. Motion system (game-feel, not decoration)

| Moment | Motion | Budget |
|---|---|---|
| App open | world plane fades in, System window rises 12 px | 320 ms |
| Panel enter | depth slide (z) + fade + scanline sweep | 220–300 ms |
| Quest complete | card press-in, XP surge, sigil pulse, light haptic | 200 + 300 ms |
| Level up | sigil spin-up → fracture → reform; overlay title | ~1.2 s, skippable |
| Rank up | material morph + color bloom + sting | ~1.4 s, skippable |
| Milestone | silhouette → reveal unfurl | 400 ms |
| Screen transition | world plane continuous (parallax), System plane swaps | 250 ms |

**Rules**
- Animate **only** `opacity` and `transform`. Never blur radius, never layout.
- Everything is **skippable** and **cancellable** (WCAG 2.2.2).
- Reduced motion → fades only, no parallax, no particles, no camera moves.
- Haptics: light on complete, medium+pattern on level/rank.
- Sound: bundled, muted by default, every cue has a visual twin.

## 7. Performance budget

| Budget | Target |
|---|---|
| Frame time | ≤ 8.3 ms (120 Hz) on Tier A; ≤ 16.6 ms (60 Hz) on Tier B |
| Real 3D objects on screen | **1** (hero only) |
| Blur elements | **1** focal per screen |
| Particles | ≤ 200, GPU-instanced, capped |
| Shadow maps | **off** on mobile (bake lighting into materials) |
| Shader count | small, precompiled via `impellerc`, no runtime compile |
| First-frame jank | none — Impeller builds pipeline state upfront |
| APK growth from 3D | ≤ ~8 MB of bundled glTF/GLB |

Fallback triggers: if frame time exceeds budget for 2 s, **auto-drop one tier**
and tell the user once ("The System dims to keep things smooth").

## 8. Offline & privacy (non-negotiable)

- **All 3D assets bundled** — glTF/GLB, textures, shaders, fonts. **No CDN, no
  runtime fetch, no download-on-first-run.** The app works in airplane mode from
  install.
- **No telemetry, no crash upload, no analytics.** Performance tiering is decided
  on-device and never reported.
- **Personal & private:** single user, local DB, no account, no cloud. The
  System's data never leaves the phone. Export/import is a user-owned file.

## 9. Accessibility (3D is where this usually breaks)

| Requirement | Rule |
|---|---|
| **Reduced motion** | OS setting + in-app override → Tier C motion (fades only). No parallax, no camera moves, no particles. |
| **Vestibular safety** | cap parallax travel; no full-screen scale/zoom; no rapid depth oscillation. |
| **Contrast** | 3D lighting must not push text below 4.5:1; text sits on an opaque-enough glass plate, never directly on a moving 3D scene. |
| **Semantics** | 3D objects are decorative unless they carry state; the rank sigil exposes "Rank C" as a semantics label. |
| **Skippable** | every cinematic has a visible skip control after the first 1 s. |
| **Tier C parity** | no feature, data, or flow is available only in 3D. |

## 10. Implementation plan

| Concern | Choice |
|---|---|
| Real 3D | `flutter_scene` (Flutter GPU/Impeller) behind a feature flag + tier gate |
| 2.5D | `vector_math` `Matrix4` perspective + `Transform` + `CustomPainter` |
| Motion | `flutter_animate`; `AnimationController` for camera/sigil |
| Blur/DoF | `BackdropFilter` + `ImageFilter.blur` (single focal element) |
| Assets | bundled glTF/GLB (KTX2 textures), SVG, `.ttf`; total 3D budget ≤ 8 MB |
| Tier detection | Impeller check + first-animation frame probe + Settings override |
| Shaders | GLSL → SPIR-V via `impellerc` at build; no runtime compilation |

### Risks
- `flutter_scene` is young — pin the version, keep Tier B as the guaranteed path,
  and never let a 3D failure blank a screen (wrap in a fallback).
- Android device fragmentation — the frame probe is the safety net.
- APK size — audit the glTF budget each release.

---

## Sources

- `flutter_scene` / fscene.dev, Brandon DeRosier (Flutter 3.47 + Flutter GPU, Aug 2026).
- Flutter docs: Impeller, custom shaders (`FragmentProgram`), Flutter GPU, `flame_3d`.
- Flutter 2026 performance guidance; Mobile SoC overdraw/tessellation limits.
- NN/g, *What Parallax Lacks* (usability/vestibular risk).
- 2026 depth/spatial-UI and dark-glassmorphism design guidance.
- WCAG 2.2 SC 2.2.2, 2.3.1, 2.3.3.
