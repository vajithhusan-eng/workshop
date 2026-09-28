# CleanTube — Master Plan

**Ad-Free YouTube + Ad-Blocking Browser · Flutter · Android-first Mobile App**
Status: PLAN v2 (research-verified) · Date: 2026-09-28 · Supersedes v1 draft

---

## 0. TL;DR

A Flutter Android app that blocks ads, with YouTube as the headline target. Two
independent blocking engines, because no single mechanism can do the whole job:

| # | Engine | What it kills | Where it runs | Play Store? |
|---|---|---|---|---|
| 1 | **Ad-Free Browser** (WebView + blocking engine) | Ads on every website, **including YouTube pre-rolls** | Inside our browser | ✅ Yes |
| 2 | **YouTube Surface** (optimised WebView player) | YouTube ads | Inside our player | ⚠️ Risky |
| 3 | **System VPN Filter** (`VpnService` DNS sinkhole) | Ads in *other* apps (Instagram, games) | Whole device | ❌ **Prohibited** |

Plus **Rule Kits**: blocking rules ship as signed JSON and update **without a store
release**, so a YouTube redesign is answered in hours, not weeks.

### Three findings that changed this plan

This draft exists because the first draft was wrong in three places. All three were
found by reading source and the live Play policy, not by guessing.

**1. Google Play explicitly prohibits system-wide ad blocking.**
The current *Device and Network Abuse* policy lists, as a common violation:
*"Apps that block or interfere with another app displaying ads."* AdAway, AdGuard,
AdBlock Plus and Blokada 5 were all **removed from Play** for this. The v1 draft claimed
they were precedents. They were the opposite — evidence. **Engine 3 cannot ship on Play.**
See §2.5 — this is now the central open decision.

**2. The ad-break "heartbeat" trick was never a real design.**
v1 claimed the fix for YouTube's ad-blocker punishment was forwarding
`ad_break/heartbeat` while hiding the ad. Reading NewPipeExtractor source: NewPipe
**does not do this at all.** It avoids punishment a different way — it never requests ad
data, and it uses a client identity YouTube does not punish (visionOS, not ANDROID/WEB).
A WebView loading real YouTube *is* the WEB client, so it has no such escape hatch. The
trick is now marked **unverified and legally risky**, not a headline feature.

**3. PO tokens were entirely missing.**
YouTube requires BotGuard-backed device-integrity tokens for playback on major clients.
These need an in-app JavaScript engine with a real DOM, plus a token-mining subsystem.
This is weeks of work, and it is the single biggest unknown in the project. See §3.6.

**M0 exists to settle all three before we build anything.** A 3–4 day spike that can
legitimately kill the project.

---

## 1. Your request → requirements

| # | What you asked for | Requirement |
|---|---|---|
| 1 | "new project" | Fresh project in this repo at `projects/cleantube/` |
| 2 | "mobile app" | Flutter, Android-first (v1), iOS deferred |
| 3 | "ad blocker" | Ads blocked on the web, in our player, and (build-dependent) in other apps |
| 4 | "mainly for youtube" | YouTube is the marquee feature, not a side case |
| 5 | "create the plan" | This document: architecture, stack, milestones, risks |
| 6 | "and your upgrade plans" | §7 — 24 upgrades beyond the original ask |
| 7 | "try the new way" | Modern techniques: WebKit isolated worlds, DASH/InnerTube, OTA rule kits |
| 8 | "or the browser extension for samsung browser for android" | An ad-blocking **browser shell** on Android WebView — a Samsung Internet alternative that blocks by default |
| 9 | Play Store (confirmed) | No root, no Shizuku, no LSPosed. **Now conflicts with requirement 3 — see §2.5 and question 1 in §9** |

---

## 2. The hard truth (read this before building)

Accuracy over optimism. These are verified constraints, not guesses.

### 2.1 What is IMPOSSIBLE on a non-rooted phone

- **We cannot reduce ads inside the official YouTube app.** Not with a VPN, not with DNS
  blocking, not with a filter list. Android gives an app zero visibility into other apps'
  traffic or UI. Anyone claiming otherwise is selling a root module.
- **The official YouTube app stays the official YouTube app.** CleanTube is a *replacement
  player*, not a patch.

### 2.2 Why DNS/host blocking alone cannot stop YouTube pre-rolls

YouTube serves ad media and content media from the **same hosts** (`*.googlevideo.com`,
same `videoplayback` endpoint, often the same byte-range stream). Killing the host kills
the video. This is why AdAway/AdGuard-style apps never removed YouTube pre-rolls — not a
filter-list gap, structurally impossible at the DNS layer.

### 2.3 YouTube actively punishes ad-stripping clients

- **SSAI (Server-Side Ad Insertion).** YouTube stitches some ads *into the video stream*
  server-side, before they reach the device. Confirmed in uBlock's own tracker: *"YT
  already inserts ads through SSAI, nothing new."* For those, the ad *is* the video —
  unremovable without destroying the stream. Low-rate and selectively served, so an
  accepted residual defect, not a blocker.
- **YouTube's anti-adblock programme** (updated 2025-06-03): "Ad blockers violate YouTube
  Terms of Service" modal, forced buffering, and **fake ad breaks inserted mid-sentence**.
  What is known and unknown about defeating this is in §3.2.
- **It is a moving target.** Even uBlock Origin breaks on YouTube changes and needs a
  24–72h patch cycle. This is not a build-once product; it is a subscription to a
  maintenance burden. Rule Kit OTA updates (§3.4) exist solely to make that survivable.

### 2.4 What is genuinely reliable

- WebView-based content blocking (the Brave-in-a-WebView model) — proven, no extensions
  required, and the only reliable way to de-ad YouTube on mobile.
- DNS sinkholing in a local VPN for cross-app banner/analytics ads — proven *as a
  technique*, and shipped that way by AdAway, AdGuard and Blokada 5 — all **off Play**.
- Cosmetic (element-hiding) rules for display ads — proven.

### 2.5 ⚠️ The Play Store problem — the central decision

**Verified against the live policy page** (Device and Network Abuse,
`support.google.com/googleplay/android-developer/answer/9888379`).

> **Common violations include:** *"Apps that block or interfere with another app
> displaying ads."*
> **Don't:** *"Don't block or interfere with another app displaying ads."*

The same policy prohibits *"Apps that access or use a service or API in a manner that
violates its terms of service."* It restricts proxying to third parties to cases where it
is the app's *"primary, user-facing core purpose"*, and flags WebViews exposing a JS
interface to untrusted web content.

**Every precedent the v1 draft cited turns out to be counter-evidence:**

| Cited as precedent | Reality |
|---|---|
| **AdAway** | Removed from Play (2013, §4.4 Developer Distribution Agreement). Own site confirms: F-Droid only. |
| **AdGuard** (full) | Removed in 2014. Only the Samsung/Chrome *Content Blocker* and *AdGuard VPN* remain on Play. |
| **AdBlock Plus** | Removed — "interference with another service or product in an unauthorized manner". |
| **Blokada 5** | The local-VPN ad blocker was the version affected. Vendor shipped Blokada 6 (cloud filtering) to comply. |
| **1Blocker** | iOS/App Store only — irrelevant to Play review. |
| **Brave, DuckDuckGo** | On Play — but as general browsers that block ads/trackers *only inside their own browser*. No cross-app VPN, no YouTube surface. They are legal *because* they touch nothing outside their own app. |

**Conclusion: the distinction that matters is scope.** Blocking ads inside a browser you
own is how Brave stays on Play. Touching *other apps'* ad monetisation is what got four
incumbents removed.

So there is no single build that satisfies "Play Store" and "system-wide ad blocker"
at once. There are three coherent options, and **this is a decision for you, not for me**:

| | **Option A — Play-only** | **Option B — F-Droid only** | **Option C — Dual build** |
|---|---|---|---|
| Store | Google Play ✅ | F-Droid / GitHub | Both |
| Engine 1 Browser | ✅ | ✅ | ✅ |
| Engine 2 YouTube player | ✅ | ✅ | ✅ |
| Engine 3 System VPN | ❌ omitted | ✅ | ✅ (F-Droid build only) |
| Reachable users | Large | Small, technical, self-installing | Large + technical |
| Update speed for rule fixes | Play review (fast for data-only) | Immediate | Immediate for F-Droid users |
| YouTube-surface risk | High — may still trip the ToS clause | Lower (no store gatekeeper) | Split |
| Revenue model | Play is the only sane one | Donations | Play + donations |

**Recommendation: Option C**, because the two builds share ~85% of the code and differ
behind one capability flag. But Option A is perfectly viable and much simpler, and it is
the only one that doesn't depend on the YouTube surface surviving review.

**One more Play tripwire:** a "WebView-only YouTube player" with thin native functionality
risks **Minimum Functionality / webview spam** rejection. Shipping Engine 1 as a
genuinely full browser is what makes a YouTube surface acceptable as part of a real app.
De-branding from YouTube's chrome helps.

---

## 3. Architecture

### 3.0 Layer map

```
┌──────────────────────────────────────────────────────────────┐
│  Flutter UI (Dart)   riverpod · go_router · Material 3      │
│  Browser · Player · VPN Dashboard · Rules Editor · Stats     │
└───────────────┬──────────────────────────────────────────────┘
                │  MethodChannel / EventChannel
┌───────────────▼──────────────────────────────────────────────┐
│  Dart — Blocking Core                                        │
│  RuleEngine · FilterParser (uBO subset) · RuleStore(drift)   │
│  Stats · UpdateClient (signed Rule Kits)                     │
└───────────────┬──────────────────────────────────────────────┘
                │
┌───────────────▼──────────────────────────────────────────────┐
│  Platform Layer                                             │
│  ┌─────────────────────┐        ┌──────────────────────────┐  │
│  │ Kotlin: WebViewHost │        │ Kotlin: DnsVpnService    │  │
│  │ WebViewClientCompat │        │  ⚠ F-Droid build only    │  │
│  │ addDocumentStartJS  │        │  ForegroundService        │  │
│  │ addWebMessageListen │        │  UDP DNS sinkhole        │  │
│  └─────────────────────┘        │  BlockingSet (mmap)      │  │
│                                 └──────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### 3.1 Engine 1 — Ad-Free Browser (`WebViewHost`)

The "browser extension for Android" you asked for. A full browser shell where blocking
is native, not bolted on. **This is the engine that makes the whole product viable on
Play**, because it blocks ads strictly inside an app we own.

**Network blocking** — `WebViewClientCompat.shouldInterceptRequest(WebView, WebResourceRequest)`
* Return a synthetic `WebResourceResponse` (HTTP 204) for blocked URLs → the request
  never reaches the network.
  * ⚠️ Hard limits: this hook **cannot read POST bodies**. AndroidX WebKit 1.14 added
    cookie read support here and for Service Workers, but Service Worker interception
    still goes through `ServiceWorkerControllerCompat`, not this hook. Documented,
    accepted, and the DNS layer (Engine 3) is the backstop.
  * **Open question for M0:** `webview_flutter` 4.14.1 may not expose these AndroidX
    WebKit features at all. If not, Engine 1 moves to a custom Kotlin platform view —
    which changes the estimate and is why M0 tests this first.

**Cosmetic blocking** — `WebViewCompat.addDocumentStartJavaScript(WebView, js, allowedOriginRules)`
* Injected *before* any page script runs → no ad flash, no layout thrash.
* Uses **isolated-world** injection (AndroidX WebKit 1.15+) so our JS cannot collide
  with page JS. Requires `androidx.webkit:webkit` ≥ 1.14 → **minSdk 23**.
  `addJavaScriptOnEvent` is still alpha — do not depend on it.
* ⚠️ **YouTube uses a Trusted Types policy** that broke uBlock's own server-side-ad
  filtering on Chromium. Expect our cosmetic layer to be similarly affected, and expect
  to have to work around it. This is a known landmine, not a surprise.

**Bridge** — `WebViewCompat.addWebMessageListener` ↔ `MethodChannel`
* `JS → Dart`: ad element sighted, telemetry, SPA route changes
* `Dart → JS`: inject/update cosmetic rules, toggle blocking without page reload
* ⚠️ **This is an injection sink and must be hardened:** strict origin allowlist, JSON
  schema validation, 4KB message cap, per-origin rate limit, drop-and-log on violation.
  Never expose a bridge method that evaluates strings, reads cookies, or writes files.

**Browser features (v1):** omnibox + search, tabbed + popup, bookmarks, history,
incognito (separate AndroidX WebKit `Profile` — no cookie bleed), downloads, share
sheet, find-in-page, desktop/mobile site toggle, share-to-CleanTube intent.

### 3.2 Engine 2 — YouTube Surface

Two render strategies, selected at runtime by a **health score**.

**Strategy A — WebView Embed (default, high fidelity)**
* Real YouTube player in a `WebView`, desktop UA so we get the full web player (best
  quality ladder, captions, PiP, background audio, playlists).
* Cosmetic rules + a dedicated `youtube-rules` Kit: `.ytp-ad-module`,
  `.ytp-ad-player-overlay`, `.ytp-ad-overlay-slot`, `#masthead-ad`, `#player-ads`,
  `ytd-promoted-*-renderer`, `ytd-display-ad-renderer`, `ytd-in-feed-ad-layout-renderer`.
* **Ad-break heartbeat forwarding — PROMISING BUT UNVERIFIED AND LEGALLY RISKY.**
  We could observe ad start/end and forward the `youtubei/v1/player/ad_break/heartbeat`
  beacon so YouTube's counters increment while the ad stays hidden. **Do not build this
  yet.** (a) NewPipe does not do it; (b) a WebView loading real YouTube *is* the WEB
  client and has no client-switching escape hatch; (c) forging ad-playback telemetry is
  materially worse than ad-blocking under the ToS and reads as invalid ad-activity
  reporting to Google Ads. **Requires counsel sign-off; presumption of removal.**
* **Punishment-UI suppression** (defence in depth, cosmetic only): hiding the "Ad
  blockers violate YouTube Terms of Service" modal and the "Sign in to confirm you're
  not a bot" interstitial. This is display-layer only and is materially less risky
  than the heartbeat, because nothing is being misreported.

**Strategy B — InnerTube API + DASH (lightweight, no WebView)**
What NewPipe actually does, and the harder path:
1. **Mint PO tokens** via Google's BotGuard (§3.6). Non-optional.
2. **Use a non-punished client identity.** Verified in `YoutubeStreamExtractor.java`:
   NewPipe fetches streams through a **visionOS** client against the `gapis` host, while
   the WEB client is demoted to a *metadata-only* call. The source cites
   NewPipe issue **#8713**: the ANDROID client gets a **decoy player response** telling you
   to "watch on the latest version of YouTube" (detected by comparing the returned
   `videoDetails.videoId` to the requested ID), and Piped#2487 documents IP rate-limiting
   producing the same decoy.
3. **Don't request ads at all** — use `$fields` on the player request so no ad data comes
   back. This is why NewPipe never needs to strip anything.
4. **Play the DASH manifest** with `media_kit`. Also carry `visitorData` and a
   per-client `cpn` (contentPlaybackNonce) — a nonce must be unique per client.

* **Pros:** no WebView, much lower battery/memory, real background audio, survives page
  redesigns.
* **Cons:** tokens must be refreshed; client identity is a moving target YouTube rotates;
  the visionOS spoof is obvious; and Strategy B is the part most likely to trip Play's
  "access a service in a manner that violates its terms of service" clause.
* **Do not attempt** driving DASH from `shouldInterceptRequest` to strip ad byte-ranges.
  Ads and content share one stream; range-blocking corrupts the video.

**Health score** — rolling measure of Strategy A vs B (playback start latency, ad-UI
suppression rate, "interruption" modal sightings, decoy-response detection, Player API
error codes). Auto-routes to the healthier strategy and drives the in-app "Blocking
degraded" banner.

### 3.3 Engine 3 — System VPN Filter (`DnsVpnService`) — ⚠️ F-DROID BUILD ONLY

**Not shippable on Play** (§2.5). This engine exists only in the F-Droid/sideload build.

* **Own Kotlin implementation.** Verified on pub.dev: `flutter_vpn_service` (1.1.0,
  published 2024-12-02) and `flutter_vpn` (0.13.0, 2024-09-06) are both ~2 years stale
  and unmaintained. No maintained DNS-sinkhole `VpnService` bridge exists. We write our
  own, and it is non-negotiable.
* **DNS-only tunnel.** `Builder.addAddress(10.0.0.2, 32)` + `addRoute(10.0.0.2, 32)` +
  `addDnsServer(10.0.0.2)`; bind a UDP socket to the virtual DNS IP, answer blocked
  domains with `0.0.0.0`, forward the rest upstream. Chosen over tun2socks: far less
  code, much lower battery, and DNS is what ad blocking actually needs.
* ⚠️ **Private DNS (DoT) can silently defeat this.** Verified in tailscale/tailscale#915:
  if a *custom* Private DNS hostname is set (e.g. `dns.nextdns.io`), enabling the VPN
  **stops all DNS resolution** and Settings shows "couldn't connect". The *Automatic*
  setting is fine. ⇒ **CleanTube must detect a custom Private DNS hostname at VPN start
  and make switching to Automatic a blocking onboarding step**, or the VPN no-ops or
  breaks connectivity with no explanation.
* ⚠️ **IPv6 is a leak path.** A DNS-only IPv4 tunnel leaks on every IPv6-first carrier
  network. Either sinkhole IPv6 too (`fd00::2/128`, `addRoute(::, 0)` scoped to DNS) or
  **block IPv6 explicitly and disclose it**. Shipping neither means a green "protected"
  badge over a half-filter. The U22 self-test must cover IPv6.
* **Upstream disclosure.** Forwarding to 1.1.1.1/9.9.9.9 over plaintext UDP exports the
  user's non-blocked DNS footprint to a third party. Must be disclosed on the consent
  screen, in the privacy policy, and in the Data Safety form. A privacy product cannot
  hide this.
* **Per-app split tunnelling** — `Builder.addDisallowedApplication()`, with a persistent
  warning that excluded apps are unfiltered, and excluded apps dropped from "ads blocked"
  stats so the UI never shows a green badge over a half-filtered device.
* **Known bypasses, stated honestly:** hardcoded IPs and DoH/DoT resolve outside the
  tunnel. Surfaced in an honest "What this can't do" panel rather than pretended away.
  QUIC/UDP-443 is not inspectable here and not required for ad blocking.

### 3.4 Rule Engine + Rule Kit OTA

* **Filter syntax** — a deliberate **subset of uBlock Origin**, because full uBO is a
  browser-extension language, not a mobile one:
  * network: `||ads.example.com^`, `@@||cdn.example.com^` (exception), `||example.com^$domain=`
  * cosmetic: `##.ad-banner`, `#@#.ad-banner` (exception), `example.com##.promo`
  * $part=**: `third-party`, `domain=`, `badfilter`, `important` — supported
  * **Not supported, and this is a security boundary not a schedule item:** regex
    filters, `$replace` rewrites, redirect resources, scriptlets. A `$replace` rule is
    arbitrary code execution in page context, and kits arrive OTA from the network.
    **Kits carry declarative data only** — network blocks and CSS-hide selectors, from a
    strict selector grammar (class/id/attribute only; reject `:has()`, `url()`,
    `expression()`, and over-broad selectors like `*`, `html`, `body`, `input`, `form`).
* **Blocklist storage** — `drift` (SQLite) for rule sources, metadata and user rules; the
  *compiled host set* lives in Kotlin for O(1) lookup in the VPN hot path (Dart is too
  slow there). Structure: **sorted-array + binary search over a memory-mapped UTF-8 blob**,
  not `HashSet<String>` — at ~800k domains a Dart `HashSet<String>` costs ~120MB+ of heap
  and heavy GC churn, versus ~30MB and zero allocation per lookup.
  ⚠️ **mmap precondition:** `AssetManager.openFd()` can only mmap **uncompressed** APK
  assets (aaptOptions `noCompress`). A compressed asset throws. If we ship the blob as an
  asset we must mark it `noCompress`; otherwise copy it to files dir on first run. Decide
  in M1 and measure real memory either way — the ~30MB figure is an estimate, not a
  measurement.
* **Rule Kits (the differentiator)** — versioned, **Ed25519-signed** JSON bundles fetched
  from our own CDN and applied **only after** verify-then-parse, via atomic swap
  (temp file → fsync → rename). **A YouTube layout change ships as a Rule Kit update,
  not a store release.**
  * **SHA-256 is a hash, not a signature.** Anything that can write to the CDN can
    recompute it. Only the signature over canonical bytes provides authenticity.
  * **The public key is pinned in the APK** (in native/Kotlin, not a patchable Dart
    asset), with an offline fallback kit baked in. A key shipped inside a kit makes the
    whole scheme circular.
  * **Anti-rollback:** monotonic version + issue timestamp; reject
    `incoming.version <= current.version` and over-age manifests. A validly-signed *old*
    kit is still a downgrade attack.
  * **Full kits only in v1.** Deltas need their own chaining (`base_version`,
    `target_version`, per-chunk hashes in a signed manifest) and are premature
    optimisation with real security cost. Kits are small.
  * **Fail CLOSED.** Any verification, parse or disk failure → keep the current kit,
    show "rules stale", never disable blocking. A one-byte corruption must never strip
    protection.
  * **Hard limits regardless of kit contents:** max kit bytes, max rule count, max
    selector length, per-page rule-application time budget. Prevents a hostile or
    malformed kit from OOM-ing low-end devices or hanging the VPN.
  * **Key rotation** is via app update only, never a kit signed by the old key, with
    dual-key pinning and a public log of issued versions.
* **Sources:** HaGeZi (Multi PRO / DNR), AdGuard, uBlock filters, AdAway — pulled on a
  schedule, **pinned to upstream commit hashes**, normalised at build time, never shipped
  raw. A poisoned upstream line must be diffable and attributable, not silently shipped
  to every device.
* ⚠️ **U8 ("encrypted/obfuscated kits") should be deleted.** Obfuscation is not a security
  control for any of the above, it directly contradicts U20 (open rule format), and it
  buys false confidence.

### 3.5 Data & State

* `drift` for rules/sources/stats/history/bookmarks
* `riverpod` for DI + reactive state, `go_router` for navigation
* **Browsing history in an ad-blocker browser is the most sensitive store in the
  product.** It must be encrypted at rest (SQLCipher, or a Keystore-wrapped key),
  excluded from Android backup (`allowBackup=false`), and incognito must never persist.
  This is a product requirement, not a hardening nice-to-have.
* All blocking telemetry stays **on-device by default**. Anything opt-in is
  aggregate-only and separately consented — a canary fleet (§7 U10) is still a
  viewing-behaviour signal, and breakage reports (§7 U3) must redact query params,
  cookies and DOM text and send selectors only.
* Data Safety form must declare VPN/DNS processing, history, and breakage-report
  contents honestly. "No data collected" from a VPN app is a suspension waiting to happen.

### 3.6 PO Token / BotGuard Subsystem ⚠️ (referenced above, previously missing)

Required by Strategy B and the reason Strategy B is weeks of work, not days.

* YouTube's PO tokens are generated by **Google's BotGuard machine**, which per NewPipe's
  `PoTokenProvider` *"must be generated using Google's BotGuard machine, which requires a
  JavaScript engine with a good DOM implementation."*
* **Two tokens** are needed, not one: one for player requests (minter = videoId), one for
  streaming URLs (minter = visitorData for logged-out users). The second is appended to
  the manifest URL as `?pot=`.
* **Consequences:** we need a JS engine with a real DOM in-process, a BotGuard VM
  execution path, a token cache with refresh, and a binding from those tokens into the
  InnerTube request. NewPipe's `getManifestUrl()` is the reference shape:
  `manifestUrl + "?pot=" + poToken + "&" + suffix`.
* **M0 must produce a real answer on this**, because a token failure makes Strategy B
  dead and leaves only Strategy A — which is the one with no working anti-punishment
  reference implementation. That combination would be a project-killing result and we
  should hear about it in week 1, not month 3.

---

## 4. Tech stack

| Layer | Choice | Note |
|---|---|---|
| Framework | Flutter 3.47.0 / Dart 3.13 | Already in this workspace |
| State | `riverpod` | |
| Routing | `go_router` | |
| DB | `drift` (SQLite) | History encrypted at rest |
| WebView | `webview_flutter` 4.14.1 + **`androidx.webkit:webkit` ≥ 1.15** | Isolated worlds need 1.15; `addJavaScriptOnEvent` is alpha — avoid |
| Custom platform view | Kotlin `WebViewHost` | **Contingent on M0** — required if `webview_flutter` doesn't expose isolated-world injection |
| Player (Strategy B) | `media_kit` 1.2.6 | DASH / background audio |
| JS engine with real DOM | e.g. QuickJS-JNI or J2V8 | **Required by §3.6 BotGuard**; absent from v1 draft |
| VPN | **own Kotlin `VpnService`** | `flutter_vpn_service` / `flutter_vpn` abandoned. F-Droid build only |
| HTTPS | `dio` | |
| Crash reporting | none by default; opt-in Sentry later | Privacy is the product |
| Tests | `flutter_test`, `integration_test`, JVM unit tests for the filter engine | The filter engine must be provably correct |

**minSdk 23** (Android 6.0) — required by `androidx.webkit:webkit`.
**Build variants:** `play` (Engines 1+2) and `fdroid` (Engines 1+2+3), behind one
capability flag — the shared-code assumption behind Option C.

---

## 5. Milestones

### M0 — Feasibility spike (4–5 days) ⚠️ GATE
**This milestone can kill the project. Do it first, do not skip. It answers four questions:**

1. **Does `webview_flutter` expose AndroidX WebKit's isolated-world injection?** If not,
   Engine 1 becomes a custom Kotlin platform view and the estimate changes.
2. **Does hiding `.ytp-ad-*` at document-start actually stop the pre-roll**, on ≥2 real
   devices and ≥2 networks, with video starting cleanly?
3. **What does YouTube's punishment look like for a WebView client** — modal, buffering,
   mid-sentence breaks? Is cosmetic suppression of the punishment UI enough?
4. **Are PO tokens mintable in-app at all** (§3.6), and can we hold a non-punished client
   identity? **If not, Strategy B is dead** and we are left with the unproven Strategy A.

**Exit criteria:** (1) yes, (2) ad suppression works on ≥1 device, (4) tokens mintable.
If (4) fails **and** Strategy A is punished, **stop and re-scope** — that is a legitimate
outcome and it costs 5 days to find out.

### M1 — Rule Engine + test suite (1 week)
* uBO-subset parser, `drift` storage, rule compilation, signed Rule Kit fetch + verify +
  atomic swap + fail-closed.
* Hard engine limits (max bytes / rules / selector length / time budget) and the selector
  allowlist implemented **in the engine**, not by convention.
* mmap-vs-copy decision measured, not assumed.
* 100% parser unit tests against real uBO/AdGuard/HaGeZi lines. This is the
  correctness-critical component and gets the most coverage in the project.

### M2 — Ad-Free Browser (2 weeks)
* Browser shell: tabs/omnibox/bookmarks/incognito/downloads, encrypted history.
* `WebViewClientCompat` network blocking + cosmetic engine + hardened JS bridge.
* **Shippable milestone #1: "a browser that blocks ads everywhere" — Play-safe.**

### M3 — YouTube Surface (2–3 weeks)
* Strategy A fully wired: player, quality, captions, PiP, background audio.
* Punishment-UI suppression. **Heartbeat forwarding gated on counsel — default off.**
* Strategy B behind the health score, incl. the §3.6 token subsystem.
* **Shippable milestone #2: the headline feature — and the highest-risk deliverable.**

### M4 — VPN Filter (2 weeks, F-Droid build only)
* Kotlin `VpnService`, DNS sinkhole, mmap host set, per-app split tunnelling with
  honest exclusion UI, Private DNS detection gate, IPv6 decision.
* Battery profiling on Xiaomi/Samsung/Oppo — the real-world hard part.

### M5 — Release hardening (1.5 weeks)
* **Distribution lane chosen and executed** (§2.5). Play submission omits Engine 3 and
  files no VpnService declaration in that build.
* Play policy pass: privacy policy, Data Safety form, Terms page, non-affiliation
  disclaimer, full-featured-browser justification for the YouTube surface.
* Crash-free sessions, ANR watch, battery delta, accessibility, localisation.
* Play internal → closed beta (100 users) before public.

**Total to closed beta: ~11 weeks** — and that assumes M0 passes. M3 is the schedule's
biggest risk and is deliberately gated on a feasibility answer we do not yet have.

---

## 6. Risks & mitigations

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| R1 | YouTube changes break blocking | **High, recurring** | Rule Kit OTA; health score; breakage reports feeding the kit; M0 gate |
| R2 | Anti-adblock modal / mid-sentence breaks | **High** | Strategy A/B; cosmetic punishment-UI suppression; health-score failover. **Heartbeat is not a mitigation until proven and cleared by counsel** |
| R3 | SSAI ads are physically in the stream | Medium, unavoidable | Accepted residual defect. Detect and report honestly |
| R4 | **Play removes/rejects the app for the VPN or the YouTube surface** | **Critical** | **Was "Medium — precedents exist". Precedents were false: AdAway, AdGuard, ABP, Blokada 5 all removed.** Now: dual-build split (§2.5), Engine 3 excluded from Play, Policy Gate review before any Play submission |
| R5 | OEM kills the VPN service | Medium | Foreground service + notification + battery-optimisation prompt + per-OEM guides |
| R6 | Filter engine bug breaks a real site | Medium | Exception rules (`@@`), per-site disable, one-tap breakage report, heavy unit tests |
| R7 | Maintenance burden kills the project | **High** | Rule Kit decoupling — most fixes become data, not releases |
| R8 | **YouTube ToS / trademark / Play action** | **Critical** | **Was "Medium".** No login, no re-hosting, no DRM circumvention is *necessary but not sufficient* — Strategy B's token minting + client spoofing is where the real exposure is. Pre-launch legal review is not optional |
| R9 | DoH / hardcoded-IP DNS leak | Low | Honest disclosure panel; documented out of scope |
| R10 | Performance / battery regression | Medium | Benchmark gate in CI; mmap host set; lazy cosmetic rules; per-site toggle |
| R11 | **PO tokens unmintable / BotGuard changes** | **High** | M0 question 4. If it fails, Strategy B dies and Strategy A is the only play |
| R12 | **Private DNS (DoT) silently kills the VPN** | Medium | Blocking onboarding step to switch to Automatic; detect custom hostname at VPN start |
| R13 | **IPv6 leak** | Medium | Sinkhole or explicitly block + disclose; U22 self-test must cover IPv6 |
| R14 | **Poisoned Rule Kit ⇒ universal XSS + VPN bypass** | **Critical** | Pinned key in APK, verify-then-parse, monotonic version, fail-closed atomic swap, declarative-only kits, selector allowlist, hard limits, hash-pinned upstreams |
| R15 | **Compromised CDN account** | High | Signing key separated from deploy credential, MFA/hardware key, public log of issued kits, in-APK fallback kit so a takedown degrades instead of bricking |
| R16 | **User data breach** (stolen device / backup) | High | Encrypted history, `allowBackup=false`, auto-wipe option, least-privilege Data Safety |
| R17 | **Minimum Functionality / webview spam rejection** | Medium | Engine 1 must be a genuinely full browser; de-brand from YouTube chrome |
| R18 | **Only one VpnService may be active** | Medium | Document that CleanTube conflicts with banking/MDM/corporate VPNs; per-app exclusion as the escape hatch; work-profile warning |

---

## 7. Upgrade plans (beyond the original ask)

You asked for "your upgrade plans" — 24, ordered by value/effort.

### Tier 1 — Ship-blocking for viability (must be in v1)
| # | Upgrade | Why |
|---|---|---|
| U1 | **Rule Kit OTA** (signed, pinned, fail-closed, no store release) | The only way to survive R1/R7. Without it the product dies in a month |
| U2 | **Blocking health dashboard** — VPN liveness *and* player health | Turns silent failure into honest, actionable UI. Must show VPN state, not just YouTube |
| U3 | **Breakage repair mode** with per-report consent + automatic redaction | Built-in known-bad-player tester; reports send selectors only, never DOM text/URLs/cookies |
| U4 | **Per-site / per-app allowlist** | Users must un-break a site instantly or they uninstall. Warn on credential-field pages so "disable to continue" can't be used to whitelist phishing |
| U5 | **Onboarding that teaches VPN consent + Private DNS** | `VpnService.prepare()` is confusing; a bad first run loses the user (and silently breaks the VPN) |

### Tier 2 — Competitive differentiation
| # | Upgrade | Why |
|---|---|---|
| U6 | **SponsorBlock integration** (public API + downloadable DB) | Legit, open, immediately valuable: skips sponsor reads, intros, outros, self-promo. Strong SEO, no legal risk |
| U7 | **Filter editor with live tester** (uBO-style "test this page") | Turns a consumer app into a *tool*. Must sandbox untrusted rules — the engine limits from §3.4 apply here |
| U8 | ~~Encrypted/obfuscated rule kits~~ → **delete** | Not a security control; contradicts U20; false confidence |
| U9 | **Community rule marketplace + reputation** | Network effect + content pipeline. Signed-curator promotion only, no auto-execution of community kits |
| U10 | **Breakage radar / canary fleet** | Opt-in devices probe a known playlist; aggregate suppression rate → we learn breakage before users report it. Separate opt-in, plain-language disclosure |
| U11 | **Statistics dashboard** (ads blocked, by site/category) | Retention. Best engagement hook in an ad blocker |
| U12 | **PiP + background audio** | Table-stakes for a YouTube app. ⚠️ Never market as "background YouTube playback" — that phrasing is itself a policy tripwire |

### Tier 3 — Expansion
| # | Upgrade | Why |
|---|---|---|
| U13 | **Android TV / Leanback app** | WebView on TV + ad-free YouTube on the biggest screen. Genuinely underserved |
| U14 | **iOS phase 2** (Safari content blocker + `NEDNSProxyProvider`) | Real, but honest scope: iOS can *never* match Android. Sell as "browsing ad blocker", not "YouTube ad blocker" |
| U15 | **Quick Settings tile + Wear OS complication** | The toggle is a daily action; make it one tap |
| U16 | **Kids mode / YouTube Restricted integration** | Strong parent use case, strong retention, differentiator |
| U17 | **Config sync across devices** (own relay, E2E-encrypted) | Settings + custom rules follow the user. Needs a published protocol and minimal metadata, or cut it |
| U18 | **On-device ML classifier for unknown ad elements** | Long-term answer to cosmetic-rules rot: classify unknown elements that look like ads. Train on breakage reports |

### Tier 4 — Hardening / trust
| # | Upgrade | Why |
|---|---|---|
| U19 | **Privacy audit dashboard** (per-site tracker/ad log, no data leaves device) | A privacy product must be inspectable. This is the trust feature |
| U20 | **Open rule format + public ruleset repo** | Transparency; users can audit exactly what we block |
| U21 | **Bring-your-own blocklist source** | Power users and researchers |
| U22 | **DNS + IPv6 leak self-test** | Proves the VPN works. **Ship-blocking, not Tier 4** — must cover IPv6, not just IPv4 |
| U23 | **Release automation** (CI → internal track → staged rollout) | Weekly maintenance requires one-command releases |
| U24 | **Foldable/tablet/Chromebook layouts** | Free reach from the same codebase |

### Deliberately NOT planned (with reasons)
* **Root/LSPosed/Shizuku hooks** — Play forbids it, and sideloading a second app is strictly worse.
* **TLS/SNI inspection** — no real gain for ad blocking, heavy battery, easy to get wrong.
* **DoH/DoT blocking arms race** — whack-a-mole; we document it instead (§3.3).
* **Byte-range ad stripping from the DASH stream** — corrupts video (§3.2).
* **`$replace` / scriptlet / regex rules** — arbitrary code execution from an OTA-delivered
  source. This is a **security boundary**, not a backlog item.
* **Account login / Google API subscription sync** — privacy red line, and it hands
  YouTube a clean "you're an ad-free client" signal. Explicitly not doing this.

---

## 8. Repo layout

```
projects/cleantube/
├── PLAN.md                  ← this document
├── README.md
├── app/                     ← Flutter app (android/, lib/, test/)
│   ├── lib/
│   │   ├── core/            # engine-agnostic blocking core
│   │   │   ├── rule_engine/  # uBO-subset parser + compiler + limits
│   │   │   ├── rule_store/   # drift tables, host-set export
│   │   │   ├── rule_kit/     # signed OTA, pinned key, fail-closed swap
│   │   │   └── stats/
│   │   ├── features/
│   │   │   ├── browser/      # Engine 1
│   │   │   ├── youtube/      # Engine 2 (Strategy A + B, health score)
│   │   │   ├── vpn/          # Engine 3 (F-Droid build only)
│   │   │   ├── rules/        # editor + live tester
│   │   │   └── settings/
│   │   └── shared/
│   ├── android/app/src/main/kotlin/…/
│   │   ├── webview/          # WebViewHost, intercept, JS injection, bridge
│   │   ├── vpn/              # DnsVpnService, foreground service, host set
│   │   └── bridge/           # MethodChannel/EventChannel surface
│   ├── android/app/src/play/       # Play build: Engine 3 excluded
│   └── android/app/src/fdroid/     # F-Droid build: all engines
├── rulekits/                 # signed bundles, sources, build tooling
└── docs/
    ├── architecture.md
    ├── store-policy-notes.md  # live policy quotes + precedent table
    ├── distribution-lanes.md  # Play vs F-Droid decision record
    └── adblock-research.md    # NewPipe/PuTube source findings
```

---

## 9. Open questions (need your input)

1. **⛔ The distribution decision (§2.5).** Play Store and system-wide ad blocking are
   mutually exclusive. Play-only (browser + player), F-Droid-only (all three engines), or
   dual build? **This blocks M4 and changes the product identity**, so it is question one.
2. **Legal review before public launch** (R8) — on your critical path, or closed beta
   first? Note the presumption is that heartbeat forwarding gets cut.
3. **Name.** `CleanTube` works but emphasises YouTube while the app is broader.
   `AdShield`, `NullTube`, `Sieve`? Consider trademark exposure before branding it around
   YouTube (§6 R8).
4. **Domain/CDN for Rule Kits**, or GitHub Releases for v1? Rule Kits are a
   single-host dependency — plan for a fallback from day one.
5. **Community backend** (U9/U10) — ship without, or budget a server early?
6. **Is the browser in scope for v1?** ~2 of ~11 weeks. Without it the app has no durable
   value if YouTube breaks (R1) *and* it is what makes the YouTube surface acceptable to
   Play (R17). Recommend yes.

---

## 10. Immediate next step

**Run M0.** Four or five days that answer: *can a WebView on a stock Android phone play
YouTube with the pre-roll suppressed, without triggering punishment; does
`webview_flutter` give us isolated-world injection; and can we mint PO tokens in-app?*

If the answer to the PO-token question is no **and** Strategy A is punished, the correct
response is to stop and re-scope — not to build 11 weeks of something that does not work.
