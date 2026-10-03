# OMNIVEST — frontend

Flutter web client for the OMNIVEST backend. Five tabs, deliberately ordered by
what the user actually needs, not by what the software can do.

| Tab | Question it answers |
|---|---|
| **87.7%** | Why should I trust this app at all? |
| **Today** | What happened that I should look at? |
| **Autopsy** | Is this signal real or did I just search hard enough to find it? |
| **Orders** | What did my execution style cost me? |
| **Journal** | What did I actually decide, and why? |

**Learn** is a pushed route off the app bar rather than a sixth tab. Six
`NavigationBar` destinations exceed the Material specification, and "what do I
do today" and "what did the books say" are different questions.

The app opens on the **87.7%** screen. A tool that opens on a feature list has
already lost the argument it exists to make.

## Run it

```bash
cd backend && ./.venv/bin/python run.py     # API on :8123
cd frontend && flutter run -d web-server --web-port=8081 --release
```

The backend must be running. If it is not, the shell shows an offline banner
with a Retry button rather than spinning forever — the remedy is part of the
error.

Point the client at a different API without editing code:

```bash
flutter run -d web-server --dart-define=OMNIVEST_API=http://10.0.0.5:8123/api
```

## Tests

```bash
make test-frontend    # flutter analyze + flutter test
```

Two groups matter more than the rest:

- **Verdict legibility.** Severity is carried by an explicit word, never by
  colour alone — roughly one in twelve men cannot reliably separate the red and
  green this app uses. A verdict that only differs by hue is a bug.
- **Wire contract.** `package:http`'s own `MockClient` asserts the frontend
  sends the keys the backend actually accepts, and that optional fields are
  *omitted* rather than sent as `null`. This pair has drifted once, silently,
  and the backend now sets `extra="forbid"` everywhere so it cannot drift
  quietly again.

## Conventions

- Nothing throws into a widget. `api.dart` returns `Result<T>`; the UI renders
  the failure with its remedy.
- Every number carries its source. A figure with no provenance is how people end
  up trading on a blog post.
- Missing data never renders as reassuring. An unmeasured order is `NEUTRAL`
  with `basis: unavailable` — never counted as patience.