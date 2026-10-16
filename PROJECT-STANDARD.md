# WORKSHOP project standard

Every project in this workspace — `projects/*/`, `backend/`, `frontend/` — is a
self-contained product with the same skeleton, so that a person or an agent
arriving at any one of them finds the same doors in the same places.

This document is the standard. `templates/project/` holds the canonical stubs;
`scripts/new_project.py` instantiates them for a new project; `scripts/verify_projects.py`
enforces them.

```
make projects-check      # every project has the required files, headers are well-formed
make docs-check          # STATE.md pins match HEAD; no agent is defined twice
make check               # both
```

## 1. Required layout

```
<project>/
├── README.md          REQUIRED  entry point for a human
├── AGENTS.md          REQUIRED  instructions for an agent
├── STATE.md           REQUIRED  verified build status (pinned to a commit)
├── CHANGELOG.md       REQUIRED  append-only history, newest first
├── docs/
│   └── README.md      REQUIRED  index of the project's documentation
├── PLAN.md            optional  the plan of record, if the project has one
└── …                  the project's own source tree
```

**Every `*.md` at the top level must be one of the required files, or be listed in
`docs/README.md`.** A document that is not indexed does not exist as far as the
next reader is concerned. Anything longer than a screenful belongs in `docs/`.

## 2. One concern per file

| File | Answers | Must not |
|---|---|---|
| `README.md` | What is this, why does it exist, what state is it in, how do I run and test it? | Hold design detail, or duplicate `PLAN.md` |
| `AGENTS.md` | Identity, scope, locked decisions, conventions, traps, what to never do | Restate `README.md`, or report build status |
| `STATE.md` | What is verified to work, against which commit, produced by which command | Claim anything that was not actually run |
| `PLAN.md` | The design contract (`**Status:**` line required) | Be silently superseded — record the supersession |
| `docs/README.md` | Where every document lives and which one is authoritative | Be the place where the detail lives |
| `CHANGELOG.md` | What changed, when, and why it mattered | Be edited in place; entries are append-only |

Where two documents disagree, the one named authoritative in `AGENTS.md` wins, and
the disagreement is a **bug to record** — never something to silently paper over.

## 3. Required headers

**README.md** — title, then a one-line italic description, then status:

```markdown
# <Name>

*<one-line description>*

**Status:** <Active | Plan only | Archived> · <one clause of evidence>
```

**AGENTS.md** — first line is `# <Name> — project instructions`, then identity,
scope, locked decisions, conventions, commands, traps.

**STATE.md** — the first content line must be the pin, because
`scripts/verify_docs.py` reads it, and it must contain the word "Verified":

```markdown
**Verified:** <YYYY-MM-DD> · `HEAD <sha>` · <the commands that were actually run>
```

A STATE.md that genuinely cannot be pinned must say so on a line containing the
words "working tree" or "uncommitted". The checker treats that as
unpinned-and-flagged — never as green.

**CHANGELOG.md** — `# Changelog`, then `## <YYYY-MM-DD> — <one-line summary>`
sections, newest first.

## 4. Rules that apply to every project

1. **STATE.md is left uncommitted.** The pin names HEAD, so committing the file
   moves HEAD and instantly re-stales it. Update the pin as the *last* edit of a
   work session and leave it in the working tree. This is enforced by
   `scripts/verify_docs.py`, and it is not a bug to work around.
2. **Claim a file before editing it.** `python3 scripts/devsup.py claim <path>
   --note "why"`. A refused claim means coordinate, not overwrite. Release with
   `devsup.py release <path>`.
3. **Never push.** A plain `git commit` stays local. Publishing needs `ALLOW_PUSH=1`
   *and* the user saying so in the current session.
4. **Tests are real commands.** Every status in `README.md` or `STATE.md` was
   produced by running the project's own command and reading its output.
5. **Real-hardware and real-site tests stay out of CI.** They are manual and
   opt-in.
6. **No secrets.** `.env` is ignored; a committed credential is a rotation event,
   not a cleanup.
7. **`PLAN.md` is a contract.** `Status: PLAN APPROVED` is binding. A proposal that
   diverges is recorded as an amendment or a supersession note — never merged
   silently into the approved plan.

## 5. New project

```bash
python3 scripts/new_project.py <slug> \
    --name "<Name>" \
    --one-line "<one-line description>" \
    [--kind flutter|dart|python|docs]
```

It creates `projects/<slug>/` from `templates/project/`, with the standard files,
a `STATE.md` pinned to the current HEAD, and the required headers already in
place. Then:

```bash
make projects-check      # the skeleton is well-formed
make docs-check          # the pin is green
git add projects/<slug> && git commit
```

## 6. Current projects

| Project | Kind | README | AGENTS.md | STATE.md | docs/ | Standalone |
|---|---|---|---|---|---|---|
| `projects/agora/` | Flutter desktop (AppImage) | ✅ | ✅ | ✅ | ✅ | yes |
| `projects/rgx/` | Python research harness | ✅ | ✅ | ✅ | ✅ | yes |
| `projects/cleantube/` | Flutter Android (plan only) | ✅ | ✅ | ✅ | ✅ | plan only |
| `projects/arise/` | in flight by another agent | — | — | — | ✅ | exempt |
| `backend/` | Python + FastAPI (OMNIVEST) | ✅ | ✅ | ✅ | ✅ | yes |
| `frontend/` | Flutter web (OMNIVEST) | ✅ | ✅ | ✅ | ✅ | yes |

A project may only be listed as exempt with a reason and an owner. An exemption
is a TODO with a name on it, not a permanent state.

`backend/` and `frontend/` stay at the repo root rather than moving under
`projects/`. They are the OMNIVEST pair — two halves of one product, on a
different stack from everything in `projects/` — and moving them would invalidate
every path in their own docs, the Makefile and `scripts/verify_api.sh` for no
benefit. They are exempt from the *location* convention, not from the standard.

## 7. What `make check` does and does not gate in CI

`.github/workflows/test.yml` runs `verify_projects.py` as a **hard gate** and
`verify_docs.py --warn` as **advisory**. That asymmetry is deliberate: the
document set is committed, but the pins are not (rule 4.1), so on a fresh checkout
the pins always name an older commit. A CI job that failed on that would be red on
every run and would teach people to ignore it.

The product suites are not in CI — they need Flutter, a virtualenv and, for the
API smoke test, a running server. They run locally via `make verify`.
