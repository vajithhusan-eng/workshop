# CleanTube — Master Plan

**Ad-Free YouTube + Ad-Blocking Browser · Flutter · Android-first Mobile App**
Status: PLAN v4 (source-verified) · Date: 2026-09-28 · Supersedes v1–v3 drafts
Evidence base: NewPipeExtractor `@dev`, AdAway's `VpnService` source, Intra's `allowFamily`
usage, the live Play *Device and Network Abuse* policy, and yt-dlp's PO-Token guide.

---

## 0. TL;DR

A Flutter Android app that blocks ads, with YouTube as the headline target. Two
independent blocking engines, because no single mechanism can do the whole job:

| # | Engine | What it kills | Where it runs | Play Store? |
|---|---|---|---|---|
| 1 | **Ad-Free Browser** (WebView + blocking engine) | Ads on every website we load | Inside our browser | ✅ Yes |
| 2 | **YouTube Client** (bespoke InnerTube, no WebView) | YouTube ads — by never requesting them | Inside our player | ⚠️ Risky |
| 3 | **System VPN Filter** (`VpnService` DNS sinkhole) | Ads in *other* apps (Instagram, games) | Whole device | ❌ **Prohibited** |

Plus **Rule Kits**: blocking rules ship as signed JSON and update **without a store
release**, so a filter-list fix is answered in hours, not weeks.

### The single idea that makes this work

> **You do not need to *block* YouTube ads. You need to *not ask for them*.**

The WEB InnerTube client makes a **second, separate** player-family request carrying
`adPlaybackContext` to obtain ad stream URLs. The ad fields are not inline in the content
manifest. A client that never makes that request **never receives ads** — so there is
nothing to strip, and no cat-and-mouse game with YouTube's ad-pruning logic.

This is not a theory. Reading `NewPipeExtractor`'s `YoutubeStreamExtractor.java` shows
**zero references** to `adPlacements`, `playerAds`, `adBreakHeartbeatParams`, `adSlots`
or `adParams`. NewPipe does not strip ads. It never receives them. That single fact
reshapes the entire architecture — and it is why Engine 2 is a native client rather than
a WebView.

### Five findings that changed this plan

This draft exists because the first two drafts were wrong. All five were found by
reading source and the live Play policy, not by guessing.

**1. Google Play explicitly prohibits system-wide ad blocking.**
The current *Device and Network Abuse* policy lists, as a common violation:
*"Apps that block or interfere with another app displaying ads."* AdAway, AdGuard,
AdBlock Plus and Blokada 5 were all **removed from Play** for this. The v1 draft claimed
they were precedents. They were the opposite — evidence. **Engine 3 cannot ship on Play.**
See §2.5.

**2. The ad-break "heartbeat" trick was never a real design.**
v1 claimed the fix for YouTube's ad-blocker punishment was forwarding
`ad_break/heartbeat` while hiding the ad. NewPipe **does not do this at all.** It avoids
punishment a different way — it never requests ad data, and it uses a client identity
YouTube does not punish. The trick is now marked **unverified and legally risky**, and
is not a feature.

**3. `addDocumentStartJavaScript` injects into the ISOLATED world — it cannot patch
`window.fetch`.** This is the trap that costs a week. Overriding `fetch` in an isolated
world does nothing: different JS heap, different `window`. Main-world injection needs
`WebViewCompat.getExecutionWorld(webView, "")` + `addJavaScriptOnEvent`, gated on
`WebViewFeature.JS_INJECTION_IN_FRAME_AND_WORLD`. See §3.1.

**4. CSS/DOM hiding of YouTube player ads is already dead.**
EasyList's `easylist-annoyances.txt` contains 22 YouTube lines and **zero player-ad
selectors**. The classic `.ytp-ad-*` / `#masthead-ad` selectors this plan used in v1 are
vestigial — dead for years. Cosmetic hiding cannot stop the ad bytes downloading, and
YouTube fires `onAbnormalityDetected` if you mutate the player DOM at the wrong time.
See §3.2.

**5. `ANDROID_VR` may make PO tokens irrelevant — and that changes the build order.**
The WEB client needs BotGuard-minted tokens *and* is SABR-only (a proprietary UMP
container neither `media_kit` nor Media3 can play). The `ANDROID_VR` context requires
**no PO token** and returns plain DASH URLs. If it holds, the single largest unknown
disappears. §3.6 is demoted accordingly.

**M0 exists to settle all of these before we build anything.**

**6. The v2 VPN tunnel design was wrong.**
It proposed `addAddress("10.0.0.2", 32)` + `addRoute("10.0.0.2", 32)` + `addDnsServer(...)`
— which installs a single host route and captures one address. AdAway's real design uses
the **prefix** of `addAddress` to install the capture subnet route, one alias per upstream
resolver, and — critically — **`allowFamily(AF_INET)` + `allowFamily(AF_INET6)`, without
which the unaddressed address family is blocked outright and you silently kill all IPv6.**
See §3.3, which is now a corrected, implementation-level design.

**7. No usable `VpnService` bridge exists on pub.dev, and one of the candidates is
actively dangerous.**
`flutter_vpn_service` instantiates `VpnService` as a plain plugin object with no
foreground-service lifecycle — Android kills it and the TUN dies with the Flutter engine. It
also never launches the consent Intent and lacks `addDnsServer` / `addDisallowedApplication`
/ `allowFamily`. Separately, **HaGeZi is GPL-3.0 and must not be bundled** in a proprietary
APK, which the v2 draft proposed. See §3.3, §4.1, R24, R25.

**M0 exists to settle findings 1–5 before we build anything.** Findings 6–7 are already
settled — by reading AdAway's and Intra's source — and §3.3 is rewritten accordingly.

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

- **A bespoke InnerTube client that never requests ads.** There is nothing to block, so
  there is nothing to break. The only architecture with no ad surface to defend.
- **WebView request *blocking*** (the Brave-in-a-WebView model) for ads on ordinary web
  pages. Proven, no extensions required, policy-safe because it stays inside our app.
- **DNS sinkholing in a local VPN** for cross-app ads — proven *as a technique*, and
  shipped that way by AdAway, AdGuard and Blokada 5, all **off Play**.

### 2.4b What does NOT work (and why you will read this somewhere and believe it)

| Myth | Reality |
|---|---|
| *"Block `youtube.com/api/stats/ads` to stop the official app showing ads."* | **Refuted.** That endpoint is a *telemetry heartbeat* — how the player reports an ad was shown, not how ad media is delivered. uBlock itself marked its own rule for it **`badfilter`**, which is uBO's explicit marker for "this rule does not work." The most sophisticated blocking engine ever built tested the idea and rejected it. |
| *"Hide the ad element with CSS."* | Dead. See finding 4. No player-ad selectors remain in the major lists, the ad bytes still download, and DOM mutation at the wrong moment trips `onAbnormalityDetected`. |
| *"Filter the ad out of the `googlevideo` byte stream."* | Impossible. Ad and content share the same host (`rr{n}---sn-*.googlevideo.com`), often the same connection, and segment boundaries are not exposed to a range request. AdGuard's own engineer: *"It seems video ad is loaded from `*.googlevideo.com`."* |
| *"Use Android WebKit's declarative net request API."* | **It does not exist.** `ProxyController`/`ProxyConfig` — which would be exactly the right shape — are `@RestrictTo(LIBRARY_GROUP)` with a `TODO` in the source. It compiles, lints, and then throws. |

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

**Conclusion: the distinction that matters is scope — ads *in other apps*, not trackers
*in other apps*.** This is sharper than v2 stated, and it is visible in DuckDuckGo's own
live Play listing:

> *"**Block Ads:** Our browser blocks most video ads, and stops invasive trackers from
> loading on sites…"* — and, separately —
> *"**Protect Your Personal Information in Other Apps:** Block most hidden trackers in
> other apps… This feature uses a VPN connection but is not a VPN."*

DuckDuckGo blocks **trackers** in other apps over a VPN and survives; blocks **ads** in
its own browser and survives. What does not survive is blocking **ads in someone else's
app**. Tracker blocking ≠ ad blocking under this policy.

### 2.5b 🚨 The escape hatch is closing — 30 September 2026

**This is time-critical and it invalidates part of the plan's own recommendation.**

Google's Android **developer verification** programme begins enforcement on
**30 September 2026 — two days from this draft** — in **Brazil, Indonesia, Singapore and
Thailand**, across Google Play, Galaxy Store, HONOR App Market, OPPO App Market and
GetApps. Global rollout follows in 2027.

The "advanced flow" requires: Developer options → *"Allow apps from unverified
developers"* → restart → 24-hour cooldown → biometric/PIN → grant for 7 days or
indefinitely. It lives in **proprietary Google Play Services**, so it does not exist on
de-Googled ROMs or Lineage.

**Consequences for this plan:**

1. **"Just ship it on F-Droid if Play rejects us" is no longer a business plan.** The
   install funnel collapses from "tap a link" to a multi-step, discoverable, per-device
   ritual. Option B's "small, technical, self-installing" audience shrinks materially
   every year.
2. **Play becomes the only distribution with real reach** — which means a Play policy
   violation can no longer be priced in as an acceptable risk.
3. **We need a verified developer identity.** NewPipe has made the opposite call — their
   pinned Feb 2026 post says they will *not* enrol and will *"give up the anonymity of our
   developers"* — and are now in a feature freeze while rewriting their codebase. That is a
   legitimate choice for them; it is not available to us if we want distribution.

**This does not remove the Play policy problem — it makes it terminal.** Option C's
"F-Droid build carries the VPN engine" is now a much smaller hedge than it was when this
plan was drafted. It should be treated as a developer/early-adopter convenience, not as a
distribution strategy.

> ⚠️ **Action for you, today:** if you intend to ship anything on Play, you need a
> verified developer account and a `D-U-N-S` number, and you should start that
> process now — it is the long pole and it is not something we can fix in code.

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

**Recommendation: Option C, but reweighted.** The two builds share ~85% of the code and
differ behind one capability flag. Given §2.5b, F-Droid is now a *convenience for
developers and early adopters*, not a second revenue or distribution channel — so Option
A is more attractive than it looks, and the cost of C is lower than it sounds. But the
**VPN engine itself must go**, in both lanes. That is a decision about the product, not
about distribution.

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

**Cosmetic blocking** — ⚠️ **the isolated-world trap, read this before writing any JS**
* `WebViewCompat.addDocumentStartJavaScript(webView, js, origins)` injects into the
  **isolated world**. That is a *different JS heap with a different `window` object*.
  Overriding `window.fetch` there does **nothing at all** to the page. This costs a week
  if you discover it late, and it is the most common reimplementation mistake.
* For anything that must touch page globals, use the main world:
  ```java
  if (WebViewFeature.isFeatureSupported(WebViewFeature.JS_INJECTION_IN_FRAME_AND_WORLD)) {
      JavaScriptExecutionWorld page = WebViewCompat.getExecutionWorld(webView, ""); // "" = page world
      WebViewCompat.addJavaScriptOnEvent(webView, page, allowedOrigins,
          WebViewCompat.JavascriptEvent.DOCUMENT_START_SCRIPT, callback);
  }
  ```
  `addJavaScriptOnEvent` with a `JavaScriptExecutionWorld` is **androidx.webkit 1.16.0+**.
  * **Always feature-gate. Never hardcode a version.** The minimum WebView version lives
    in WebView's own `WebViewGlueCommunicator` boundary constants, not the AndroidX repo.
    `DOCUMENT_START_SCRIPT` is known to be WebView 105+; assume `JS_INJECTION_IN_FRAME_AND_WORLD`
    is the same era but **verify empirically** — an unsupported call throws
    `UnsupportedOperationException`.
  * Consequence for packaging: `androidx.webkit:webkit` ≥ 1.16 → **minSdk 23**.
* **Isolation is still desirable where it works** — for our own telemetry and
  DOM-reading code that need not touch page globals, isolated world prevents collisions
  with site JavaScript. Use both worlds deliberately rather than defaulting to one.
* ⚠️ **YouTube uses a Trusted Types policy** that broke uBlock's own server-side-ad
  filtering on Chromium. Expect our cosmetic layer to be similarly affected. Known
  landmine, not a surprise.
* **In Flutter these are not callable from Dart.** `webview_flutter` does not expose
  execution worlds. We need either a thin `MethodChannel` into a platform-view WebView,
  or `inappwebview` (which exposes `UserScript` with a `contentWorld`) — and
  `inappwebview` has the *same* failure mode, documenting that `AT_DOCUMENT_START` only
  guarantees ordering when `DOCUMENT_START_SCRIPT` is supported. **M0 must resolve this
  before M2 is estimated.**

**Bridge** — `WebViewCompat.addWebMessageListener` ↔ `MethodChannel`
* `JS → Dart`: ad element sighted, telemetry, SPA route changes
* `Dart → JS`: inject/update cosmetic rules, toggle blocking without page reload
* ⚠️ **This is an injection sink and must be hardened:** strict origin allowlist, JSON
  schema validation, 4KB message cap, per-origin rate limit, drop-and-log on violation.
  Never expose a bridge method that evaluates strings, reads cookies, or writes files.

**Browser features (v1):** omnibox + search, tabbed + popup, bookmarks, history,
incognito (separate AndroidX WebKit `Profile` — no cookie bleed), downloads, share
sheet, find-in-page, desktop/mobile site toggle, share-to-CleanTube intent.

### 3.2 Engine 2 — YouTube Client (the "new way")

**The principle, restated because everything below follows from it:** the WEB client
issues a **second, separate** player-family request carrying
`adPlaybackContext` / `adType: AD_TYPE_INSTREAM` to obtain ad stream URLs. The ad fields
are **not** inline in the content manifest. A client that never makes that request never
receives ads.

**You cannot prevent the official app from making that request from outside its process.**
To control it, you must control the client. Hence a native client.

#### Strategy B — Bespoke InnerTube client ⭐ **THIS IS THE PRIMARY PATH**

Ship a native Dart YouTube client. No WebView in the playback path.

| # | Step | Detail |
|---|---|---|
| 1 | **Pick a non-punished client identity** | `ANDROID_VR` is the target: **no PO token required**, plain DASH URLs, no `signatureCipher`/`n`-parameter. See the client table below. |
| 2 | **Never send `adPlaybackContext`** | Use `$fields` on the player request so no ad data comes back. This is why NewPipe never needs to strip anything. |
| 3 | **Synthesise an MPD** | High quality returns **separate video and audio URLs**. Build a minimal MPD document in memory (`application/dash+xml`) referencing both `BaseRepresentation`s and hand it to the player. This is what NewPipe and Seal do. **Do not run two players and mix** — you will fight the audio-focus stack forever. |
| 4 | **Play it** | `media_kit` (MIT, fastest path, `dash` demuxer) or Media3 `ExoPlayer` (more control, more Kotlin glue). |

**YouTube DASH is `fMP4` + `WebM`/Opus. No Widevine is involved for standard content** —
we are not touching DRM at all.

**Client landscape (from the yt-dlp Po-Token Guide's enforcement table):**

| Client | PO Token | Playback | Verdict |
|---|---|---|---|
| `web` | Subs + GVS | **SABR only** | ⛔ |
| `web_safari` | GVS* | HLS may avoid PO Token | partial |
| `mweb` | GVS | mixed | fallback |
| `tv` / `tv_simply` | not required | *all formats DRM'd without cookies* | ⛔ |
| `web_embedded` | not required | embeddable videos only | limited |
| `android` | GVS/Player | GVS | ⛔ |
| **`android_vr`** | **not required** | **GVS (plain URLs)** | ✅ **target** |
| `ios` | GVS/Player | GVS | ⛔ |

`ANDROID_VR` is the sweet spot because it sidesteps **three** existential problems at
once: no PO Token, no SABR, and no `n`-parameter — which otherwise forces a JavaScript
engine into the app just to compute throttling parameters. Refusing that dependency is
worth a great deal on its own.

**Fallback ladder, built from day one, not later:**
1. `android_vr` → plain DASH URLs. *(target)*
2. `mweb` → if `hlsManifestUrl` comes back, hand the `.m3u8` to `media_kit`'s HLS path. *(cheap)*
3. `web` + valid PO Token → **SABR only** → requires a UMP demuxer. ⛔ *out of scope for v1.*

> 🚨 **`android_vr` is a moving target and we must plan for that.** It is a
> *Meta-distributed* client, not a Google first-party app. Google restricted `TVHTML5`
> the same way (NewPipe removed that client), and NewPipe has since cut `ClientsConstants`
> on its dev branch down to **four** clients — `WEB`, `WEB_REMIX`,
> `WEB_MUSIC_ANALYTICS`, `VISIONOS` — with `ANDROID`, `IOS`, `TVHTML5` and `MWEB` **all
> removed**. NewPipeExtractor 0.26.3's changelog reads: *"Workaround SABR enforcement by
> using another player client."*
>
> **The most mature open-source YouTube extractor in existence has been forced down to a
> two-client configuration and is actively being SABR-broken. That is our maintenance
> forecast**, whether or not we use NewPipe.
>
> ⇒ **Non-negotiable engineering requirement: the active client must be a remotely
> switchable config string.** Not a build-time constant.

#### Strategy A′ — WebView + main-world JSON pruning (**FALLBACK ONLY**)

Only if InnerTube-native playback proves unworkable in our timeline. Real, works today,
and is a treadmill for the life of the app.

Load real YouTube in a WebView and hook the network **in the page's main world**:

* **Prune the response** — intercept `/player` fetch/XHR JSON and remove `adPlacements`,
  `adSlots`, `playerAds`, `legacyImportant`. uBO often does this by **string replacement**
  (`"adPlacements"` → `"no_ads"`) because YouTube's protobuf-ish repeated-field encoding
  does not survive a full JSON re-serialisation.
* **Mutate the request — this is the part every reimplementation forgets, and response
  pruning alone does not work.** YouTube also uses `clientScreen` and
  `contentPlaybackContext` to decide whether to request ads at all. The single
  highest-value injection is:
  `contentPlaybackContext: { "isInlinePlaybackNoAd": true }` — tell YouTube the surface
  is ad-free so it never mints an ad stream.
* **Both request-mutation and response-pruning are mandatory.** uBO's live YouTube rules
  do both; most reimplementations do only the first half and then conclude it doesn't work.
* This is a **treadmill**: uBO's YouTube quick-fixes are rewritten every few months. Budget
  for a breakage cycle every few weeks, forever — or don't build it.

#### Strategy C — DOM/CSS hiding (**NOT A TECHNIQUE — A GARNISH**)

EasyList carries 22 YouTube lines and **zero player-ad DOM selectors**. The classic
`.ytp-ad-module` / `.video-ads` selectors are vestigial. The player is a closed,
heavily-bundled React app with obfuscated class names, and YouTube fires
`onAbnormalityDetected` if you mutate the player DOM at the wrong moment. Pure CSS
hiding also cannot stop the ad **bytes downloading** — you pay full bandwidth and still
see a spinner. Keep cosmetic rules for ordinary pages; do not build a strategy on them
for YouTube.

#### Strategy D — Byte-range ad stripping from `googlevideo` (**IMPOSSIBLE**)

Ad media and content media come from the same host, often the same TCP/TLS session.
Nothing stable to match on, and segment boundaries are not exposed. Dead on arrival, and
so is any DNS-level approach (§2.2).

**Health score** — rolling measure of which strategy is actually working (playback start
latency, decoy-response detection via `videoDetails.videoId` mismatch, SABR detection,
ad-UI sightings, player error codes). Auto-routes to the healthier strategy and drives
the in-app "Blocking degraded" banner.

### 3.3 Engine 3 — System VPN Filter (`DnsVpnService`) — ⚠️ PROHIBITED ON PLAY

**Not shippable on Play** (§2.5, §2.5b). Sideload/developer distribution only.

**The tunnel design in the v2 draft was wrong.** It proposed
`addAddress("10.0.0.2", 32)` + `addRoute("10.0.0.2", 32)` + `addDnsServer("10.0.0.2")`.
That installs only a *host* route and captures a single address. The correct design is
**AdAway's**, read from `DnsServerMapper` — and it is about thirty lines.

**AdAway's actual design (adopt this):**
* **TEST-NET-1 subnet with a prefix:** `addAddress("192.0.2.0", 24)`. The **subnet route
  that `addAddress` with a prefix installs is the actual capture mechanism** — the `/32`
  `addRoute` on the alias is belt-and-braces, not the mechanism. Get the prefix right or
  nothing gets captured.
* **One alias per upstream resolver.** For each system resolver take the next address in
  the TEST-NET subnet (`192.0.2.2`, `.3`, … — the index starts at 2 because `.0` is the
  subnet address and `.1` is network/broadcast), call `addDnsServer(alias)` and
  `addRoute(alias, 32)` for IPv4. The alias's last octet *encodes* the resolver index;
  reverse-map by `lastOctet - 2`. IPv6 uses `2001:db8::/120` and needs **no** explicit
  `/32` route, because `addAddress` with a prefix installs the route itself.
* **`allowFamily(AF_INET)` + `allowFamily(AF_INET6)` — MANDATORY, and the single most
  common v1 bug.** Android's default rule: *if you add no address, route, or DNS server for
  an address family, that family is blocked entirely.* Build only the IPv4 TEST-NET subnet
  on an IPv6 network and you silently kill all IPv6.
* `setBlocking(true)` (dedicated worker thread), `setMetered(false)`, `allowBypass()`.
* **⚠️ `allowBypass()` combined with the Settings "Block connections without VPN"
  (lockdown) toggle is dangerous** — apps bound to a specific network end up with *no
  connectivity at all*. Consider omitting `allowBypass()`, and document the interaction.
* **The TUN read loop lives in Kotlin, on a dedicated blocking thread. Never Dart.** A
  packet `read()` loop over a `MethodChannel` is an ANR generator. Aggregate counters in
  Kotlin and push a snapshot at 1 Hz over an `EventChannel` — never per-query, which would
  freeze the UI isolate at thousands of messages/second.
* **Two channels, not one:** `MethodChannel` for commands in, `EventChannel` for state and
  telemetry out.
* **`addDisallowedApplication(getPackageName())` — one line, not `protect()`.** Intra proves
  it: its `getProtector()` returns `null` on API ≥ 21 precisely because this call makes
  per-socket protection unnecessary. AdAway does the opposite (skips itself, protects each
  socket) and is strictly more error-prone.
* **Always null-check `establish()`** — it returns `null` when unprepared or revoked. This
  is the most common crash in hand-rolled `VpnService` implementations.
* **`onRevoke()` is terminal for that session** — it may not run on the main thread and the
  replacement interface is already routing. Tear down, do not flush; surface a resume CTA
  rather than auto-retrying, which is how you get an app the user force-stops.
* **Filter changes = `stop → configure → start`**, never live mutation. Routes and DNS
  servers are immutable once established. AdAway's `VpnModel.apply()` does exactly this.

**The package landscape is worse than v2 recorded — no viable option exists:**

| Package | Verdict |
|---|---|
| `flutter_vpn_service` 1.1.0 (2024-12) | ⚠️ **The dangerous one.** Plausible API, broken on device: `VpnService` is instantiated as a plain plugin object with **no `startForegroundService`/`onStartCommand`/notification** (Android kills it and the TUN dies with the Flutter engine); `prepareVpn` only *checks* consent and **never launches the consent Intent**; and it has **no `addDnsServer`, no `addDisallowedApplication`, no `allowFamily`**. |
| `flutter_vpn` 0.13.0 | Wrong category — vendors the whole strongSwan/IKEv2 runtime. Cannot read a TUN, has no blocklist concept. |
| `vpn` (xclud) 1.0.0 | Won't even resolve on Dart 3 (`sdk: ">=2.12.0 <3.0.0"`). 10 downloads/30d, three-method API. |
| `vpn_manager`, `vpn_service` | Do not exist. Stop searching pub.dev for them. |

**Write the ~600 lines ourselves.** `flutter_vpn_service`'s existence is the strongest
argument for it — we would spend longer working around it than writing it.

**Blocklist storage — copy AdAway, not a custom mmap structure.** The v2 draft proposed a
sorted memory-mapped blob. AdAway's proven design is simpler:
* `hosts_lists` table (raw sources, per-source `enabled` flags) + a `host_entries`
  denormalised lookup table built with `INSERT ... SELECT DISTINCT`. Toggling a source is a
  `DELETE` + re-import, **not** a query-time `UNION`.
* `LruCache(4096)` in front. Instrument `hitCount()`/`missCount()` from day one — it is the
  only free performance telemetry we get.
* **The allowlist is a deletion, not a separate check** — `allowHost` removes the row, and
  absent-means-allowed is one indexed lookup via `IFNULL(..., 1)`.
* **Skip wildcard (`*.example.com`) tiers in v1.** They need suffix matching, and
  `HashSet.contains()` on a wildcard **silently fails to block** — the most common bug in
  hand-rolled implementations. Use non-wildcard `dnsmasq` format.
* **Cache negative results too.** Most DNS traffic is for domains that are *not* blocked, so
  this roughly doubles effective cache capacity for free. One-line change, do it in v1.
* ⚠️ **`drift` may not be usable on the hot path.** `sqlite3_flutter_libs` 0.6.0+ is EOL
  ("no longer does anything") and `drift_dev >= 2.23.0` depends on `sqlite3 ^2.4.6`,
  conflicting with `sqlite3` 3.x. Since the blocklist lives in the **Kotlin** layer anyway,
  the pragmatic answer is **Room (`room-runtime` 2.6.1) in Kotlin** for the hot path,
  keeping `drift` for Dart-side UI state only. Decide in M1.

**⚠️ HaGeZi is GPL-3.0 and must NOT be bundled in a proprietary APK.** Its own licence
notice says: *"Check the license in the repository before redistributing the lists as part
of your own product or service."* The v2 draft listed HaGeZi as a source to normalise at
build time — that is a distribution violation. Options, in order:
1. **Self-compile our own list** from permissively-licensed inputs and publish the *output*
   under our own licence. Cleanest answer.
2. **Download at runtime** from HaGeZi's CDN. Not a derivative work — but GPL arguably
   still reaches network use, and this is legally unsettled. *Get a lawyer's opinion.*
3. **Bundle `StevenBlack/hosts` (MIT)** as a bootstrap list only. Works today; weak on mobile.

*(Documentation note: the widely-cited HaGeZi **REACH and DNR lists no longer exist**.
Current tiers are Light / Normal / Pro / Pro++ / Ultimate / TIF. Citing REACH/DNR marks a
document as stale.)*

**⚠️ Private DNS (DoT) can silently defeat this.** Verified in tailscale/tailscale#915: if a
*custom* Private DNS hostname is set (e.g. `dns.nextdns.io`), enabling the VPN **stops all
DNS resolution** and Settings shows "couldn't connect". The *Automatic* setting is fine.
⇒ **CleanTube must detect a custom Private DNS hostname at VPN start and make switching to
Automatic a blocking onboarding step**, or the VPN no-ops with no explanation.

**⚠️ DoH/QUIC bypass is structural, not a bug to fix.** With no default route, QUIC (UDP/443)
and DoH never enter the TUN at all. Apps shipping their own resolver — most of Chromium,
Firefox, and a growing share of Android apps — never touch our fake DNS, and setting
"Private DNS = Off" in system settings does nothing about them. This is a property of
DNS-level filtering; it will not improve with better code.

* **Rank 0, free, ship in v1:** bundle HaGeZi's `ips/doh.txt` (1,423 known DoH resolver IPs,
  20 KB) and surface a **warning card** — *"your browser is using its own encrypted DNS,
  which bypasses this filter."* Detects rather than blocks. Far better than silently
  under-delivering, and it costs 20 KB.
* **Rank 1, opt-in:** blackhole well-known DoH resolvers via `addRoute("9.9.9.9", 32)`.
  Brittle, and hard-blocking `1.1.1.1`/`8.8.8.8` breaks many apps. Make it a **"Strict
  mode" toggle, default off.**
* **Rank 2+:** routing QUIC in, or TLS SNI inspection, requires a full userspace IP stack
  (the NetGuard/Intra shape) — 20–40 days of NDK work. Defer until measured.
* **Upstream disclosure.** Forwarding to 1.1.1.1/9.9.9.9 over plaintext UDP exports the
  user's non-blocked DNS footprint to a third party. Must be disclosed on the consent
  screen, in the privacy policy, and in the Data Safety form. A privacy product cannot
  hide this.
* **Per-app split tunnelling** — `addDisallowedApplication()`, with a persistent warning
  that excluded apps are unfiltered, and excluded apps dropped from "ads blocked" stats so
  the UI never shows a green badge over a half-filtered device. Platform constraint:
  **allowed-list OR disallowed-list, never both** — setting both throws.
* ⚠️ **Never promise "blocks all ads."** HaGeZi's own words: *"no DNS blocklist can work
  around it."* YouTube and Spotify serve ads from the content hostname. Promise "blocks the
  ads DNS-level filtering can see, which is most of them." Better reviews, no unservable
  support load.
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

### 3.6 PO Token / BotGuard Subsystem — ⏸️ **DEFERRED, may never be needed**

**This was the largest unknown in the plan. `ANDROID_VR` may delete it entirely.**

The PO-token subsystem is only required by the `web` and `android`/`ios` clients. The
`ANDROID_VR` context (§3.2) requires **no PO Token** and returns plain URLs. Since
`android_vr` is now the primary target, this section drops from "weeks of work and a
project-killing risk" to "a fallback we hope never runs."

**It is still written down because the fallback ladder (§3.2) leads there, and the
fallback ladder is non-negotiable.** If `android_vr` gets SABR-enforced, the only
remaining paths are `web` + PO Token, and we will need this.

* YouTube's PO tokens are generated by **Google's BotGuard machine**, which per NewPipe's
  `PoTokenProvider` *"must be generated using Google's BotGuard machine, which requires a
  JavaScript engine with a good DOM implementation."*
* **Two tokens** are needed, not one: one for player requests (minter = videoId), one for
  streaming URLs (minter = visitorData for logged-out users). The second is appended to
  the manifest URL as `?pot=`.
* Reference shape, from NewPipe's `getManifestUrl()`:
  `manifestUrl + "?pot=" + poToken + "&" + suffix`.
* **Cost if we must build it:** a JS engine with a real DOM in-process, a BotGuard VM
  execution path, a token cache with refresh, and a binding from those tokens into the
  InnerTube request.

> ⚠️ **But note what sits behind it.** The `web` client is **SABR-only**. SABR changes
> delivery to `POST …/videoplayback?&sabr=1` returning `content-type: application/vnd.yt-ump`
> — a proprietary protobuf container that **neither `media_kit` nor Media3/ExoPlayer can
> play**. So the PO-token path does not actually save us: it leads to a **UMP demuxer**,
> which is the entire project by itself.
>
> **This is why `android_vr` matters so much, and why a SABR/UMP demuxer is on the
> "deliberately not planned" list.** PO tokens are the *smaller* half of that problem.

**M0 must produce a real answer on whether `android_vr` works without a PO Token**, by
capturing a live request from the Oculus YouTube app before writing any code. If it does
not, we have a genuine strategic decision to make, and we should hear about it in week 1
rather than month 3.

---

## 4. Tech stack

| Layer | Choice | Note |
|---|---|---|
| Framework | Flutter 3.47.0 / Dart 3.13 | Already in this workspace |
| State | `riverpod` | |
| Routing | `go_router` | |
| DB (Dart, UI state) | `drift` (SQLite) | History encrypted at rest |
| DB (Kotlin, blocklist **hot path**) | **`room-runtime` 2.6.1** | ⚠️ **`drift` is unsafe here**: `sqlite3_flutter_libs` 0.6.0+ is EOL and `drift_dev ≥ 2.23.0` pins `sqlite3 ^2.4.6`, conflicting with `sqlite3` 3.x. The blocklist is read on every DNS packet — it cannot be in Dart anyway. Decide in M1. See §3.3 |
| Blocklist data model | AdAway's: `hosts_lists` + denormalised `host_entries` + `LruCache(4096)` + negative caching | Proven under real load. v2's "sorted mmap blob" is cut — see §3.3 |
| WebView | **custom Kotlin platform view** + **`androidx.webkit:webkit` ≥ 1.16** | `webview_flutter` does **not** expose execution worlds. Main-world injection is non-negotiable for Strategy A′ — see §3.1 |
| Player (primary) | `media_kit` 1.2.6 | DASH via synthesised MPD. MIT. Fastest path |
| Player (alternative) | `androidx.media3:media3-exoplayer-dash` 1.11.0 | More control, more Kotlin glue. Apache-2.0 |
| JS engine with real DOM | QuickJS-JNI or J2V8 | **Deferred** — only needed for the §3.6 BotGuard fallback |
| VPN | **own Kotlin `VpnService`** (~600 LOC) | ⚠️ **Prohibited on Play — see §2.5.** No viable pub.dev bridge exists: `flutter_vpn_service` 1.1.0 kills the TUN (no foreground-service lifecycle) and lacks `addDnsServer`/`addDisallowedApplication`/`allowFamily`; `flutter_vpn` is a strongSwan/IKEv2 wrapper; `vpn` (xclud) won't resolve on Dart 3. See §3.3 |
| Blocklist sources | **Self-compiled from permissively-licensed inputs** | ⚠️ **HaGeZi is GPL-3.0 and must not be bundled** in a proprietary APK. `StevenBlack/hosts` (MIT) as a bootstrap fallback only. See §3.3, §4.1 |
| HTTPS | `dio` | |
| Crash reporting | none by default; opt-in Sentry later | Privacy is the product |
| Tests | `flutter_test`, `integration_test`, JVM unit tests for the filter engine | The filter engine must be provably correct |

**minSdk 23** (Android 6.0) — required by `androidx.webkit:webkit` 1.16.
**Build variants:** `play` (Engines 1+2) and `fdroid` (Engines 1+2+3), behind one
capability flag — the shared-code assumption behind Option C. **Reweighted by §2.5b**:
the `fdroid` variant is a developer convenience, not a distribution channel.

### 4.1 ⚠️ Licensing — this is a budgeted cost, not a footnote

| Project | Licence | Can we use it? |
|---|---|---|
| **yt-dlp** | **Unlicense (public domain)** | ⭐ **Yes — port freely.** Our legally clean protocol reference and the single most valuable artifact available |
| `adblocker_webview` / `adblocker_core` | BSD-3-Clause | Yes — licence-clean Dart starting point, but toy quality; expect to replace parser and injection layer |
| `media_kit` | MIT | Yes — direct use |
| Media3 / ExoPlayer | Apache-2.0 | Yes — direct use |
| **NewPipe / NewPipeExtractor** | **GPL-3.0** | ⛔ **Read, do not copy.** Copyleft contaminates a proprietary Play app. We reimplement from observed wire behaviour |
| **HaGeZi block/host lists** | **GPL-3.0** | ⛔ **Must not be bundled in a proprietary APK.** Its licence says: *"Check the license in the repository before redistributing the lists as part of your own product or service."* We self-compile our own list and publish the output under our own licence, or fetch at runtime with a lawyer's opinion. `ips/doh.txt` may still be shipped as a *detector* — a static IP list, not a derivative work |
| **uBlock Origin / uAssets engine** | GPL-3.0 | ⛔ Engine unusable. Filter *lists* are separately licensed — check per list |
| **AdGuard Content Blocker** | GPL-3.0 | ⛔ Architecture reference only |

**Consequence:** if we want to ship closed-source, the InnerTube client is a
**reimplementation**, not a port. Read NewPipe; port from yt-dlp. This is real,
budgetable work and it is already in the M3 estimate — but it must be *accepted*, not
discovered in month 3.

---

## 5. Milestones

### M0 — Feasibility spike (4–5 days) ⚠️ GATE
**This milestone can kill the project. Do it first, do not skip. It answers four
questions — and the first two are now the ones that matter:**

1. **Does the `ANDROID_VR` InnerTube client return a plain `url` (no `signatureCipher`,
   no SABR) and need no PO Token?** *This single fact determines whether we need a JS
   engine in the app, whether we need the whole §3.6 subsystem, and whether the project
   is tractable at all.* Capture a live request from the Oculus YouTube app before
   writing code; keep an `INNERTUBE_API_KEY` fallback wired in.
2. **Does a synthesised MPD actually play in `media_kit` / Media3, at 1080p60 and with
   Opus audio?** Video and audio arrive as separate URLs; if MPD synthesis is wrong we
   find out in week 1.
3. **Does `webview_flutter` expose main-world injection at all?** If not, Engine 1 becomes
   a custom Kotlin platform view and its estimate changes. (Note: we now *assume* a custom
   platform view, since `webview_flutter` does not expose execution worlds.)
4. **Fallback check:** on ≥2 real devices and ≥2 networks, does main-world
   fetch/XHR pruning **plus** `isInlinePlaybackNoAd: true` actually kill the pre-roll and
   avoid the punishment modal? *(This is the fallback ladder, not the main path — do not
   let it eat the spike.)*

**Exit criteria:** (1) and (2) both pass. If `android_vr` is SABR-enforced **and** the
WebView fallback is punished, **stop and re-scope** — that is a legitimate outcome, and it
costs 5 days to find out instead of 3 months.

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

### M3 — YouTube Client (2–3 weeks)
* **Strategy B (primary)** fully wired: `ANDROID_VR` client, `$fields` to never request
  ads, MPD synthesis, `media_kit` playback, search/browse/watch/playlists.
* **Remotely switchable client config from day one** — non-negotiable, per §3.2.
* Quality/audio-only selection, PiP, background audio, speed, subtitles.
* Strategy A′ (WebView fallback) behind the health score. **Heartbeat forwarding is
  deleted, not gated** — see §7 "deliberately NOT planned".
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
| R9 | DoH / hardcoded-IP bypass of the DNS filter | **High — structural, not a bug** | With no default route, QUIC (UDP/443) and DoH never enter the TUN. Bundle HaGeZi's `ips/doh.txt` (1,423 IPs, 20 KB) as a **detector**, add a **"Strict mode"** opt-in (`addRoute("9.9.9.9", 32)`, default off), and disclose honestly. See §3.3 |
| R10 | Performance / battery regression | Medium | Benchmark gate in CI; **Room + `LruCache(4096)` in Kotlin, not Dart** (§3.3); `allowFamily(AF_INET6)` to avoid a silent full-IPv6 blackout; lazy cosmetic rules |
| R11 | **SABR / UMP enforcement** — YouTube moves all clients to `application/vnd.yt-ump` | **Critical, existential** | ⚠️ **This replaced R11 as the top technical risk.** Neither `media_kit` nor Media3 can play UMP; supporting it means writing a proprietary demuxer = the whole project. Mitigation is `android_vr` (plain URLs) + a **remotely switchable client** + the `mweb`/HLS rung of the ladder. A UMP demuxer is explicitly *not* planned. NewPipe has already been forced to "work around SABR enforcement by using another player client" |
| R12 | **PO tokens unmintable / BotGuard changes** | ~~High~~ → **Low** (contingent) | Demoted by `android_vr`. Only needed if we fall back to the `web` client — and that path is SABR-locked anyway, so PO tokens are the *smaller* problem. §3.6 |
| R13 | **`android_vr` restricted by Google** (it is a Meta-distributed client) | **High** | Precedent: Google restricted `TVHTML5`; NewPipe has since deleted `ANDROID`, `IOS`, `TVHTML5`, `MWEB`. Mitigation is the **remotely switchable client config** — non-negotiable, build it day one |
| R14 | **GPL contamination** — copying NewPipe/uBO/AdGuard Content Blocker into a proprietary app | **High, legal** | §4.1. Read GPL sources; **port from yt-dlp (Unlicense)**. Reimplementation is already budgeted in M3. Decide closed-source vs GPL *before* M3 starts |
| R15 | **EU copyright exposure** — BGH 31 Jul 2025 (I ZR 131/23) remanded Axel Springer v. Eyeo back to Hamburg, holding §69c UrhG rights *"can possibly be infringed by an ad-blocker"* | **High, unquantifiable** | Not yet decided on the merits; HansOLG still pending. Note the theory is about *rendering* and would swallow reader-mode and anti-tracking too, but it does not clearly reach a native API client. **EU is a large Play market. Get counsel before launching there.** |
| R16 | **Developer verification makes sideloading impractical** (enforcement 30 Sep 2026) | **High** | §2.5b. F-Droid is a convenience, not a fallback. Makes Play compliance non-negotiable. **Action item today: verified developer account + D-U-N-S number** |
| R17 | **Private DNS (DoT) silently kills the VPN** | Medium | Blocking onboarding step to switch to Automatic; detect custom hostname at VPN start |
| R18 | **IPv6 leak** | Medium | Sinkhole or explicitly block + disclose; U22 self-test must cover IPv6 |
| R19 | **Poisoned Rule Kit ⇒ universal XSS + VPN bypass** | **Critical** | Pinned key in APK, verify-then-parse, monotonic version, fail-closed atomic swap, declarative-only kits, selector allowlist, hard limits, hash-pinned upstreams |
| R20 | **Compromised CDN account** | High | Signing key separated from deploy credential, MFA/hardware key, public log of issued kits, in-APK fallback kit so a takedown degrades instead of bricking |
| R21 | **User data breach** (stolen device / backup) | High | Encrypted history, `allowBackup=false`, auto-wipe option, least-privilege Data Safety |
| R22 | **Minimum Functionality / webview spam rejection** | Medium | Engine 1 must be a genuinely full browser; de-brand from YouTube chrome |
| R23 | **Only one VpnService may be active** | Medium | Document that CleanTube conflicts with banking/MDM/corporate VPNs; per-app exclusion as the escape hatch; work-profile warning |
| R24 | **`flutter_vpn_service` (or any pub.dev bridge) fails in production** | **High** | The trap package instantiates `VpnService` as a plain plugin object with **no `startForegroundService`, no `onStartCommand`, no notification** — Android kills it and the TUN dies with the Flutter engine. `prepareVpn` only *checks* consent, never *launches* it. And it has **no `addDnsServer`, no `addDisallowedApplication`, no `allowFamily`**. **Own the implementation.** §3.3 |
| R25 | **HaGeZi is GPL-3.0 — bundling it contaminates the app** | **High, legal** | The v2 draft listed HaGeZi as a build-time source. Its licence says to check before redistributing. Self-compile our own list from permissive inputs and publish the output under our own licence, or fetch at runtime with a lawyer's opinion. §3.3, §4.1 |
| R26 | **Silent IPv6 blackout** | Medium | `Builder.allowFamily(AF_INET)` + `allowFamily(AF_INET6)` are **mandatory**. If you add no address/route/DNS for a family, that family is blocked entirely. Building only the IPv4 TEST-NET subnet on an IPv6 network kills all IPv6 and looks like "the app broke my phone" |
| R27 | **`establish()` returns `null`; `onRevoke()` semantics** | Medium | Always null-check the Intent result. `onRevoke()` may not run on the main thread and the replacement interface is already routing — tear down, never flush; surface a resume CTA rather than auto-retry (this is how apps get force-stopped) |

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
| U6 | **DoH/QUIC bypass *detector*** (ship HaGeZi `ips/doh.txt`, 20 KB) | Apps with their own resolver never touch our fake DNS. Warn rather than pretend. Detection is honest, cheap, and expected — see §3.3 and R9 |

### Tier 2 — Competitive differentiation
| # | Upgrade | Why |
|---|---|---|
| U7 | **SponsorBlock integration** (public API + downloadable DB) | Legit, open, immediately valuable: skips sponsor reads, intros, outros, self-promo. Strong SEO, no legal risk |
| U8 | **Filter editor with live tester** (uBO-style "test this page") | Turns a consumer app into a *tool*. Must sandbox untrusted rules — the engine limits from §3.4 apply here |
| U9 | ~~Encrypted/obfuscated rule kits~~ → **delete** | Not a security control; contradicts U20; false confidence |
| U10 | **Community rule marketplace + reputation** | Network effect + content pipeline. Signed-curator promotion only, no auto-execution of community kits |
| U11 | **Breakage radar / canary fleet** | Opt-in devices probe a known playlist; aggregate suppression rate → we learn breakage before users report it. Separate opt-in, plain-language disclosure |
| U12 | **Statistics dashboard** (ads blocked, by site/category) | Retention. Best engagement hook in an ad blocker |
| U13 | **PiP + background audio** | Table-stakes for a YouTube app. ⚠️ Never market as "background YouTube playback" — that phrasing is itself a policy tripwire |

### Tier 3 — Expansion
| # | Upgrade | Why |
|---|---|---|
| U14 | **Android TV / Leanback app** | WebView on TV + ad-free YouTube on the biggest screen. Genuinely underserved |
| U15 | **iOS phase 2** (Safari content blocker + `NEDNSProxyProvider`) | Real, but honest scope: iOS can *never* match Android. Sell as "browsing ad blocker", not "YouTube ad blocker" |
| U16 | **Quick Settings tile + Wear OS complication** | The toggle is a daily action; make it one tap |
| U17 | **Kids mode / YouTube Restricted integration** | Strong parent use case, strong retention, differentiator |
| U18 | **Config sync across devices** (own relay, E2E-encrypted) | Settings + custom rules follow the user. Needs a published protocol and minimal metadata, or cut it |
| U19 | **On-device ML classifier for unknown ad elements** | Long-term answer to cosmetic-rules rot: classify unknown elements that look like ads. Train on breakage reports |

### Tier 4 — Hardening / trust
| # | Upgrade | Why |
|---|---|---|
| U20 | **Privacy audit dashboard** (per-site tracker/ad log, no data leaves device) | A privacy product must be inspectable. This is the trust feature |
| U21 | **Open rule format + public ruleset repo** | Transparency; users can audit exactly what we block |
| U22 | **Bring-your-own blocklist source** | Power users and researchers |
| U23 | **DNS + IPv6 leak self-test** | Proves the VPN works. **Ship-blocking, not Tier 4** — must cover IPv6, not just IPv4 |
| U24 | **Release automation** (CI → internal track → staged rollout) | Weekly maintenance requires one-command releases |
| U25 | **Foldable/tablet/Chromebook layouts** | Free reach from the same codebase |

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
