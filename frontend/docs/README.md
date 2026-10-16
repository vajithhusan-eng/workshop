# OMNIVEST frontend — documentation

The documentation set for the Flutter web client. Every document has one concern;
the project's other top-level Markdown files are indexed here too.

| Document | Concern |
|---|---|
| [`../README.md`](../README.md) | The product framing — what each tab answers, and the three UI rules |
| [`../AGENTS.md`](../AGENTS.md) | Instructions for changing the code: locked decisions, conventions, traps |
| [`../STATE.md`](../STATE.md) | Verified build status — regenerated, never hand-written |
| [`../CHANGELOG.md`](../CHANGELOG.md) | What changed, by commit, newest first |

## Where the real design record lives

There is no `PLAN.md`. The decisions worth knowing are documented at the point of
code, because that is where they can go wrong:

| Topic | Read |
|---|---|
| The HTTP boundary, error taxonomy, retryability | `lib/api.dart` |
| The tab set and what each answers | `README.md` table |
| Why a 200 with no bars is empty rather than an error | `test/chart_test.dart` |
| Why conditional imports select the chart engine | `lib/chart/tradingview.dart` |
| The terminal look (colour, spacing, typography) | `lib/theme/terminal.dart` |

## Related

- The service this client calls: [`../backend/`](../backend/) — its README
  documents the 31 routes and the SAFE-mode guardrails the UI must respect.
- If you add a document here, put it in the table above.
  `scripts/verify_projects.py` fails the build when a top-level Markdown file is
  not named in this index.
