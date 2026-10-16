#!/usr/bin/env python3
"""Assert every project in this workspace has the standard skeleton.

This is the enforcement half of PROJECT-STANDARD.md. It fails when a project is
missing a required document, when a required document is empty, when a required
header is malformed, or when a top-level Markdown file is not indexed in
docs/README.md.

Usage:
    python3 scripts/verify_projects.py            # report, exit 1 on failure
    python3 scripts/verify_projects.py --warn     # report, always exit 0
    python3 scripts/verify_projects.py --quiet    # only failures
    python3 scripts/verify_projects.py --strict   # do not honour exemptions

Exits 1 if any project fails, 0 otherwise.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# A project is any directory under projects/, plus these top-level ones.
TOP_LEVEL = ["backend", "frontend"]

REQUIRED = [
    "README.md",
    "AGENTS.md",
    "STATE.md",
    "CHANGELOG.md",
    "docs/README.md",
]

# Top-level *.md files that are required and therefore need no index row.
ALWAYS_OK = set(REQUIRED)

# A project may only be exempt with a reason. An exemption is a TODO with a name
# on it, never a permanent state.
EXEMPT = {
    "arise": "in flight by another agent (docs/ only, no claim yet)",
}

# Required first lines.
FIRST_LINE = {
    "README.md": (re.compile(r"^#\s+\S"), "must start with a '# Title' line"),
    "AGENTS.md": (
        re.compile(r"^#\s+.* — project instructions\s*$"),
        "first line must be '# <Name> — project instructions'",
    ),
    "CHANGELOG.md": (
        re.compile(r"^#\s+Changelog\s*$"),
        "must start with '# Changelog'",
    ),
    "docs/README.md": (re.compile(r"^#\s+\S"), "must start with a '# Title' line"),
}

# STATE.md must carry a line the pin checker can read.
STATE_PIN = re.compile(r"verif", re.I)

MIN_CHARS = 40


def find_projects() -> list[Path]:
    found = [p for p in sorted((REPO / "projects").glob("*")) if p.is_dir()]
    found += [REPO / t for t in TOP_LEVEL if (REPO / t).is_dir()]
    return found


def first_line(path: Path) -> str:
    try:
        for line in path.read_text().splitlines():
            if line.strip():
                return line.strip()
    except OSError:
        return ""
    return ""


def check_project(path: Path) -> list[str]:
    problems: list[str] = []
    for rel in REQUIRED:
        f = path / rel
        if not f.is_file():
            problems.append(f"missing        {rel}")
            continue
        try:
            body = f.read_text()
        except OSError as e:
            problems.append(f"unreadable     {rel}: {e}")
            continue
        if len(body.strip()) < MIN_CHARS:
            problems.append(f"empty          {rel} ({len(body.strip())} chars)")
            continue
        rule = FIRST_LINE.get(rel)
        if rule:
            pattern, message = rule
            if not pattern.match(first_line(f)):
                problems.append(f"bad header     {rel}: {message}")

    state = path / "STATE.md"
    if state.is_file():
        try:
            if not any(STATE_PIN.search(ln) for ln in state.read_text().splitlines()):
                problems.append(
                    "unpinnable     STATE.md: no line containing 'Verified'/'verified'"
                )
        except OSError:
            pass

    index = path / "docs" / "README.md"
    if index.is_file():
        try:
            text = index.read_text()
        except OSError:
            text = ""
        for extra in sorted(path.glob("*.md")):
            if extra.name in ALWAYS_OK:
                continue
            if extra.name not in text:
                problems.append(
                    f"unindexed      {extra.name}: not mentioned in docs/README.md"
                )
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--warn", action="store_true", help="always exit 0")
    ap.add_argument("--quiet", action="store_true", help="only print failures")
    ap.add_argument("--strict", action="store_true", help="do not honour exemptions")
    a = ap.parse_args()

    projects = find_projects()
    failed = 0
    if not a.quiet:
        print("PROJECT STANDARD")
    for path in projects:
        rel = path.relative_to(REPO)
        exempt = path.name in EXEMPT and not a.strict
        problems = [] if exempt else check_project(path)
        if problems:
            failed += 1
            print(f"  FAIL  {rel}/")
            for p in problems:
                print(f"          {p}")
        elif not a.quiet:
            note = f"  (exempt: {EXEMPT[path.name]})" if exempt else ""
            print(f"  ok    {rel}/{note}")

    if failed:
        print(f"\n{failed} project(s) do not meet PROJECT-STANDARD.md.")
        print(
            "Fix the items above, or add a reasoned exemption to scripts/verify_projects.py."
        )
    elif not a.quiet:
        print(f"\n{len(projects)} project(s) checked.")
    return 0 if (a.warn or not failed) else 1


if __name__ == "__main__":
    raise SystemExit(main())
