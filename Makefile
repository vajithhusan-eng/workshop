.PHONY: help backend frontend setup clean push test test-unit test-api test-frontend verify lint dev-status dev-targets dev-down dev-preview dev-review docs-check projects-check check

help:
	@echo "WORKSHOP Commands:"
	@echo "  make backend      - Start finance backend (:8123)"
	@echo "  make frontend     - Start flutter web (:8081)"
	@echo "  make dev-status   - Show every live build/runtime: session, port, pid, health"
	@echo "  make dev-targets  - List supervisable targets"
	@echo "  make dev-down     - Stop everything devsup started"
	@echo "  make dev-start X  - Start target X on a free port (backend|frontend|agora)"
	@echo "  make dev-preview X - Print the browser-preview URL for target X (opens nothing)"
	@echo "  make dev-review on|off|status - Arm/disarm opening a browser (default OFF)"
	@echo "  make docs-check      - Fail if a STATE.md pin does not resolve, or an agent is shadowed"
	@echo "  make projects-check  - Fail if a project is missing its standard files"
	@echo "  make check           - projects-check + docs-check (the full gate)"
	@echo "  make test         - Run all tests (unit + api + frontend)"
	@echo "  make test-unit    - Forensic math + watch-loop rules (no server needed)"
	@echo "  make test-api     - API smoke test (needs backend running)"
	@echo "  make test-frontend- Flutter analyze + widget/wire tests (no server needed)"
	@echo "  make lint         - flutter analyze (must be clean)"
	@echo "  make verify       - test-unit + test-frontend + boot backend + test-api"
	@echo "  make setup        - Setup all projects"
	@echo "  make clean        - Clean all build artifacts"
	@echo "  make push         - Push master to GitHub (needs credentials)"

# -- devsup: live build + runtime, per project and per session ---------------
# Ports are allocated, not demanded: if 8123 is busy devsup takes 8124, so two
# sessions on the same project coexist instead of the second one dying.
# Pass a session to keep concurrent lines of work apart:
#   make dev-start backend SESSION=alpha

dev-start:
	python3 scripts/devsup.py start $(or $(TARGET),backend) $(if $(SESSION),--session $(SESSION))

dev-status:
	python3 scripts/devsup.py status

dev-targets:
	python3 scripts/devsup.py targets

dev-down:
	python3 scripts/devsup.py down

dev-preview:
	python3 scripts/devsup.py preview $(TARGET)

dev-review:
	python3 scripts/devsup.py review $(ACTION)

push:
	@echo "🚀 Pushing master to GitHub (vajithhusan-eng/workshop)…"
	git push origin master

backend:
	cd backend && ./.venv/bin/python run.py

frontend:
	cd frontend && flutter run -d web-server --web-port=8081 --release

# ── tests ────────────────────────────────────────────────────────────────────
# The product's claim is statistical integrity. If the forensics math or its
# wiring is wrong, the app is confidently lying to people about their money, so
# these run on every change and are not optional decoration.

test: test-unit test-api test-frontend

# Pure math, no server. Safe to run anywhere.
test-unit:
	@echo "── forensics math ──"
	cd backend && ./.venv/bin/python -m app.tests.test_forensics
	@echo "── execution forensics ──"
	cd backend && ./.venv/bin/python -m app.tests.test_execution
	@echo "── watch loop rules ──"
	cd backend && ./.venv/bin/python -m app.tests.test_watchloop

# End-to-end over HTTP. Needs the backend up.
test-api:
	@echo "── api smoke ──"
	cd backend && ./.venv/bin/python -m app.tests.test_api

# One-shot: unit tests, boot the backend, API tests, tear down. This is the
# gate to run before committing.
# Analyzer plus the widget + wire-contract tests. No server needed.
# The wire tests assert the frontend sends the keys the backend actually
# accepts — that pair has already drifted once and silently, so it is gated.
test-frontend: lint
	@echo "── flutter tests ──"
	cd frontend && flutter test

lint:
	@echo "── flutter analyze ──"
	cd frontend && flutter analyze

# Pre-commit gate: unit math, frontend lint+tests, then boot a real backend
# and hit it over HTTP.
verify: test-unit test-frontend
	@bash scripts/verify_api.sh

docs-check:
	@python3 scripts/verify_docs.py

# Does every project carry the standard document set?
projects-check:
	@python3 scripts/verify_projects.py

# The full gate. Both checks run even if the first fails, so one failure does
# not hide the other.
check:
	@python3 scripts/verify_projects.py; p=$$?; \
	 python3 scripts/verify_docs.py; d=$$?; \
	 if [ $$p -eq 0 ] && [ $$d -eq 0 ]; then echo "make check: all green"; \
	 else echo "make check: FAILED (projects-check=$$p docs-check=$$d)"; exit 1; fi

setup:
	cd backend && ./.venv/bin/python run.py
	cd frontend && flutter run -d web-server --web-port=8081 --release

clean:
	find . -type d -name "__pycache__" -not -path "*/.venv/*" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -not -path "*/.venv/*" -delete 2>/dev/null || true
	rm -f backend/omnivest_journal.json
	cd frontend && flutter clean 2>/dev/null || true
