.PHONY: help backend frontend setup clean push test test-unit test-api verify

help:
	@echo "WORKSHOP Commands:"
	@echo "  make backend     - Start finance backend (:8123)"
	@echo "  make frontend    - Start flutter web (:8081)"
	@echo "  make test        - Run all tests (unit + api)"
	@echo "  make test-unit   - Forensics math only (no server needed)"
	@echo "  make test-api    - API smoke test (needs backend running)"
	@echo "  make verify      - test-unit + start backend + test-api"
	@echo "  make setup       - Setup all projects"
	@echo "  make clean       - Clean all build artifacts"
	@echo "  make push        - Auto-push all changes to GitHub"

push:
	@echo "🚀 Pushing to GitHub..."
	gh repo view vajithhusan-eng/workshop --json name 2>/dev/null && git push origin master || git push origin master
	@echo "✅ Done!"

backend:
	cd backend && ./.venv/bin/python run.py

frontend:
	cd frontend && flutter run -d web-server --web-port=8081 --release

# ── tests ────────────────────────────────────────────────────────────────────
# The product's claim is statistical integrity. If the forensics math or its
# wiring is wrong, the app is confidently lying to people about their money, so
# these run on every change and are not optional decoration.

test: test-unit test-api

# Pure math, no server. Safe to run anywhere.
test-unit:
	@echo "── forensics math ──"
	cd backend && ./.venv/bin/python -m app.tests.test_forensics

# End-to-end over HTTP. Needs the backend up.
test-api:
	@echo "── api smoke ──"
	cd backend && ./.venv/bin/python -m app.tests.test_api

# One-shot: unit tests, boot the backend, API tests, tear down. This is the
# gate to run before committing.
# Pre-commit gate: unit math, then boot a real backend and hit it over HTTP.
verify: test-unit
	@bash scripts/verify_api.sh

setup:
	cd backend && ./.venv/bin/python run.py
	cd frontend && flutter run -d web-server --web-port=8081 --release

clean:
	find . -type d -name "__pycache__" -not -path "*/.venv/*" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -not -path "*/.venv/*" -delete 2>/dev/null || true
	rm -f backend/omnivest_journal.json
	cd frontend && flutter clean 2>/dev/null || true
