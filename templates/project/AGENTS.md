# @NAME@ — project instructions

@IDENTITY@

## Authority

- `PLAN.md` — @PLAN_STATE@
- `STATE.md` — derived build status. Regenerate with the `project-orientation`
  skill; never hand-edit the pin.
- `README.md` — the entry point for a human. Keep it true or delete it.

## Scope

**In:**

- @IN@

**Out — do not build these:**

- @OUT@

## Locked decisions

Changing one of these is a decision, not a refactor.

- @DECISION@

## Conventions

- @CONVENTION@

## Commands

```bash
@COMMANDS@
```

## Known traps

- @TRAP@

## Standing constraints

- **Never claim more than the evidence supports.** A status is a command you ran
  and read, not a file that exists.
- **Claim a file before editing it.** `python3 scripts/devsup.py claim <path>
  --note "why"`; a refused claim means coordinate, not overwrite.
- **Never push.** A plain `git commit` stays local; publishing needs `ALLOW_PUSH=1`
  and the user's explicit agreement in the session.
- **Leave no stub standing in for finished work** without saying so in
  `STATE.md`.
