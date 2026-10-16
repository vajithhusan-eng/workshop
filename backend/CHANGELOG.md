# Changelog

All changes to OMNIVEST that touched `backend/`, newest first. Entries are the
commits that modified this directory, quoted from `git log`; the short hash is
the commit that carried them.

Commits also touching other projects are listed once here with their full
subject, since a multi-project commit is a single change.

## 2026-10-17 — documentation standard

- Added `README.md`, `AGENTS.md`, `STATE.md`, `docs/README.md` and this changelog
  to meet `PROJECT-STANDARD.md`.
- Added `app/tests/conftest.py` with `collect_ignore = ["test_api.py"]` so a bare
  `pytest app/tests` runs the unit suite instead of collecting the live-server
  smoke test. Product code unchanged.

## 2026-10-06

- `ce31de1` feat(agora): live real-site check tool, page text dumper, vision note

## 2026-10-03

- `cb459bb` feat(agora): Calibration Studio can probe a live page - reports which selector tier actually resolved
- `22e9309` test(agora): drop a stale hide clause that named members drift/native does not export
- `b93b8a1` fix(omnivest): forbid unknown request fields so no claim is silently discarded
- `b627498` feat(omnivest): implement all 12 watch-loop rules with a drift-proof registry
- `91e6dc7` feat(agora): schema v2 - sessions.archived, onUpgrade migration, hot-query indexes; dedupe contentHash into hashing.dart
- `79f1ee3` feat(omnivest): execution forensics - price the impatience, don't ask about it

## 2026-09-30

- `e4a2d9c` feat(agora): real adapter configs for ChatGPT/Gemini/DeepSeek + registry_check tool (3/3 validate)
- `84a551c` feat(agora): adapter registry - bundled+user JSON overlay, hot-reload on config change, graceful skip of broken configs
- `639cde5` fix(agora): sandbox suite green - 42/42 e2e against real Chrome; healer restricted to typeable surfaces; login probed before demanding composer
- `a6ab401` fix(agora): CRITICAL - capture answer baseline before send click; honour screenshotOnStore; allow file:// in validate()
- `23bdc2c` feat(agora): Sandbox Lab (B6) - mock AI site fixture + full adapter e2e smoke test
- `1472cfe` feat(omnivest): backend FastAPI MVP + Flutter 5-tab frontend

### Notable at first release

- SAFE mode on by default; ratings, price targets and guaranteed-return language
  blocked at the output boundary.
- Pydantic models reject unknown fields so a typo cannot silently become a
  confident verdict on default numbers.
- The journal is a JSON file with a matching undo for every write.
