#!/usr/bin/env python3
"""Create a new project from templates/project/.

Guarantees the layout in PROJECT-STANDARD.md so a new project starts compliant
instead of being retrofitted later.

Markers in the templates are substituted with plain ``str.replace`` -- never an
f-string, because the templates contain literal braces inside code fences.

Usage:
    python3 scripts/new_project.py myproj \
        --name "My Project" --one-line "Does one thing well." --kind python

    python3 scripts/new_project.py spec --name "Spec" --one-line "Design only." \
        --kind docs --into projects
"""

from __future__ import annotations

import argparse
import datetime
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TEMPLATES = REPO / "templates" / "project"
SLUG = re.compile(r"^[a-z][a-z0-9-]{0,40}$")

# Per-kind defaults. Each key becomes a @MARKER@ in the templates.
KINDS = {
    "flutter": {
        "STATUS": "Active",
        "STATUS_EVIDENCE": "skeleton only -- no build verified yet",
        "RUN": "flutter run",
        "TEST": "flutter test",
        "COMMANDS": "flutter pub get\nflutter test\nflutter analyze",
        "CONVENTION": "Flutter/Dart. `flutter analyze` must be clean before a commit.",
        "DECISION": "Flutter for the UI; do not add a second UI toolkit.",
    },
    "dart": {
        "status": "Active",
        "status_evidence": "skeleton only -- no code verified yet",
        "run": "dart run",
        "test": "dart test",
        "commands": "dart pub get\ndart test\ndart analyze",
        "convention": "Dart; `dart analyze` must stay clean before a commit.",
        "decision": "Pure Dart, no Flutter dependency.",
    },
    "python": {
        "status": "Active",
        "status_evidence": "skeleton only -- no tests verified yet",
        "run": "python -m <module>",
        "test": "pytest",
        "commands": "python -m venv .venv && . .venv/bin/activate\npip install -r requirements.txt\npytest",
        "convention": "Python 3 with type hints; a real test command before any status claim.",
        "decision": "Synthetic/fixture data only until a real run is verified.",
    },
    "docs": {
        "status": "Plan only",
        "status_evidence": "no code -- documents only",
        "run": "—",
        "test": "—",
        "commands": "# documents only; nothing to run",
        "convention": "This project is documents only. Write design, not code.",
        "decision": "Design is frozen in PLAN.md before implementation starts.",
    },
}
# The template uses @STATUS@-style upper-case markers for the header block and
# the same words in lower case inside prose. Normalise both spellings.
ALIASES = {
    "status": "STATUS",
    "status_evidence": "STATUS_EVIDENCE",
    "run": "RUN",
    "test": "TEST",
    "commands": "COMMANDS",
    "convention": "CONVENTION",
    "decision": "DECISION",
}

SLUG_RE = r"^[a-z][a-z0-9-]{0,40}$"


def head() -> str:
    try:
        out = __import__("subprocess").run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=REPO,
            capture_output=True,
            text=True,
            timeout=15,
        )
        return out.stdout.strip() or "uncommitted"
    except (OSError, __import__("subprocess").SubprocessError):
        return "uncommitted"


def substitutions(args: argparse.Namespace) -> dict[str, str]:
    kind = dict(KINDS[args.kind])
    # every key is available under both its raw and its upper-case marker form
    for lower, upper in ALIASES.items():
        kind[upper] = kind.get(upper, kind.get(lower, ""))
    kind.update(
        {
            "@NAME@": args.name,
            "@SLUG@": args.slug,
            "@ONE_LINE@": args.one_line,
            "@DATE@": datetime.date.today().isoformat(),
            "@SHA@": head(),
            "@EVIDENCE@": "skeleton created; nothing has been built or run yet",
            "@WHAT@": args.one_line,
            "@AUTHORITY@": (
                "`PLAN.md` is the plan of record when this project has one; "
                "otherwise `AGENTS.md` holds the locked decisions."
            ),
            "@LAYOUT@": f"{args.slug}/\n  README.md\n  AGENTS.md\n  STATE.md\n  CHANGELOG.md\n  docs/README.md",
            "@IDENTITY@": f"{args.one_line}",
            "@PLAN_STATE@": (
                "**Status: PLAN APPROVED** — binding."
                if args.plan
                else "not present — this project has no plan of record yet."
            ),
            "@IN@": args.one_line,
            "@OUT@": "Anything not named in the one-line description above.",
            "@TRAP@": "None recorded yet. Add one the first time something costs an hour.",
            "@AREA@": "Skeleton",
            "@AREA_STATUS@": "created",
            "@AREA_EVIDENCE@": "`scripts/new_project.py` (see CHANGELOG.md)",
            "@OPEN@": "Everything — this project has not been built or run yet.",
            "@REVERIFY@": "# run the project's own test command, then update the pin above",
        }
    )
    return kind


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("slug", help="lower-case directory name, e.g. myproj")
    ap.add_argument("--name", required=True, help="human name, e.g. 'My Project'")
    ap.add_argument("--one-line", required=True, help="one-line description")
    ap.add_argument("--kind", choices=sorted(KINDS), default="docs")
    ap.add_argument("--plan", action="store_true", help="project will have a PLAN.md")
    ap.add_argument(
        "--into", default="projects", help="parent directory (default: projects)"
    )
    ap.add_argument(
        "--force", action="store_true", help="write into an existing directory"
    )
    a = ap.parse_args()

    import re as _re

    if not _re.match(SLUG_RE, a.slug):
        print(
            f"error: '{a.slug}' is not a valid slug (lower-case, digits, dashes)",
            file=sys.stderr,
        )
        return 2
    if not TEMPLATES.is_dir():
        print(f"error: templates not found at {TEMPLATES}", file=sys.stderr)
        return 2

    dest = (REPO / a.into / a.slug).resolve()
    if dest.exists() and any(dest.iterdir()) and not a.force:
        print(
            f"error: {dest} already exists and is not empty (use --force to overwrite)",
            file=sys.stderr,
        )
        return 2

    subs = substitutions(a)
    written: list[str] = []
    for src in sorted(p for p in TEMPLATES.rglob("*") if p.is_file()):
        rel = src.relative_to(TEMPLATES)
        out = dest / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        text = src.read_text()
        for marker, value in subs.items():
            text = text.replace(marker, value)
        out.write_text(text)
        written.append(str(rel))

    print(f"created {dest.relative_to(REPO)}/")
    for rel in sorted(written):
        print(f"  {rel}")
    print()
    print("next:")
    print(
        f"  1. fill the @-free sections in {a.into}/{a.slug}/AGENTS.md (scope, decisions, traps)"
    )
    print(f"  2. make projects-check     # the skeleton is well-formed")
    print(f"  3. make docs-check         # the pin is green while HEAD is unchanged")
    print(f"  4. git add {a.into}/{a.slug} && git commit")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
