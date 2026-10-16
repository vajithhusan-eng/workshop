# CleanTube — project instructions

Android-first **Flutter ad-blocker** built on three independent engines plus an
OTA rule system:

1. **Ad-Free Browser** — Android WebView shell with a blocking engine.
2. **Native YouTube client** — bespoke InnerTube client, no WebView in the
   playback path.
3. **System-wide DNS sinkhole** — own Kotlin `VpnService`. **F-Droid build only**;
   the Play policy forbids it.

Plus **Rule Kits** — Ed25519-signed JSON filter bundles shipped OTA, so rule fixes
do not need a store release.

## The premise — read this before touching the player

You do not need to block YouTube ads. You need to **not ask for them**. The WEB
InnerTube client makes a separate player-family request carrying
`adPlaybackContext`; a client that never makes that request never receives ads.

Consequences that are structural, not tunable:

- **SSAI stitches ads into the stream server-side.** Some ads survive even a correct
  client. This is an accepted residual defect, not a bug to chase.
- **`addDocumentStartJavaScript` injects into the ISOLATED world** — a different JS
  heap. Overriding `window.fetch` there does nothing. This is the trap that costs
  a week.
- **`ANDROID_VR` may eliminate PO tokens entirely**, but Google can restrict any
  InnerTube client at any time (NewPipe has lost `ANDROID`, `IOS`, `TVHTML5`).
  Therefore **remotely switchable client config is a day-one non-negotiable.**
- Feature-detect `JS_INJECTION_IN_FRAME_AND_WORLD`. Never hardcode it.

## Authority

`PLAN.md` (68 KB, research-verified) is the sole plan of record. There is no other
design doc. `STATE.md` is derived — regenerate it via the `project-orientation` skill.

## Scope

**In:** fresh project at `projects/cleantube/`; Flutter, Android-first (iOS deferred
to Tier-3 U15); ad blocking on the web, in our player, and build-dependently in other
apps; YouTube as the marquee feature; blocking browser shell; Play Store as the
distribution target; OTA rule kits.

**Out — do not build these:**

- Root / LSPosed / Shizuku hooks. Play forbids it.
- TLS/SNI interception.
- Byte-range ad stripping from DASH/googlevideo — **impossible**, ad and content
  share hosts.
- `$replace` / scriptlet / regex rules — arbitrary code execution from an OTA source.
- Account login / Google API subscription sync — privacy red line.
- Engine 3 (VPN) in the Play build.
- CSS/DOM hiding as a YouTube strategy.
- Strategy A′ (WebView + main-world JSON pruning) as the primary path —
  **fallback only**; Strategy B (native InnerTube) is the primary path.
- PO-Token/BotGuard subsystem — deferred; `android_vr` may delete it entirely.
- SABR/UMP demuxer — "the entire project by itself".
- DRM circumvention — not needed, standard YouTube DASH carries no Widevine.

## Licensing — hard constraint on how you may write this

- **yt-dlp** (Unlicense): port freely. *The single most valuable artifact available.*
- NewPipe/NewPipeExtractor, HaGeZi, uBO engine, AdGuard Content Blocker (GPL-3.0):
  **read, do not copy.**

This is why the InnerTube client must be a **reimplementation, not a port** — already
budgeted in M3. Decide closed-source vs GPL **before M3 starts**; it changes the
implementation.

## Milestones (`PLAN.md` §5)

| # | Name | Duration | Notes |
|---|---|---|---|
| **M0** | Feasibility spike | 4–5 days | **GATE — "can kill the project. Do it first, do not skip."** |
| M1 | Rule Engine + test suite | 1 week | uBO-subset parser, drift, signed Rule Kit fetch/verify/atomic swap/fail-closed, 100% parser unit tests |
| M2 | Ad-Free Browser | 2 weeks | shippable #1, Play-safe |
| M3 | YouTube Client | 2–3 weeks | Strategy B fully wired; **highest-risk deliverable** |
| M4 | VPN Filter | 2 weeks | **F-Droid build only** |
| M5 | Release hardening | 1.5 weeks | Play policy pass, closed beta ~100 users |

~11 weeks to closed beta, contingent on M0 passing.

## Blocking — do not start implementation without these

1. **Distribution decision (`PLAN.md` §9.1).** Play-only / F-Droid-only / dual.
   Blocks M4 entirely and changes product identity. It is question one.
2. **Verified Play developer account + D-U-N-S number.** Cannot be automated.
   §2.5b states Android developer verification enforces **30 September 2026** in
   BR/ID/SG/TH, global 2027 — **that date has now passed**, so Play compliance is
   non-negotiable and F-Droid is no longer a viable business plan.
3. **Rule Kit CDN/domain + signing-key custody.** Needs a host, an Ed25519 key, and
   a pinned public key in the APK before any OTA work.
4. **Legal counsel** (R8, R15) before public launch, EU market specifically.
5. **M0 must pass first.** If PO-token minting is impossible *and* Strategy A is
   punished, the correct response is to **stop and re-scope**, not to build 11 weeks
   of something that does not work.

## Known contradictions inside `PLAN.md` — verify before trusting a section

- **§10 is stale.** It frames M0 around "can a WebView play YouTube" and "Strategy A",
  but §3.2 promotes Strategy B to primary and marks A′ fallback-only. §10's M0
  questions also ask about `webview_flutter` isolated-world injection (§3.1 already
  proved that is useless) and PO-token minting (since deferred).
- **§3.4 contradicts §3.3/§4/§5 on blocklist storage.** §3.4 mandates a sorted
  memory-mapped blob; §3.3 and §4 **cut** that in favour of Room +
  `hosts_lists`/`host_entries` + `LruCache(4096)`. §3.4 is stale.
- **"Five findings" heading lists seven** (§0). §5 M0 defines 4 questions; §10 says
  "four or five days for three questions".
- **§9 Q6 cites R17** where the intended risk is **R22**. **§9 Q5 cites U9**, which
  is deleted — should be U10.
- **§7 says 24 upgrades; the tables run U1–U25.**
- **U23 sits in Tier 4 but its own text says "Ship-blocking, not Tier 4".**
- **§3.1 still offers `inappwebview` `contentWorld` as an option**, but §4 has
  already committed to a custom Kotlin platform view.

## Open questions (`PLAN.md` §9)

1. ⛔ Distribution lane (above — blocks M4).
2. Legal review before public launch, or closed beta first.
3. Name. `CleanTube` over-emphasises YouTube; consider trademark exposure before
   branding around it. Alternatives floated: `AdShield`, `NullTube`, `Sieve`.
4. Rule Kit CDN/domain — or GitHub Releases for v1.
5. Community backend — ship without, or budget a server early?
6. Is the browser in scope for v1? ~2 of ~11 weeks. Plan recommends **yes**: without
   it the app has no durable value if YouTube breaks.

## Current state

**Zero code.** `projects/cleantube/` contains only `PLAN.md` and an empty `docs/`.
The four docs named in §8 (`architecture.md`, `store-policy-notes.md`,
`distribution-lanes.md`, `adblock-research.md`) do not exist. Nothing in git beyond
the plan commit.

## Tech stack (§4)

Flutter 3.47 / Dart 3.13 · `riverpod` · `go_router` · `drift` · `room-runtime` 2.6.1
for the blocklist hot path (**decide vs drift in M1** — `sqlite3_flutter_libs` 0.6.0+
is EOL and `drift_dev ≥2.23.0` pins `sqlite3 ^2.4.6`, conflicting with `sqlite3` 3.x)
· custom Kotlin platform view + `androidx.webkit` ≥1.16, minSdk 23 forced ·
`media_kit` 1.2.6 primary, `media3-exoplayer-dash` 1.11.0 alt · own Kotlin
`VpnService` ~600 LOC · `dio` · build variants `play` (engines 1+2) and `fdroid`
(1+2+3) behind one capability flag.

**Verify the Flutter/Dart version claim against the actual toolchain before relying
on it** — `PLAN.md` §4 asserts it is "already in this workspace", and §3.3 notes
`vpn` (xclud) will not resolve on Dart 3.

## Standing constraints

- **Never promise "blocks all ads."** That is HaGeZi's own warning.
- **DoH/QUIC bypass is structural, not a bug** — with no default route, QUIC and DoH
  never enter the TUN. Detect it; do not pretend to stop it.
- **Encrypt browsing history at rest** (SQLCipher / Keystore-wrapped key),
  `allowBackup=false`, incognito never persists. This is the most sensitive store.
- **mmap precondition:** `AssetManager.openFd()` only mmaps *uncompressed* APK
  assets, so it needs `aaptOptions noCompress`. Decide and measure in M1.