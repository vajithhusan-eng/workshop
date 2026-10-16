---
name: dev
description: Start, stop, preview, and review live builds and running apps per project and per session
agent: build
---

# Live build and runtime supervision

`scripts/devsup.py` supervises the repo's runnable targets. It exists so a running
app is **visible and owned** rather than a mystery process, and so two sessions on
the same project never collide on a port.

Always invoke it from the repo root:

```bash
python3 scripts/devsup.py <verb> [args]
```

## Targets

| Target | What runs | Port | Browser preview |
|---|---|---|---|
| `backend` | OMNIVEST FastAPI, uvicorn auto-reload | 8123 preferred | yes — `/docs` |
| `frontend` | Flutter web server, hot reload | 8081 preferred | yes — `/` |
| `agora` | Agora Flutter desktop (Linux), hot reload | none — native window | **no** — use `agora-web` |
| `agora-web` | Agora served in a browser (`web/` exists) | 8090 preferred | yes — `/` |

```bash
python3 scripts/devsup.py targets      # list with readiness
```

## Review mode — nothing opens a browser unless you ask

**Live building and live testing run in the terminal and are always on.** Logs,
`status`, health probes and error output are the normal output of this workflow,
and none of them open anything.

A browser opens **only** when review mode is armed:

```bash
python3 scripts/devsup.py review on      # arm it
python3 scripts/devsup.py review status  # check it
python3 scripts/devsup.py review off     # disarm it
```

`review` defaults to **OFF**. That is deliberate: a build that runs for twenty
minutes must not steal focus twenty times.

**Before any `browser.tabs.open`, run `review status`.** If it reports OFF, give
the URL as text and stop. The human flips the switch, not the agent.

When review is armed, take the exact URL from `preview`:

```bash
python3 scripts/devsup.py preview frontend --session pv
```

It prints the URL **with the port devsup actually allocated** — the part that is
easy to get wrong, because the preferred port is often already taken by something
outside devsup. Then open exactly that:

```
browser.tabs.open({ url: "<that url>", focus: true })
```

Rules:

- **Never guess the port.** Take it from `preview` or `status`. A 200 on the
  preferred port may be a *different* process than the one you started.
- **Never open speculatively.** No "let me take a look", no opening several
  targets to compare them. One target, only when asked.
- Re-open or focus the tab after a restart to pick up the rebuilt app.
- `agora` (native) cannot be previewed: `xwd` fails `BadMatch` on root and
  `ffmpeg x11grab` captures pure black on both `:0` and `:1`. Verified — do not
  promise a desktop screenshot. Use `agora-web` when a visual is needed.
- A preview showing a stale frame is a **red line**. If the page still shows the
  pre-change state, the rebuild did not land — check `logs` before continuing.

Ports are **allocated, not demanded**. If the preferred port is busy — including by
a server you started outside devsup — devsup takes the next free one. Never kill a
foreign process to reclaim a port; just let it allocate.

## Claims — do not collide

This workspace has **more than one agent working in it at the same time**. That is
normal, not an edge case: during one session a fourth project appeared from
nothing, an app went from 4 commits to done, and a source file was rewritten
*while a command was reading it*. Guessing is not good enough.

**Before editing a file you did not create, claim it:**

```bash
python3 scripts/devsup.py claim projects/agora/lib/main.dart --note "mount UI"
python3 scripts/devsup.py claims                     # who holds what, right now
python3 scripts/devsup.py release projects/agora/lib/main.dart
python3 scripts/devsup.py release                    # everything this session holds
```

A claim by another live session is **REFUSED with exit 2**. Stop and coordinate
rather than overwrite. Claims are advisory — nothing is locked — so a refusal means
"ask or pick a different path", not "impossible".

Release claims when you finish. A claim older than 6 hours shows as `STALE` so an
abandoned one does not block you forever; release it explicitly to clear it.

**Watch for churn even without a claim.** If a file's mtime changes between your
read and your write, someone else is mid-write. Re-read before editing, and do not
assume your earlier read is still current.

## Verbs

```bash
python3 scripts/devsup.py start <target> [--session S] [--port N]
python3 scripts/devsup.py stop  <target> [--session S]
python3 scripts/devsup.py restart <target> [--session S]
python3 scripts/devsup.py status                       # the review toggle
python3 scripts/devsup.py logs <target> [--lines 40] [--follow] [--session S]
python3 scripts/devsup.py down                         # stop everything
python3 scripts/devsup.py preview [target] [--session S]  # URL only, opens nothing
python3 scripts/devsup.py review on|off|status         # the browser toggle (default off)
python3 scripts/devsup.py claim <path> [--note N] [--session S]
python3 scripts/devsup.py release [<path>] [--session S]
python3 scripts/devsup.py claims
```

`status` shows one row per running target with session, port, pid, uptime and a
live health probe. `preview` only **prints** a URL — it never opens anything.
`review` is the only thing that permits a browser to open, and it is **off** until
someone arms it.

## How to work with it

**Start early, not at the end.** Launch the target as soon as the code it exercises
exists, so the rest of the work is done against a running app rather than a
theoretical one.

**Give each concurrent line of work its own session name.** `--session alpha`,
`--session beta`. Two backends then run on different ports instead of the second
one dying.

**`start` waits for health.** It probes until the target answers, up to 90s, and
exits non-zero with the last 20 log lines if the process dies first. Do not run a
test against a target whose `start` did not print `up`.

**A server that started is not a server that works.** After starting, exercise the
real endpoint — `curl` the route the change affects, or read `logs`. A 200 on
`/openapi.json` proves uvicorn booted; it does not prove the endpoint you edited
works.

**Watch for errors while it runs.** `logs` after each meaningful change. A
traceback in the log is a red line: fix it before the next step, per the
no-red-left-behind rule.

**Report the port.** When a target comes up, tell the user the URL, including the
allocated port when it is not the preferred one.

**Leave nothing orphaned.** If you started a target, either leave it running and
say so, or `stop` it. `status` must never show something you started and forgot.

## Not covered

- Real-Chrome checks under `projects/agora/tool/` stay **manual and opt-in**
  (`PLAN.md` §12). devsup does not wire them into CI or run them for you.
- `flutter run` gives an interactive terminal. devsup redirects it to a log file,
  so **hot reload keystrokes (`r`, `R`) are unavailable**. Edit and let the
  reloader work, or restart. Do not claim you triggered a hot reload.