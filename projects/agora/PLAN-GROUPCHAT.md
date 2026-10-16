# Agora — Multi-Agent Groupchat Plan (relay + round-robin council)

Status: PROPOSED · Date: 2026-09-30 · Base commit: `639cde5`

---

## 0. What the user asked for

> "connect multiple agents in a groupchat for agents using web URL of the agents,
> pass each others message to each other"

N agents (ChatGPT / Gemini / DeepSeek / Claude…), each in its own real Chrome tab driven
by its web URL, participating in **one shared conversation** where every agent sees the
others' messages and replies to them.

## 1. Locked decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | **Round-robin broadcast.** Every participant receives the full tagged transcript and replies in turn. Leader may force a specific agent to speak. No @-mention protocol. | True groupchat. A scalar `invite.agent` field cannot express N-way conversation. |
| D2 | **Full tagged transcript** per turn. | Agents must be able to address each other by name. Cheap enough at real web context sizes; `delta` is available as an option. |
| D3 | **Real-browser transport.** One Chrome tab per agent, user's own logged-in profile. No API mode in this slice. | User's stated requirement; existing adapter + CDP layers already do this. |
| D4 | **Vertical slice first**: tab pool → relay → orchestrator → storage, proven e2e against the mock AI site, **before** any UI. | The hard part is the engine. UI on top of an unproven engine is wasted work. |

## 2. Current state — honest inventory

**Built and proven (against real Chrome, 42/42 e2e green):**
CDP client · Chrome launcher with dedicated `~/.config/agora/chrome-profile` · `WebAgentAdapter`
(drives any site by URL, verbatim capture: raw text + HTML + screenshot + hash) · JS page
kernel (pierces shadow DOM, survives redesigns) · `CouncilProtocol` parser (24 tests) ·
mock AI site fixture · drift schema.

**Missing — and this is the whole feature:**

| Missing | Consequence |
|---|---|
| No tab pool. `Target.createTarget` exists only in `tool/`, zero times in `lib/`. | Cannot open a tab per agent. **Nothing else can start.** |
| No turn queue / speaker selection | Nothing decides who speaks; no serialization |
| No relay / prompt compiler | A's answer cannot become part of B's prompt |
| No orchestrator, budgets, stop conditions | Nothing prevents an unbounded run |
| No `invites` table | Transcript has no *edges* — "Gemini replied to ChatGPT" is unrepresentable |
| Zero UI. `main.dart` is a 16-line stub. | Nothing visible. |

## 3. Design constraints that MUST be respected

Discovered by exploration, not documented anywhere:

1. `WebAgentAdapter` has **no internal concurrency guard**. A second `send()` during
   `awaitCompletion()` clobbers `_answerBaseline`/`_sentAt`. → **All calls per adapter
   instance are serialized by the caller.**
2. `AgentAdapter.tokens` emits **full cumulative text**, not deltas. Consumers snapshot-replace.
3. `awaitCompletion()` returning ≠ success — it also returns on timeout and on interrupt.
4. `AdapterConfig` is `final` in `WebAgentAdapter` → hot-reload requires **rebuilding adapters**.
5. `adapter.close()` neither detaches the CDP session nor closes the tab. **The pool owns the tab.**
6. `Page.bringToFront` / `Emulation.setFocusEmulationEnabled` are **absent** → background tabs get
   timer-throttled, distorting `awaitPromise` evaluates and streaming detection. Must be added.
7. All agents share **one cookie jar and one `--user-data-dir`** (no `Target.createBrowserContext`).
   Logins and rate-limit state are *not* per-agent.
8. `_waitForComposer` **swallows its timeout** → `send()` can proceed against a page with no composer.
9. `AgentPhase.blocked` fires **only** from `connect()` → a mid-turn CAPTCHA looks like a timeout.
10. `_lastFence` accepts an **unterminated** fence; `status` is **not** validated.

---

## 4. Task A — Tab & session pool *(foundation; everything depends on it)*

**New file:** `lib/core/cdp/tab_pool.dart`

The sandbox harness's header records a hard-won lesson: *attach/detach churn on every call
invalidated another adapter's flattened session ("Session with given id not found")*.
`tool/sandbox_smoke.dart` currently creates **two** sessions per tab (its own cache **and**
the adapter's). The pool removes that class of bug permanently.

**Decision — the pool is the SOLE owner of attach/detach. `WebAgentAdapter` stops
self-attaching and receives an injected `sessionId`.** Migration cost is small and surgical:

```dart
// web_agent_adapter.dart — additive, backwards compatible
WebAgentAdapter({
  required AdapterConfig config,
  required CdpClient client,
  required String targetId,
  String? sessionId,          // NEW: if supplied, connect() skips attachToTarget
  DateTime Function()? clock,
});

// connect(): if (_sessionId != null) { /* skip attach, still Page.enable/Runtime.enable */ }
```

```dart
class TabPool {
  TabPool({required CdpClient client, int maxLiveTabs = 8});

  Future<TabHandle> acquire(AdapterConfig config);   // create-or-reuse a tab for this kind
  Future<void> release(String targetId);             // refcount--; keep warm
  Future<void> closeIdle(Duration ttl);              // evict warm tabs past ttl
  Future<void> closeAll();
  int get liveTabs;
}

class TabHandle {
  final String targetId;
  final String sessionId;      // the ONE session for this tab, reused by everyone
}
```

**Anti-throttle:** on acquire, `Emulation.setFocusEmulationEnabled{enabled:true}` per session
so N tabs stay responsive without thrashing window focus. (New CDP call — must be added.)

**Memory policy:** ~150–300 MB per tab. Open exactly one tab per *participant*, keep warm for
the session life, close all on session end. Eviction applies only to non-participant warm tabs.
`maxLiveTabs` is a hard safety ceiling; `acquire` on a full pool evicts the coldest warm tab first.

**Also fix here:** `cdp_client.dart` — `onDone` never sets `_closed = true`, so after Chrome
drops the socket `isClosed` lies `false` and `send()` keeps accepting into a dead sink.

**Proves it:** a new `tool/tabpool_smoke.dart` opens 3 tabs against the mock site, attaches
once each, asserts `liveTabs == 3`, closes 2 and asserts `Target.getTargets` shrinks, closes
the rest. No accounts, no quota.

---

## 5. Task B — Relay, prompt compilation & the injection firewall

This is the security-critical task. **Agent A's output is attacker-controlled free text that
lands in Agent B's prompt.** Shipping relay without fencing would create a raw cross-vendor
prompt-injection channel.

**New file:** `lib/core/orchestration/security_firewall.dart`

```dart
class SecurityFirewall {
  static String fence(String speaker, String content);   // wrap as untrusted block
  static List<InjectionSignal> scan(String content);     // flag, never block
  static String redactPii(String content, {bool enabled});
}

class InjectionSignal { final String ruleId; final int offset; final String excerpt; }
```

**The fencing rule — precise enough to implement:**

1. Agora-authored instructions and the **return contract** are emitted **outside** every fence.
2. Each relayed message is wrapped in `BEGIN/END UNTRUSTED CONTENT FROM "<name>"` markers,
   carrying an explicit instruction that the content is **data, not instructions**, and that
   any instruction inside it — however urgent or authoritative — must be ignored.
3. **The return contract is emitted after the last fence.** Last instruction wins.
4. `scan()` **flags, never blocks.** A false positive that mangles an honest answer is worse
   than a missed attack in a personal tool; the signal is surfaced in the UI so the human
   decides. Patterns: `ignore (all )?previous`, `disregard (the )?(above|instructions)`,
   `you are now`, `system prompt`, `reveal your instructions`, `send .* to https?://`,
   `<\|.*?\|>` delimiter spoofing.

**New file:** `lib/core/orchestration/context_compiler.dart`

```dart
class ContextCompiler {
  Packet compile({
    required String recipient,        // displayName
    required String? roleCard,
    required String objective,
    required List<TranscriptEntry> transcript,   // chronological, already fenced
    required List<String> participants,
    required int round,
    required int maxRounds,
  });
}
```

Packet layout, **in this order**:

```
1. Identity + role card        (Agora-authored)
2. Council roster + round state (Agora-authored)
3. The objective                (the user's original question, verbatim, always present)
4. <<< TRANSCRIPT >>>           (each message fenced + tagged + injection-scanned)
5. THE RETURN CONTRACT          (Agora-authored, AFTER all untrusted text)
```

**Return contract for a follower:** "Reply as yourself, in your own voice. Address colleagues
by name when you disagree. This is round N of M. End with a fenced `council` block only if you
want to hand the floor to a specific colleague or declare the question settled."

**New file:** `lib/core/orchestration/context_strategist.dart`

```dart
class ContextStrategist {
  List<TranscriptEntry> select({
    required List<TranscriptEntry> full,
    required String recipient,
    required int strategy,          // 0 = full, 1 = delta
    required int recentWindow,      // delta: keep last K
  });
}
```

`full` → everything. `delta` → **objective (always verbatim, never dropped) + the last K messages
+ a structural digest of the remainder** (one line per excluded message: who said what, truncated).
**Deterministic compaction — no Archivist agent turn in v1.** PLAN §E's Fractal Memory stays a
later upgrade; spending a real agent turn to summarize would double turn cost.

**Proves it:** unit tests — (a) a hostile message from A appears inside a fence with the return
contract *after* it; (b) `scan()` flags `ignore all previous instructions` and `you are now`;
(c) `select(strategy: delta)` never drops the objective and never exceeds the window.

---

## 6. Task C — Speaker selection

**New file:** `lib/core/orchestration/speaker_selector.dart`

```dart
class SpeakerSelector {
  SpeakerSelector({required List<Participant> participants});
  String? next({String? forced});        // forced = leader override, else round-robin on sortOrder
  void skip(String kind);                // blocked/disabled/logged-out agent
  void rejoin(String kind);
  int get cursor;
}
```

Round-robin over `SessionAgents.sortOrder`, skipping agents marked `login_required` / `disabled` /
in error. `forced` bypasses the cursor for exactly one turn. A live cursor lets the UI render
the "◐ deepseek busy" indicator PLAN §11 promises.

---

## 7. Task D — Orchestrator

**New file:** `lib/core/orchestration/agent_runtime.dart`

Wraps one `AgentAdapter` and enforces constraint #1 — a `Future` chain as a mutex:

```dart
class AgentRuntime {
  AgentRuntime({required AgentAdapter adapter, required String agentId});
  Future<T> serialize<T>(Future<T> Function() op);   // per-instance mutex
  Stream<AgentStatus> get statuses;
  Stream<String> get tokens;
  Future<void> dispose();
}
```

**New file:** `lib/core/orchestration/orchestrator.dart`

Phases (extends PLAN §9):

```
IDLE → OPENING → TURN → WAITING → STORING → (TURN | CONSENSUS) → FINALIZE
                                        ↓            ↓
                                      BLOCKED ← RETRY(≤2) ← transport error
```

Transitions:

| From | Event | To |
|---|---|---|
| `IDLE` | `start(prompt)` | `OPENING` |
| `OPENING` | all participants ready | `TURN` |
| `OPENING` | any participant `!isReady` | `BLOCKED` |
| `TURN` | packet sent | `WAITING` |
| `WAITING` | `awaitCompletion` returned | `STORING` |
| `STORING` | message persisted | `TURN` (next speaker) |
| `TURN` | `awaitCompletion` threw | `RETRY` (≤2, same agent, same round) |
| `RETRY` | 2nd consecutive failure | `BLOCKED` |
| `WAITING` | mid-turn login/captcha/rate-limit detected | `BLOCKED` |
| any | round > `maxRounds` | `FINALIZE(stopped: roundCap)` |
| any | elapsed > `budgetSeconds` | `FINALIZE(stopped: budget)` |
| `TURN` | stagnation detected | `FINALIZE(stopped: stagnant)` |
| any | `decide{status:solved}` | `FINALIZE(stopped: solved)` |
| any | user interrupt | `FINALIZE(stopped: user)` |

**Every turn is `await`ed. Nothing runs concurrently.** This is the single most important
property: it is what makes `awaitCompletion` correct at all (constraint #1).

**Mid-turn blocked detection** (fixes #9): after each `awaitCompletion`, if the transcript did not
grow past `timeoutMs/2` and no content arrived, re-probe `checkLogin()` rather than reporting a
generic timeout — a mid-run CAPTCHA is a login problem, not a hang.

**Proves it:** `test/orchestrator_test.dart` with `FakeAgentAdapter` — one test per stop
condition, one for round-robin order, one for leader override, one asserting no two adapters are
ever in-flight simultaneously.

---

## 8. Task E — Storage

**Modify** `lib/data/database.dart`, **regenerate** `database.g.dart` with
`dart run build_runner build` (keep `drift_dev 2.35.0` + `build_runner 2.16.x` — older
`drift_dev` hard-crashes codegen on Dart 3.10).

| Change | Detail |
|---|---|
| **NEW `Invites` table** | `id, sessionId, round, fromAgentId, toAgentId, task, expect, contextRef, dispatchedAt, returnedAt, status` — the missing edge in the transcript |
| `messages` += `seq` | monotonic per-session ordering; `createdAt` alone cannot order same-ms inserts |
| `messages` += `kind` | `'user' \| 'agent' \| 'invite' \| 'system' \| 'packet'` |
| `messages` += `replyToMessageId` | makes "Gemini replied to ChatGPT" a first-class query |
| `messages` += `prevHash`, `chainHash` | PLAN §C3 hash chain — currently a **promise with no implementation** |
| `agents` += `tabId`, `loginOk` | binds a runtime tab to a DB row; currently no such binding exists |
| `sessions` += `archived` | in PLAN §7, absent from the schema |
| Foreign keys | **ZERO exist today.** Add with `onDelete: cascade` |
| Indexes | `messages(sessionId, seq)`, `messages(sessionId, round)`, `session_agents(sessionId)`, unique `agents(kind)` |
| **Hash chain** | `chainHash = sha256(prevChain + contentHash(rawText)).substring(0,32)` — makes reordering, deletion and insertion detectable, not just in-place mutation |
| `schemaVersion 1 → 2` | ⚠️ `MigrationStrategy` has **only `onCreate`** — there is **no `onUpgrade`**. This is breaking and must land before any real data exists. Acceptable now; flagged as a debt. |
| Consolidate `contentHash` | **duplicated** in `hashing.dart:13` and `database.dart:17`. One implementation. |

**New file:** `lib/data/repository.dart` — all inserts, `watchMessages(sessionId)`,
`watchSession`, transaction-wrapped turn persistence. Today there are **no inserts and no watch
streams**, so a UI would re-query every frame.

**New file:** `lib/data/vault.dart` — writes `Verbatim.screenshotBytes` (`Uint8List`) to disk via
the existing `AgoraPaths.vaultDir`, populating `messages.screenshotPath`.

---

## 9. Task F — Test strategy

No mocking library is declared and `integration_test` is absent. Rather than add dependencies,
hand-roll:

**New:** `test/support/fake_agent_adapter.dart`
`FakeAgentAdapter implements AgentAdapter` — scripted replies per prompt, optional
`delay`, fault injection (`throwOnSend`, `throwOnComplete`, `neverCompletes`), records
`sendLog` and enforces the same serialization invariant as the real one (so a test that
violates it fails loudly).

**Tests that matter most:**

| Test | Guards |
|---|---|
| one per stop condition (6 total) | §9's "always safe, never hangs" |
| round-robin order + leader override | `SpeakerSelector` |
| **A's injected text cannot steer B** | `ContextCompiler` + firewall |
| no two adapters in flight | the mutex |
| `delta` never drops the objective | context pressure |
| chain hash detects reorder/deletion | verbatim guarantee C3 |
| DB: relay persists as an `invite` + `replyToMessageId` | storage |
| (e2e, `tool/`) 2 agents relay through the mock site | the real loop |

Keep `flutter test` (fast, no Chrome) for unit/integration; keep `tool/*_smoke.dart` for
real-Chrome e2e. Both are load-bearing in this repo — the 42/42 sandbox suite is the precedent.

---

## 10. Task G — Sequencing

Waves are chosen so that **no two tasks in a wave touch the same file.**

**Wave 1 — independent, fully parallel**
| # | Task | Files | Touches |
|---|---|---|---|
| T1 | TabPool + fix `cdp_client` `_closed` + `WebAgentAdapter` injected sessionId | `tab_pool.dart`(new), `cdp_client.dart`, `web_agent_adapter.dart` | CDP/adapter |
| T2 | SecurityFirewall + ContextStrategist + ContextCompiler | 3 new files under `orchestration/` | pure logic |
| T3 | Schema v2 + Repository + Vault + `build_runner` | `database.dart`, `database.g.dart`, `repository.dart`, `vault.dart`, `hashing.dart` | data |
| T4 | SpeakerSelector + FakeAgentAdapter | 2 new files, no deps | pure logic |

**Wave 2 — parallel, all depend on Wave 1**
| # | Task | Depends on |
|---|---|---|
| T5 | `AgentRuntime` (mutex) | T1 |
| T6 | `Orchestrator` state machine | T2, T4, T5 |

**Wave 3 — sequential**
| # | Task | Depends on |
|---|---|---|
| T7 | `test/orchestrator_test.dart` — full suite | T6 |
| T8 | `tool/groupchat_smoke.dart` — 2 real agents relaying through the mock site | T7 |

**Wave 4 — only after the engine is green**
| # | Task |
|---|---|
| T9 | Riverpod providers + `ProviderScope` + transcript/council-panel UI + real adapter JSON in `assets/adapters/` |

**Conflict notes:** T1 and T3 both touch generated/lockfile-adjacent concerns but no shared
source file. T3 alone runs `build_runner`; T1 must not. T5 and T6 must not run concurrently —
T6 imports T5's class.

---

## 11. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| **Cross-agent prompt injection** — A's text steers B | **HIGH** | Firewall fences every relay; return contract last; scan flags for the human. Ships *with* the relay, not after. |
| **Background-tab throttling** — >1 tab, timers throttled, streaming detection breaks, `awaitCompletion` hangs | **HIGH** | `Emulation.setFocusEmulationEnabled` per session in TabPool (Task A). Validate in `tabpool_smoke` with 3 concurrent tabs before building higher. |
| **Double-attach** — two sessions per tab breaks other adapters | **HIGH** | Pool is sole owner; adapter takes injected `sessionId`. |
| **DOM churn** — a site redesign breaks an adapter mid-council | HIGH | Config-driven selectors + `diagnose()` + healer already exist; `needsRepair` now maps to a real BLOCKED state. |
| **No `onUpgrade`** — any schema change is breaking | MED | Land schema v2 **before** real data exists. Then add a real migration strategy. |
| **One cookie jar** — all agents share a profile; rate limits are shared | MED | Accept it; surface `UsageCounters` (already a table, zero writers) and make the cap visible. |
| **Turn cost** — N agents × M rounds = N·M web turns | MED | `maxRounds` default 12, wall-clock budget 1800s, stagnation detector. Hard stops are mandatory, not optional. |
| **ToS / account risk** — automating chat UIs | HIGH | Out of scope to fix; human-paced, single profile, no parallelism. User's informed call. |
| **`awaitCompletion` lies on timeout** | MED | Orchestrator re-probes login rather than trusting the return. |

## 12. Flags on the existing design

1. **`AgentStatus.progress` is never set** — always 0. Dead field; either wire it or delete it.
2. **`AdapterConfig.copyWith` is incomplete** — cannot change `kind`, `color`, `sendWithEnter`,
   `newChatUrl`, `modelPicker`, `knownModels`. A silent trap.
3. **`AdapterRegistry.upsert` cannot override a bundled adapter in-memory** (precedence 200 > 100)
   but wins after restart. Deliberate-looking, almost certainly not.
4. **`WebAgentAdapter.send()` error hint names `send_with_enter`; the real key is `sendWithEnter`.**
5. **`send()` has no `Input.*` fallback** — all typing is JS-synthetic and will fail on any site
   checking `isTrusted`. `Input.insertText` is proven working in `cdp_smoke` but unused in `lib/`.
6. **`chrome_log` / `agora_log` paths exist but nothing writes files** — `Logger` is memory-only,
   and `debugEnabled` defaults **true**, so every `send()` result is JSON-encoded and logged.
7. **`shutdown(closeBrowser: true)` closes Chrome it did not launch** — `alreadyRunning` is
   recorded and then ignored.
8. **No `invites` table and no `seq`** despite being in PLAN §7 — the transcript currently
   cannot represent conversation structure at all.

## 13. Definition of done for this slice

- [ ] `TabPool` opens/closes/reuses N tabs; 3-tab concurrency proven against the mock site
- [ ] 2 agents exchange at least 2 rounds of relayed messages through real Chrome + mock site
- [ ] Every relay is fenced; an injection attempt is flagged and cannot alter B's contract
- [ ] All 6 stop conditions terminate cleanly; nothing hangs
- [ ] Transcript persisted with ordering, `replyToMessageId`, and a verifiable hash chain
- [ ] `flutter test` green with no Chrome; `tool/groupchat_smoke.dart` green with Chrome