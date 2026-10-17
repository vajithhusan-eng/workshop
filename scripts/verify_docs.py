#!/usr/bin/env python3
"""Catch the two failure modes that keep recurring in this workspace.

1. STATE PINS WITH NOTHING BEHIND THEM. Every STATE.md pins the commit it was
   verified against. That pin is a *record* -- "this file describes the tree at
   <commit>" -- so it is allowed to name an older commit. What it may never do is
   name a commit this history does not contain, which is what an invented,
   truncated or rebased-away hash looks like. A pin that is merely old is honest;
   a pin that is unverifiable is a claim with nothing behind it.

   THIS REPLACED A STRICTER RULE. The check used to demand `pin == HEAD`, which can
   only hold while STATE.md is a dirty working-tree file. That made a published,
   clean checkout impossible and forced "leave STATE.md uncommitted" (the old rule
   4.1) -- which in turn meant the pins on GitHub were permanently stale while still
   looking authoritative. The old rule could not tell "old" from "invented".

2. SHADOWED AGENTS. An agent defined both inline in opencode.jsonc and as a file in
   agents/ silently loses to the file version. Editing the inline copy does nothing
   and looks like it worked.

Usage:
    python3 scripts/verify_docs.py            # report, exit 1 on an unverifiable pin
    python3 scripts/verify_docs.py --warn     # report, always exit 0
    python3 scripts/verify_docs.py --quiet    # only failures

Exits 1 when any STATE.md is pinned to a commit that is not in this history, or is
unpinned (cannot be checked). Drift behind HEAD is reported, never fatal.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GLOBAL_CFG = Path.home() / ".config" / "opencode"

# A pinned commit: a 7-40 char hex string on a line that mentions verification.
SHA = re.compile(r"\b([0-9a-f]{7,40})\b")
VERIFY_LINE = re.compile(r"verif", re.I)
# A line that explicitly declines to pin, which is honest but uncheckable.
UNPINNED = re.compile(r"working tree|current head|uncommitted", re.I)


def head(root: Path = REPO) -> str:
    try:
        return subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=root,
            capture_output=True,
            text=True,
            timeout=15,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def is_ancestor(sha: str, root: Path = REPO) -> bool:
    """True when `sha` names a commit reachable from HEAD."""
    try:
        r = subprocess.run(
            ["git", "merge-base", "--is-ancestor", sha, "HEAD"],
            cwd=root,
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    return r.returncode == 0


def behind(sha: str, root: Path = REPO) -> int:
    """Commits between `sha` and HEAD; 0 when they are the same commit."""
    try:
        r = subprocess.run(
            ["git", "rev-list", "--count", f"{sha}..HEAD"],
            cwd=root,
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (OSError, subprocess.SubprocessError):
        return 0
    try:
        return int(r.stdout.strip() or "0")
    except ValueError:
        return 0


def check_state_file(path: Path, want: str) -> tuple[str, str]:
    """Return (status, detail) for one STATE.md.

    status is one of: ok | STALE | UNPINNED | no-head
    """
    if not want:
        return ("no-head", "cannot resolve HEAD for this directory")
    try:
        text = path.read_text()
    except OSError as e:
        return ("UNPINNED", f"unreadable: {e}")

    pinned: str | None = None
    unpinned = False
    for line in text.splitlines():
        if not VERIFY_LINE.search(line):
            continue
        m = SHA.search(line)
        if m and m.group(1) != want:
            pinned = m.group(1)
        elif m:
            pinned = m.group(1)
        if UNPINNED.search(line):
            unpinned = True

    if pinned is None:
        if unpinned:
            return ("UNPINNED", "says 'working tree' -- cannot be checked")
        return ("UNPINNED", "no commit pinned -- add one so this can be checked")
    if pinned == want:
        return ("ok", f"pinned {pinned} == HEAD")
    if is_ancestor(pinned, path.parent):
        n = behind(pinned, path.parent)
        return ("ok", f"pinned {pinned}, {n} commit(s) behind HEAD -- verified earlier")
    return ("STALE", f"pinned {pinned}, which is not in this history")


def shadowed_agents() -> dict[str, Path]:
    """Map each agent defined twice to the file that actually wins.

    The file version silently overrides the inline one, so editing the inline copy
    does nothing while looking like it worked. Returning the winning path (not just
    the name) is the difference between a report you can act on and a bare list.
    """
    cfg = GLOBAL_CFG / "opencode.jsonc"
    if not cfg.exists():
        return {}
    try:
        s = cfg.read_text()
    except OSError:
        return {}
    s = re.sub(r"^\s*//.*$", "", s, flags=re.M)
    s = re.sub(r",(\s*[}\]])", r"\1", s)
    try:
        inline = set(json.loads(s).get("agents", {}))
    except json.JSONDecodeError:
        return {}
    files = {p.stem: p for p in (GLOBAL_CFG / "agents").glob("*.md")}
    return {n: files[n] for n in sorted(inline & files.keys())}


# Projects that are in flight under another agent get the same exemption
# verify_projects.py grants them. An exemption is a TODO with a name on it.
EXEMPT = {"arise": "in flight by another agent (docs/ only, no claim yet)"}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--warn", action="store_true", help="always exit 0")
    ap.add_argument("--quiet", action="store_true", help="only print failures")
    a = ap.parse_args()

    # Project directories, top-level projects (backend/, frontend/) and the root.
    files = (
        sorted(REPO.glob("projects/*/STATE.md"))
        + sorted(REPO.glob("*/STATE.md"))
        + [REPO / "STATE.md"]
    )
    files = [f for f in files if f.exists()]

    bad = 0
    if not a.quiet:
        print("STATE FILE FRESHNESS")
    for f in files:
        rel = f.relative_to(REPO)
        if f.parent.name in EXEMPT:
            if not a.quiet:
                print(f"  ok       {rel}  (exempt: {EXEMPT[f.parent.name]})")
            continue
        want = head(f.parent) or head()
        status, detail = check_state_file(f, want)
        if status == "ok":
            if not a.quiet:
                print(f"  ok       {rel}  ({detail})")
        else:
            bad += 1
            print(f"  {status:<8} {rel}  {detail}")

    shadow = shadowed_agents()
    if shadow:
        print("\nSHADOWED AGENTS -- the FILE wins; the inline copy is inert")
        for name, path in shadow.items():
            print(f"  {name:<14} edit this, not the opencode.jsonc entry:")
            print(f"                 {path}")
        print(f"\n  {len(shadow)} agent(s) defined in both places.")
        print("  Each inline entry is commented with the same warning.")

    if bad:
        print(f"\n{bad} state file(s) pin a commit this history does not contain.")
        print("A pin records what was verified, so naming an older commit is fine.")
        print("Naming a commit that does not exist is not. Fix the pin.")
    return 0 if (a.warn or bad == 0) else 1


if __name__ == "__main__":
    sys.exit(main())
