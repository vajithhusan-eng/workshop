# OMNIVEST frontend — project instructions

Flutter **web** client for the [OMNIVEST backend](../backend/). Five tabs ordered
by what the user needs, not by what the software can do. It shares this
repository with Agora, rgx and CleanTube and shares nothing else with them.

## Authority

- [`README.md`](README.md) — the product framing: what each tab answers, and the
  three rules the UI is built on. Read it first; it is short and it is binding.
- `STATE.md` — derived build status. Regenerate with the `project-orientation` skill.
- **There is no `PLAN.md`.** `README.md` plus the module docstrings are the record.

## Locked decisions — violating these reverses work already done

1. **The five tabs and their order are the product.** `87.7%`, Today, Autopsy,
   Orders, Journal. Learn is a pushed route, not a sixth tab. Reordering the tabs
   is a product decision, not a refactor.
2. **No failure renders as a reassuring default.** Transport failures become
   retryable errors; a 422 shows the server's message; a 200 with no bars is
   *empty*, not an error; malformed bars are dropped loudly.
3. **Missing data never looks measured.** An unmeasured order is `NEUTRAL` with
   `basis: unavailable` — never counted as patience.
4. **Every number carries its source.** A number without a provenance label does
   not ship.
5. **The wire contract is asserted, not assumed.** `test/chart_test.dart` pins the
   exact request/response shape; `api.dart` is the only place that talks HTTP.
6. **Charts are vendored.** TradingView's *lightweight-charts* is committed under
   `web/vendor/` on purpose — no CDN at runtime.

## Conventions

- Flutter web, `pubspec.yaml` package name `omnivest`, version `0.1.0`,
  SDK `>=3.3.0 <4.0.0`.
- Dependencies: `http ^1.2.0`, `web ^1.1.0`; dev `flutter_test`, `flutter_lints ^4.0.0`.
  Adding one is a decision.
- **`lib/api.dart` is the only HTTP boundary.** Parsing and error mapping live
  there; UI code never calls `http` directly.
- Conditional imports for the chart engine: `chart/tradingview.dart` selects
  `tradingview_web.dart` (web) or `tradingview_stub.dart` (other platforms).
- Lint is `flutter_lints` via `analysis_options.yaml`; `make lint` runs
  `flutter analyze`.

## Run and verify

```bash
# terminal 1 — the API this client talks to
cd backend && ./.venv/bin/python run.py

# terminal 2 — the client
cd frontend && flutter pub get && flutter run -d web-server --web-port=8081

make lint           # flutter analyze
make test-frontend  # lint + flutter test (165 tests)
```

The Flutter SDK used for these numbers is Flutter 3.47.0 / Dart 3.13.0; run
`flutter --version` to confirm yours before comparing.

## Traps

- **This is Flutter *web*.** It uses `dart:js_interop`/package:web and a vendored
  JS chart library, so it will not run on desktop or mobile targets as-is.
- **`web/vendor/lightweight-charts.standalone.production.js`** is a 180 KB
  committed blob. It is the largest tracked file in the repository; do not
  "clean it up" — replacing it means re-vendoring, not deleting.
- **The backend must be running** for anything but the pure widget tests. The
  chart tests mock `http`; a real run without `run.py` shows retryable errors,
  which is correct behaviour, not a bug.
- `test/widget_test.dart` is the Flutter template's smoke test; the product
  coverage is in `chart_test.dart`, `terminal_test.dart`, `traces_test.dart`.

## Scope

Only `frontend/`. The service it talks to is the sibling
[`backend/`](../backend/); that project has its own instructions and its own
SAFE-mode rules which this client must not contradict.
