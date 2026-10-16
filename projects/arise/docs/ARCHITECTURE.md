# Arise — Architecture, Modules & Data Models

> How Arise is built: modules, layering, entities, the pure domain engines, and
> the storage/routing/notification decisions. Read with `docs/ROADMAP.md` (the
> plan of record) and `docs/FEATURE-SPEC.md` (behaviour).

---

## 1. Principles

1. **Offline-only.** There is **no network layer at all** — no Dio, no http, no
   sync, no analytics phone-home. This is a red line (`AGENTS.md`), not a phase.
2. **Feature-first, light Clean Architecture.** Each feature is a vertical slice
   with `domain/` (pure Dart, no Flutter/DB imports), `data/` (storage impl), and
   `presentation/` (widgets + providers). Dependency direction points inward.
3. **The domain is portable and pure.** The engines (XP, level, rank, streak)
   import only `dart:*`. They can run in a CLI with no Flutter. They are the
   most-tested code in the app.
4. **Append-only XP ledger.** Progress is an ordered event log, not just a
   running total. History is never destroyed by recomputation — this is what
   makes v7+ analytics and v8+ prestige possible without a rewrite.
5. **Storage behind an interface.** UI never touches the database. A repository
   contract in `domain/`, a Drift implementation in `data/`. v2+ can extend the
   schema, or swap storage, without touching the UI.
6. **All System copy in one catalog.** Enforced so the ethics rules stay
   reviewable (`UI-UX-HUD.md` §9).
7. **v1 must not preclude v2–v20** (`AGENTS.md` locked decision 6).

## 2. Layered structure

```
lib/
├── main.dart
├── app/
│   ├── app.dart              # MaterialApp.router, theme
│   ├── router.dart           # go_router config
│   └── bootstrap.dart        # ProviderScope, DB init, notification init
├── core/
│   ├── theme/                # SystemColors/Typography/Motion/Glass (ThemeExtension)
│   ├── widgets/              # SystemWindow, SystemButton, XpBar, RankBadge, …
│   ├── copy/                 # SystemMessages — ALL System copy
│   ├── result/               # Result<T> / Failure
│   ├── time/                 # clock abstraction, local-day key
│   └── ids/                  # uuid wrapper
└── features/
    ├── onboarding/{domain,data,presentation}
    ├── quests/{domain,data,presentation}
    ├── progression/{domain,data,presentation}
    ├── streak/{domain,data,presentation}
    ├── notifications/{domain,data,presentation}
    ├── log/{domain,data,presentation}
    └── settings/{domain,data,presentation}
```

**Dependency rule:** `presentation → domain ← data`. Domain depends on nothing
from the other two. Cross-feature use goes through *domain* contracts, never
through another feature's data or presentation.

## 3. Modules (v1 vertical slices)

| Module | Responsibility | Key types |
|---|---|---|
| **onboarding** | First-run, stage assessment (TTM), permission ask, seed first quest | `OnboardingController`, `StageAssessment` |
| **quests** | Quest templates, instances, scheduling, completion | `QuestTemplate`, `QuestInstance`, `QuestRepository`, `QuestScheduler`, `CompleteQuest` |
| **progression** | XP ledger, levels, ranks | `XpEvent`, `XpLedger`, `Player`, `LevelEngine`, `RankEngine` |
| **streak** | Streaks with never-miss-twice | `Streak`, `StreakEngine` |
| **notifications** | Schedule System-window reminders | `NotificationService`, `SystemWindowPayload` |
| **log** | Daily log / chronicle | `DailyLog`, `LogRepository` |
| **settings** | Prefs, sound/motion toggles, export/import | `Settings`, `SettingsRepository` |

### Future modules (the v2–v20 arc, one slice each)

`stats` · `jobs` · `hp`/`penalty` · `dungeon` · `inventory`/`shop` · `titles` ·
`bestiary` · `analytics` · `shadow-army` · `events` · `prestige` · `guild(local)` ·
`chronicle`. **Each is a new slice plus, at most, new columns/tables — never a
rewrite.** The ledger (§1.4) and repository boundary (§1.5) are what buy this.

## 4. Data models (Dart, `freezed` + `json_serializable`)

### v1 entities

```dart
// progression
class Player {
  String id;            // uuid
  String name;
  DateTime createdAt;
  int level;            // derived cache of the ledger
  int xpTotal;          // derived cache of the ledger
  Rank rank;            // derived cache of level
  String? classId;      // v2 (job class) — nullable, unused in v1
}

class XpEvent {         // append-only ledger
  String id;
  DateTime at;
  int amount;           // may be negative (bounded penalty), never below floor
  XpSource source;      // quest | recovery | milestone | penalty | adjustment
  String? sourceId;     // quest instance id
  String reason;        // human-readable, for the log
}

// quests
enum QuestType { daily, weekly, custom }
enum QuestStatus { pending, done, skipped, failed }
enum QuestDomain { neutral, badHabit /* porn/other */ }

class QuestTemplate {
  String id;
  String title;
  String? description;
  QuestType type;
  QuestDomain domain;
  int xpValue;
  int? minMinutes;      // Two-Minute Rule floor
  int? cueMinutesOfDay; // preferred reminder time
  bool active;
}

class QuestInstance {
  String id;
  String templateId;
  String dayKey;        // "YYYY-MM-DD" local
  QuestStatus status;
  DateTime? completedAt;
  int xpAwarded;
}

// streak
class Streak {
  int current;
  int longest;
  String? lastDayKey;
  int freezesAvailable; // "never-miss-twice" shields
  int totalCompletions;
  int totalAttempts;
}

// log
class DailyLog {
  String dayKey;
  String? note;
  int questsPlanned;
  int questsDone;
}

// settings (kv)
class Settings { bool sound; bool reduceMotion; bool highContrast; ... }
```

### Future entities (declared later, columns anticipated)

`Stat` · `JobClass` · `HpEvent` · `Item` · `InventoryEntry` · `Title` ·
`Achievement` · `DungeonSession`. `Player` already carries nullable `classId`;
`XpSource` already has `penalty`/`recovery` variants.

## 5. Domain engines (pure, heavily unit-tested)

| Engine | Rule (v1) | Notes |
|---|---|---|
| **LevelEngine** | Rising-cost curve. `xpToNext(level) = base * level^exp` (start `base=100`, `exp≈1.5`), tuned so early levels are fast and later ones are earned. | Cap deferred; v1 target ~level 1–30 within months |
| **RankEngine** | Thresholds by level: E 1–9 · D 10–19 · C 20–34 · B 35–49 · A 50–69 · S 70+ | Fixed by level (Solo Leveling's ranks are fixed at awakening; we are the *legible* exception — earn every rank) |
| **StreakEngine** | **Never-miss-twice**: one missed day is tolerated (a shield/freeze); a *second consecutive* miss resets `current` to 0 — but `longest`, `totalCompletions`, `totalAttempts` are **never** lost | Directly encodes `BEHAVIOR-SCIENCE-DEEP.md` §A + Marlatt §C |
| **XpLedger** | Appends `XpEvent`s; recomputes `xpTotal`/`level`/`rank` as derived caches. Negative events floored at 0 total. | Monotonic history; never destructive |
| **QuestScheduler** | Each day, materialises `QuestInstance`s from active templates; idempotent by `(templateId, dayKey)` | Pure given a clock + templates |

All engines take a `Clock` for testability and never read the wall clock directly.

## 6. Storage — **Drift** (decided)

**Decision: Drift (SQLite).** Relational fits the event ledger, the derived
caches, and the future stats/jobs/analytics queries far better than a key-value
store; it is mature, type-safe, testable with an **in-memory** database, and
fully offline.

| Table | Rows |
|---|---|
| `players` | one row (single-user, offline) |
| `xp_events` | append-only ledger |
| `quest_templates` | definitions |
| `quest_instances` | per-day occurrences |
| `streaks` | one row |
| `daily_logs` | one per day |
| `settings_kv` | key/value prefs |

- **Migrations** via Drift's `schemaVersion` + `MigrationStrategy` — additive,
  never destructive.
- **Export/import** = serialize to a JSON artifact (the "artifact" idea from the
  arc), user-owned; the only data portability, and it needs no server.

## 7. State management — **Riverpod** (decided)

- One provider graph; `ProviderScope` at the root.
- Repository providers (`Provider`) → service/engine providers → feature
  `AsyncNotifier`s → widgets (`ConsumerWidget`).
- App-wide state (`player`, `settings`) uses `@Riverpod(keepAlive: true)`.
- **Riverpod is wiring, not business logic** — no Riverpod imports in `domain/`.

## 8. Routing — **go_router**

```
/onboarding
/                 (Status / home)
/quests
/quests/new
/quests/:id
/log
/settings
/settings/ethics
```

## 9. Notifications

- `flutter_local_notifications` + `timezone`.
- **Android 13+**: runtime `POST_NOTIFICATIONS` ask (during onboarding).
- **Android 12+**: exact alarms need `SCHEDULE_EXACT_ALARM`; fall back to
  inexact if not granted, and say so — never silently miss a cue.
- The notification is **rendered as a System window** (title = System line, body
  = quest summary); tapping deep-links to `/quests`.
- **All copy from `SystemMessages`.** Never engagement-driven, never
  guilt/fear ("you're losing your streak!") — forbidden by the 12 red lines.
  Reminders fire at the user's chosen cue time, or not at all.

## 10. Testing strategy

| Layer | Tool | What |
|---|---|---|
| Domain engines | `flutter test` (pure Dart) | Level/rank/streak/XP curve tables, never-miss-twice edge cases, scheduler idempotency |
| Data | Drift in-memory | Repository CRUD, migrations, ledger integrity |
| Widget | `flutter_test` | `SystemWindow`, `QuestCard`, completion flow, semantics labels |
| A11y | widget tests | Semantics values present; contrast tokens checked by a unit test |
| Golden | *(later)* | Visual regression on the hero components |

The real commands per milestone: **`flutter analyze`** and **`flutter test`** —
run and read the output; no green claim without it.

## 11. Decisions recorded (this phase)

| Decision | Choice | Reason |
|---|---|---|
| Package id | `com.arise.system` | Short, on-theme, unconfirmed pending trademark check |
| State management | **Riverpod** | Compile-safe DI + state; testable via provider overrides |
| Storage | **Drift** (SQLite) | Relational ledger + future queries; in-memory tests; offline |
| Routing | **go_router** | Declarative, deep-linkable for notifications |
| Notifications | `flutter_local_notifications` | Only offline-capable choice; System-window payload |
| Motion | `flutter_animate` + `CustomPainter` | Declarative; no runtime asset fetch |
| Fonts | **bundled** | Offline-only forbids `google_fonts` runtime fetch |
| Architecture | feature-first + light Clean | Domain purity, v1→v20 without rewrite |

## 12. Risks / open questions

- **Exact-alarm policy** on Android 14+ may downgrade cue precision — decide the
  fallback UX at M4.
- **Drift codegen** adds a `build_runner` step — acceptable, but keep the domain
  layer free of generated code.
- **Blur performance** on low-end Android — the high-contrast/flat fallback
  (`UI-UX-HUD.md` §7) is the mitigation; benchmark at M3.
