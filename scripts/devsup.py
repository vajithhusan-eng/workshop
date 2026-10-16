#!/usr/bin/env python3
"""devsup — per-project, per-session live build + runtime supervisor.

Solves three things the Makefile's `backend` / `frontend` targets cannot:

  1. Isolation. Two OpenCode sessions on the same project no longer fight over a
     port. Each start allocates a real free port and records it.
  2. Visibility. `status` is the review toggle: one row per running target, with
     port, pid, uptime and a live health probe. Logs are on disk, never lost.
  3. Accountability. Nothing is started that `status` cannot account for, and
     nothing is left running that `stop` cannot kill.

A "live build" here means the target's own build-and-run command, watched. For
Flutter that is `flutter run`, which builds, launches, and stays resident for hot
reload -- build and runtime in one process. For the backend it is uvicorn with
its reloader. devsup supervises; it does not pretend to be a build system.

State lives in .devsup/ at the repo root. Logs are appended, never truncated, so
a crash that happened four minutes ago is still readable.

Stdlib only. No install step.

Usage:
    devsup.py start  <target> [--session S] [--port N]
    devsup.py stop   <target> [--session S]
    devsup.py restart <target> [--session S]
    devsup.py status
    devsup.py logs   <target> [--lines N] [--session S]
    devsup.py down
    devsup.py targets
"""

from __future__ import annotations

import argparse
import errno
import json
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATE = ROOT / ".devsup"
LOGS = STATE / "logs"
REGISTRY = STATE / "registry.json"
# Review mode is an explicit, user-flipped intent flag. It exists so a live build
# can run and report itself loudly in the terminal while *nothing* opens a browser
# until the human asks to look.
REVIEW = STATE / "review.json"
LOCK = STATE / ".lock"
# Claims record which session is working on which path, so two agents editing the
# same tree can see each other instead of silently overwriting each other. A claim
# is advisory, not a lock: it exists to make a collision visible *before* the
# second writer starts, not to prevent the first from working.
CLAIMS = STATE / "claims.json"
# A claim older than this is treated as abandoned. Nothing here can kill a stale
# claim automatically -- a long-running build is not a crash -- so expiry only
# changes what is *reported*.
CLAIM_STALE_S = 6 * 3600

# --------------------------------------------------------------------------
# Targets. Each knows how to build, run, and be probed.
#
# `port` is the *preferred* port, not a requirement: start allocates upward from
# here until it finds a free one, so a session never dies because someone left a
# server running in another session.
# --------------------------------------------------------------------------
TARGETS = {
    "backend": {
        "cwd": "backend",
        "desc": "OMNIVEST FastAPI (uvicorn, auto-reload)",
        "port": 8123,
        "probe": "http://127.0.0.1:{port}/",
        "env": {"OMNIVEST_PORT": "{port}"},
        "preview": "http://127.0.0.1:{port}/docs",
        "cmd": lambda: [
            str(ROOT / "backend" / ".venv" / "bin" / "python"),
            "run.py",
        ],
        "needs": "backend/.venv",
    },
    "frontend": {
        "cwd": "frontend",
        "desc": "Flutter web server (hot reload)",
        "port": 8081,
        "probe": "http://127.0.0.1:{port}/",
        "preview": "http://127.0.0.1:{port}/",
        "cmd": lambda: (
            flutter()
            + [
                "run",
                "-d",
                "web-server",
                f"--web-port={{port}}",
                "--web-hostname=127.0.0.1",
            ]
        ),
        "needs": None,
    },
    "agora": {
        "cwd": "projects/agora",
        "desc": "Agora Flutter desktop (Linux, hot reload)",
        "port": None,  # native window, no port
        "probe": None,  # liveness == process alive
        "preview": None,  # native window: not browser-previewable
        "cmd": lambda: flutter() + ["run", "-d", "linux"],
        "needs": None,
    },
    "agora-web": {
        "cwd": "projects/agora",
        "desc": "Agora in a browser (previewable; web/ dir exists)",
        "port": 8090,
        "probe": "http://127.0.0.1:{port}/",
        "preview": "http://127.0.0.1:{port}/",
        "cmd": lambda: (
            flutter()
            + [
                "run",
                "-d",
                "web-server",
                f"--web-port={{port}}",
                "--web-hostname=127.0.0.1",
            ]
        ),
        "needs": None,
    },
}

STARTUP_GRACE = 90  # seconds to wait before judging a target healthy


# --------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------
def flutter() -> list[str]:
    """Locate flutter without assuming it is on PATH (snap installs are not)."""
    exe = shutil.which("flutter")
    if exe:
        return [exe]
    for guess in (
        Path.home() / "snap/flutter/common/flutter/bin/flutter",
        Path.home() / "flutter/bin/flutter",
        Path("/usr/local/flutter/bin/flutter"),
    ):
        if guess.exists():
            return [str(guess)]
    sys.exit("devsup: flutter not found on PATH or in the usual locations")


def free_port(start: int, limit: int = 60) -> int:
    for port in range(start, start + limit):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                s.bind(("127.0.0.1", port))
                return port
            except OSError as exc:
                if exc.errno != errno.EADDRINUSE:
                    raise
    sys.exit(f"devsup: no free port in {start}..{start + limit}")


def port_busy(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(("127.0.0.1", port)) == 0


def alive(pid: int | None) -> bool:
    if not pid:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def load() -> dict:
    if REGISTRY.exists():
        try:
            return json.loads(REGISTRY.read_text())
        except json.JSONDecodeError:
            # A corrupt registry must never wedge the tool. Preserve it for
            # inspection and continue with an empty one rather than refusing.
            REGISTRY.rename(STATE / "registry.corrupt.json")
    return {}


def save(reg: dict) -> None:
    STATE.mkdir(parents=True, exist_ok=True)
    tmp = REGISTRY.with_suffix(".tmp")
    tmp.write_text(json.dumps(reg, indent=2, sort_keys=True))
    tmp.replace(REGISTRY)


def review_state() -> dict:
    if REVIEW.exists():
        try:
            return json.loads(REVIEW.read_text())
        except json.JSONDecodeError:
            REVIEW.rename(STATE / "review.corrupt.json")
    return {"armed": False}


def set_review(armed: bool) -> None:
    STATE.mkdir(parents=True, exist_ok=True)
    tmp = REVIEW.with_suffix(".tmp")
    tmp.write_text(
        json.dumps(
            {"armed": armed, "changed": time.strftime("%Y-%m-%d %H:%M:%S")},
            indent=2,
            sort_keys=True,
        )
    )
    tmp.replace(REVIEW)


def claims_load() -> dict:
    if CLAIMS.exists():
        try:
            return json.loads(CLAIMS.read_text())
        except json.JSONDecodeError:
            CLAIMS.rename(STATE / "claims.corrupt.json")
    return {}


def claims_save(reg: dict) -> None:
    STATE.mkdir(parents=True, exist_ok=True)
    tmp = CLAIMS.with_suffix(".tmp")
    tmp.write_text(json.dumps(reg, indent=2, sort_keys=True))
    tmp.replace(CLAIMS)


def claim_path(p: str) -> str:
    """Normalise a path so two agents claiming the same file agree on the key."""
    return os.path.normpath(os.path.abspath(os.path.expanduser(p)))


def cmd_claim(a) -> None:
    """Take an advisory claim on a path. Refuses if someone else holds a live one."""
    path = claim_path(a.path)
    session = resolve_session(a.session)
    reg = claims_load()
    now = time.time()
    held = reg.get(path)
    if held and held.get("session") != session and _claim_live(held, now):
        age = int(now - held.get("ts", now))
        print(f"claim: REFUSED -- {path}", file=sys.stderr)
        print(
            f"  held by session={held['session']} since {held.get('since', '?')} "
            f"({age}s ago)",
            file=sys.stderr,
        )
        print(
            "  This is advisory, not enforced. Coordinate rather than overwrite, "
            "or claim a different path.",
            file=sys.stderr,
        )
        sys.exit(2)
    reg[path] = {
        "session": session,
        "note": a.note or "",
        "since": time.strftime("%Y-%m-%d %H:%M:%S"),
        "ts": now,
    }
    claims_save(reg)
    print(f"claim: {path}")
    print(f"  session={session}" + (f"  note={a.note}" if a.note else ""))


def _claim_live(held: dict, now: float) -> bool:
    return (now - held.get("ts", 0)) < CLAIM_STALE_S


def cmd_release(a) -> None:
    """Release a claim. Without a path, releases every claim held by this session."""
    reg = claims_load()
    if a.path:
        path = claim_path(a.path)
        if path in reg:
            del reg[path]
            claims_save(reg)
            print(f"released: {path}")
        else:
            print(f"no claim held on {path}")
        return
    session = resolve_session(a.session)
    mine = [p for p, h in reg.items() if h.get("session") == session]
    for p in mine:
        del reg[p]
    claims_save(reg)
    print(f"released {len(mine)} claim(s) held by session={session}")


def cmd_claims(a) -> None:
    """List every live claim, flagging abandoned ones."""
    reg = claims_load()
    now = time.time()
    if not reg:
        print("claims: none")
        return
    print(f"{'STATUS':8} {'SESSION':16} {'AGE':>9}  PATH")
    stale = 0
    for path in sorted(reg):
        h = reg[path]
        age = int(now - h.get("ts", now))
        live = _claim_live(h, now)
        stale += not live
        print(
            f"{'live' if live else 'STALE':8} {(h.get('session') or '?'):16} "
            f"{age:>7}s  {path}" + (f"  [{h['note']}]" if h.get("note") else "")
        )
    if stale:
        print(
            f"\n{stale} claim(s) look abandoned -- release with: devsup.py release <path>"
        )


def key(target: str, session: str) -> str:
    return f"{session}/{target}"


def resolve_session(explicit: str | None) -> str:
    return explicit or os.environ.get("OPENCODE_SESSION") or "default"


def resolve_target(name: str) -> str:
    """Accept exact key, or any unambiguous prefix/suffix."""
    if name in TARGETS:
        return name
    hits = [t for t in TARGETS if t.startswith(name) or name in t]
    if len(hits) == 1:
        return hits[0]
    if not hits:
        sys.exit(f"devsup: unknown target {name!r}. Try: {', '.join(TARGETS)}")
    sys.exit(f"devsup: {name!r} is ambiguous: {', '.join(hits)}")


# --------------------------------------------------------------------------
# lifecycle
# --------------------------------------------------------------------------
def reap(reg: dict) -> bool:
    """Drop entries whose process is gone. Returns True if anything changed."""
    changed = False
    for k, rec in list(reg.items()):
        if not alive(rec.get("pid")):
            rec["exited_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
            rec["pid"] = None
            changed = True
    return changed


def stop_one(k: str, rec: dict, verbose: bool = True) -> None:
    pid = rec.get("pid")
    if alive(pid):
        # Kill the whole group. `flutter run` spawns a dart VM as a child;
        # killing only the parent orphans the child and keeps the port bound.
        for sig in (signal.SIGTERM, signal.SIGKILL):
            try:
                os.killpg(os.getpgid(pid), sig)
            except OSError:
                try:
                    os.kill(pid, sig)
                except OSError:
                    break
            for _ in range(20):
                if not alive(pid):
                    break
                time.sleep(0.1)
            if not alive(pid):
                break
        if verbose:
            print(f"  stopped {k} (pid {pid})")
    elif verbose:
        state = "already exited" if rec.get("exited_at") else "not running"
        print(f"  {k}: {state}")


def start_one(target: str, session: str, want_port: int | None) -> None:
    spec = TARGETS[target]
    reg = load()
    reap(reg)
    k = key(target, session)

    if reg.get(k, {}).get("pid") and alive(reg[k]["pid"]):
        sys.exit(
            f"devsup: {k} is already running (pid {reg[k]['pid']}, "
            f"port {reg[k].get('port')}). Use `restart` or `stop` first."
        )

    needs = spec.get("needs")
    if needs and not (ROOT / needs).exists():
        sys.exit(
            f"devsup: {target} needs {needs}, which does not exist. Run its setup first."
        )

    port = None
    if spec.get("port"):
        pref = want_port or spec["port"]
        if want_port and port_busy(want_port):
            sys.exit(f"devsup: port {want_port} is already in use")
        port = free_port(pref)

    cmd = [str(c).format(port=port) for c in spec["cmd"]()]
    cwd = ROOT / spec["cwd"]
    env = {
        **os.environ,
        **{k: v.format(port=port) for k, v in spec.get("env", {}).items()},
    }

    LOGS.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    log = LOGS / f"{session}-{target}-{stamp}.log"

    print(f"  starting {k}")
    print(f"    cwd   {spec['cwd']}")
    print(f"    cmd   {' '.join(cmd)}")
    print(f"    port  {port or 'n/a'}")
    print(f"    log   {log.relative_to(ROOT)}")

    with log.open("ab", buffering=0) as fh:
        fh.write(f"\n=== {stamp} :: {' '.join(cmd)}\n".encode())
        proc = subprocess.Popen(
            cmd,
            cwd=cwd,
            env=env,
            stdout=fh,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
            # New process group => stop can kill the whole tree.
            preexec_fn=os.setsid,
        )

    reg[k] = {
        "target": target,
        "session": session,
        "pid": proc.pid,
        "port": port,
        "log": str(log.relative_to(ROOT)),
        "cmd": cmd,
        "cwd": spec["cwd"],
        "started_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "started_ts": time.time(),
    }
    save(reg)

    if not probe_ok(spec, port):
        print(f"    waiting up to {STARTUP_GRACE}s for first successful response...")
        deadline = time.time() + STARTUP_GRACE
        while time.time() < deadline:
            if not alive(proc.pid):
                print(f"    process exited early -- last 20 log lines:\n")
                tail(log, 20)
                sys.exit(1)
            if probe_ok(spec, port):
                break
            time.sleep(1.0)
        else:
            print("    did NOT become healthy in time. Still running; inspect:")
            print(f"      devsup.py logs {target} --lines 40")
            return

    print(
        f"    up    {'ready at ' + spec['probe'].format(port=port) if spec.get('probe') else 'process alive'}"
    )


def probe_ok(spec: dict, port: int | None) -> bool:
    if not spec.get("probe"):
        return True
    url = spec["probe"].format(port=port)
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=1.5) as s:
            s.sendall(b"HEAD / HTTP/1.0\r\nHost: localhost\r\n\r\n")
            s.recv(64)
        return True
    except OSError:
        return False


def tail(path: Path, n: int) -> None:
    if not path.exists():
        print("    (no log file)")
        return
    lines = path.read_text(errors="replace").splitlines()
    for line in lines[-n:]:
        print(f"    {line}")


def cmd_start(a) -> None:
    start_one(resolve_target(a.target), resolve_session(a.session), a.port)


def cmd_stop(a) -> None:
    reg = load()
    reap(reg)
    save(reg)
    session = resolve_session(a.session)
    target = resolve_target(a.target) if a.target else None
    victims = [
        k
        for k, r in reg.items()
        if (target is None or r["target"] == target)
        and (a.session is None or r["session"] == session)
    ]
    if not victims:
        print("  nothing to stop")
        return
    for k in victims:
        stop_one(k, reg[k])
        reg.pop(k, None)
    save(reg)


def cmd_restart(a) -> None:
    cmd_stop(argparse.Namespace(target=a.target, session=a.session))
    time.sleep(1.0)
    cmd_start(argparse.Namespace(target=a.target, session=a.session, port=None))


def cmd_down(a) -> None:
    cmd_stop(argparse.Namespace(target=None, session=None))


def cmd_status(a) -> None:
    reg = load()
    if reap(reg):
        save(reg)
    live = {k: r for k, r in reg.items() if r.get("pid")}

    print()
    if not live:
        print("  nothing running")
        print()
        print("  start one:  devsup.py start <target>   e.g. start agora")
        print("  targets:    devsup.py targets")
        print()
        return

    rows = []
    for k, r in sorted(live.items()):
        spec = TARGETS.get(r["target"], {})
        up = int(time.time() - r.get("started_ts", time.time()))
        health = "up" if probe_ok(spec, r.get("port")) else "starting/slow"
        rows.append(
            (
                r["session"],
                r["target"],
                r.get("port") or "-",
                r["pid"],
                f"{up // 3600}h{(up % 3600) // 60:02d}m{up % 60:02d}s",
                health,
                r["log"],
            )
        )

    w = [max(len(str(x[i])) for x in rows) for i in range(6)]
    print(
        f"  {'SESSION':<{w[0]}}  {'TARGET':<{w[1]}}  {'PORT':<{w[2]}}  {'PID':<{w[3]}}  {'UPTIME':<{w[4]}}  HEALTH"
    )
    print(
        f"  {'-' * w[0]}  {'-' * w[1]}  {'-' * w[2]}  {'-' * w[3]}  {'-' * w[4]}  {'-' * 9}"
    )
    for row in rows:
        print(
            f"  {row[0]:<{w[0]}}  {row[1]:<{w[1]}}  {row[2]:<{w[2]}}  {row[3]:<{w[3]}}  {row[4]:<{w[4]}}  {row[5]}"
        )
    print()
    for row in rows:
        print(f"  logs:  devsup.py logs {row[1]} --session {row[0]}")
    print()


def cmd_logs(a) -> None:
    reg = load()
    k = key(resolve_target(a.target), resolve_session(a.session))
    rec = reg.get(k)
    if not rec:
        sys.exit(f"devsup: {k} has never been started in this repo")
    tail(ROOT / rec["log"], a.lines)
    if a.follow:
        print("\n--- following (ctrl-c to stop) ---")
        try:
            subprocess.run(["tail", "-f", str(ROOT / rec["log"])])
        except KeyboardInterrupt:
            pass


def cmd_targets(a) -> None:
    print()
    for name, spec in TARGETS.items():
        missing = spec.get("needs") and not (ROOT / spec["needs"]).exists()
        print(f"  {name:<10} {spec['desc']}")
        print(
            f"  {'':<10}   cwd={spec['cwd']}  port={spec.get('port') or 'n/a'}"
            + ("   MISSING: " + spec["needs"] if missing else "")
        )
    print()


def cmd_preview(a) -> None:
    """Print the browser-preview URL for a running target.

    devsup cannot open the pane itself -- that is an agent-side action using the
    browser tool. What it can do is tell the agent the exact URL for the exact
    port this session allocated, which is the part that is easy to get wrong.
    """
    name = resolve_target(a.target) if a.target else None
    reg = load()
    if reap(reg):
        save(reg)

    rows = []
    if name:
        # Every session running this target, not just one. A wrong port here sends
        # the browser to somebody else's server, which is worse than no answer.
        sess = a.session
        for k, rec in sorted(reg.items()):
            if rec.get("target") != name:
                continue
            if sess and rec.get("session") != sess:
                continue
            rows.append((name, rec))
        if not rows and not sess:
            rows.append((name, None))  # nothing anywhere: report the preferred port
    else:
        for k, rec in sorted(reg.items()):
            rows.append((rec["target"], rec))

    if not rows:
        print("  nothing running - start something first")
        return

    print()
    shown = False
    for tname, rec in rows:
        spec = TARGETS.get(tname, {})
        tmpl = spec.get("preview")
        if not tmpl:
            print(f"  {tname:<10} no browser preview (native window)")
            continue
        port = rec.get("port") if rec else spec.get("port")
        if not port:
            print(f"  {tname:<10} no port")
            continue
        url = tmpl.format(port=port)
        sess = rec.get("session", "?") if rec else "not-running"
        state = "up" if rec and alive(rec.get("pid")) else "not-running"
        print(f"  {tname:<10} [{sess}] {state}")
        print(f"  {'':<10} {url}")
        shown = True

    if shown:
        print("\n  open with the browser tool (tabs.open) to show it beside the TUI")
        print("  native targets: no X/Wayland capture works here - verified blank.")
    print()


def cmd_review(a) -> None:
    """Arm or disarm review mode -- the only thing that permits opening a browser.

    A build should be able to run loudly and visibly in the terminal for as long
    as it takes without ever stealing focus. Review mode is the deliberate,
    human-flipped exception. It is OFF unless someone explicitly turns it ON.
    """
    act = a.action
    if act == "status":
        st = review_state()
        armed = bool(st.get("armed"))
        print(
            "review: ON  (a preview may be opened when you ask for one)"
            if armed
            else "review: OFF (no browser will be opened)"
        )
        if st.get("changed"):
            print(f"  changed: {st['changed']}")
        return
    armed = act == "on"
    set_review(armed)
    print(
        "review: ON - previews may be opened when you ask for one."
        if armed
        else "review: OFF - no browser will be opened."
    )


def main() -> None:
    STATE.mkdir(parents=True, exist_ok=True)
    ap = argparse.ArgumentParser(
        prog="devsup",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("start")
    p.add_argument("target")
    p.add_argument("--session")
    p.add_argument("--port", type=int)
    p.set_defaults(fn=cmd_start)
    p = sub.add_parser("stop")
    p.add_argument("target", nargs="?")
    p.add_argument("--session")
    p.set_defaults(fn=cmd_stop)
    p = sub.add_parser("restart")
    p.add_argument("target")
    p.add_argument("--session")
    p.set_defaults(fn=cmd_restart)
    p = sub.add_parser("status")
    p.set_defaults(fn=cmd_status)
    p = sub.add_parser("logs")
    p.add_argument("target")
    p.add_argument("--session")
    p.add_argument("--lines", type=int, default=40)
    p.add_argument("--follow", action="store_true")
    p.set_defaults(fn=cmd_logs)
    p = sub.add_parser("down")
    p.set_defaults(fn=cmd_down)
    p = sub.add_parser("targets")
    p.set_defaults(fn=cmd_targets)
    p = sub.add_parser("preview")
    p.add_argument("target", nargs="?")
    p.add_argument("--session")
    p.set_defaults(fn=cmd_preview)
    p = sub.add_parser(
        "review",
        help="arm/disarm opening a browser (off by default)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "review on    allow a preview to be opened when asked\n"
            "review off   nothing opens a browser (default)\n"
            "review status  show the current setting"
        ),
    )
    p.add_argument(
        "action", choices=("on", "off", "status"), nargs="?", default="status"
    )
    p.set_defaults(fn=cmd_review)
    p = sub.add_parser(
        "claim",
        help="take an advisory claim on a path before editing it",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Advisory, not enforced. Refuses when another session holds a live claim\n"
            "so a collision is visible before the second writer starts.\n\n"
            "  devsup.py claim lib/data/database.dart --note 'schema v3'\n"
            "  devsup.py claims          # who holds what\n"
            "  devsup.py release <path>  # give it back\n"
            "  devsup.py release         # release all of this session's"
        ),
    )
    p.add_argument("path")
    p.add_argument("--session")
    p.add_argument("--note")
    p.set_defaults(fn=cmd_claim)
    p = sub.add_parser(
        "release",
        help="release a claim (or all claims held by this session)",
    )
    p.add_argument("path", nargs="?")
    p.add_argument("--session")
    p.set_defaults(fn=cmd_release)
    p = sub.add_parser("claims", help="list live and stale claims")
    p.set_defaults(fn=cmd_claims)

    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
