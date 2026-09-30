"""OMNIVEST backend entry.

    cd backend && ./.venv/bin/python run.py     -> http://127.0.0.1:8123

Reload notes
------------
Watch only the `app` package and explicitly exclude the test tree. With the
default watch directory, running the forensics suite touched app/tests/*.py and
the server restarted on every test write — dozens of pointless reloads, and the
reloader occasionally lost the race to re-read run.py. Narrowing the watch is
both faster and stops the flapping.
"""

import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import uvicorn

PORT = int(os.environ.get("OMNIVEST_PORT", "8123"))


def main() -> None:
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=PORT,
        reload=os.environ.get("OMNIVEST_RELOAD", "1") == "1",
        reload_dirs=[str(HERE / "app")],
        reload_excludes=["tests/*", "*.pyc", "__pycache__/*"],
        log_level="info",
    )


if __name__ == "__main__":
    main()
