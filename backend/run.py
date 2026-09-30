"""OMNIVEST backend entry — `cd backend && ./.venv/bin/python run.py` → :8123"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import uvicorn

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8123, reload=True)
