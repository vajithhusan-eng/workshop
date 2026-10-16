# CleanTube — documentation

The documentation set for CleanTube. Every document has one concern; the
project's other top-level Markdown files are indexed here too.

| Document | Concern |
|---|---|
| [`../README.md`](../README.md) | What CleanTube is, the "don't ask for ads" premise, the three engines, licensing, blockers |
| [`../AGENTS.md`](../AGENTS.md) | Instructions for building it: locked decisions, scope-out list, traps |
| [`../PLAN.md`](../PLAN.md) | **The plan of record.** 68 KB, source-verified, supersedes all earlier drafts |
| [`../STATE.md`](../STATE.md) | Verified status — currently "design only, zero code" |
| [`../CHANGELOG.md`](../CHANGELOG.md) | What changed, by commit, newest first |

## `PLAN.md` is the only design document

There is no second design doc and there should not be one. `STATE.md` is derived
from `PLAN.md` and from `git`; if the plan changes, `PLAN.md` changes.

Read it in this order:

| Section | Why |
|---|---|
| §0 TL;DR, §2 The hard truth | The premise, and every method that is impossible on a non-rooted phone |
| §2.5 / §2.5b | The Play Store problem and the closing 30 Sep 2026 escape hatch |
| §3 Architecture | The three engines, the rule engine and the OTA Rule Kit |
| §4.1 Licensing | The GPL boundary that shapes engine 2 |
| §5 Milestones | **M0 is a gate** — it can cancel the project |
| §9 Open questions | What is still waiting on a human decision |

## Where the design record lives

| Topic | Read |
|---|---|
| Why ads cannot simply be blocked on a non-rooted phone | `PLAN.md` §2.1–§2.4 |
| Why `addDocumentStartJavaScript` looks like it works and does not | `PLAN.md` §3.2 |
| Why the InnerTube client must be remotable/swappable at runtime | `PLAN.md` §3.2 (NewPipe lost `ANDROID`, `IOS`, `TVHTML5`) |
| Why engine 3 can never ship on Play | `PLAN.md` §3.3 |
| Why the signed Rule Kit exists | `PLAN.md` §3.4 |

## Known internal contradictions (recorded, not silently fixed)

1. **§10 "Immediate next step" is stale.** It frames M0 around the WebView and
   Strategy A; §3.2 supersedes that with the native InnerTube client as primary.
   Where they disagree, §3.2 wins.
2. **§3.1 still offers `inappwebview`'s `contentWorld`**, but §4 commits to a
   custom Kotlin platform bridge. §4 is the decision.
3. `PLAN.md` names files that will never exist under those names.

Recorded here rather than edited out, because `PLAN.md` is a ratified design
document and divergences are information.
