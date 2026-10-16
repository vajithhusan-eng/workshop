# Changelog

All changes to OMNIVEST that touched `frontend/`, newest first. Entries quote the
commits that modified this directory; the short hash is the commit that carried
them.

## 2026-10-17 — documentation standard

- `32db69f` wip(frontend): terminal/omnivest screens and their tests
- Added `AGENTS.md`, `STATE.md`, `docs/README.md` and this changelog to meet
  `PROJECT-STANDARD.md`. `README.md` predated the standard and already satisfied
  it, so it was left untouched. No product code changed.

## 2026-10-06

- `ce31de1` feat(agora): live real-site check tool, page text dumper, vision note

## 2026-10-03

- `22e9309` test(agora): drop a stale hide clause that named members drift/native does not export
- `eafcc88` feat(omnivest): Flutter client — 5 tabs, verdict legibility, wire-contract tests
- `ceb4a49` feat(agora): mount the Flutter UI - three-pane council room, composer with @-routing, calibration studio, decision record, settings
- `e46e5a2` chore(omnivest): protect in-progress frontend from a parallel git clean

## 2026-09-30

- `1472cfe` feat(omnivest): backend FastAPI MVP + Flutter 5-tab frontend

### Notable at first release

- Five tabs ordered by user need; Learn is a pushed route rather than a sixth tab.
- Transport failures, 422s and empty responses each get their own distinct,
  non-reassuring rendering; the wire contract is pinned by tests.
