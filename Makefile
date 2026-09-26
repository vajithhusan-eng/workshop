.PHONY: help backend frontend setup clean
help:
	@echo "WORKSHOP Commands:"
	@echo "  make backend    - Start finance backend"
	@echo "  make frontend   - Start flutter web"
	@echo "  make setup      - Setup all projects"
	@echo "  make clean      - Clean build artifacts"
backend:
	cd backend && ./.venv/bin/python run.py
frontend:
	cd frontend && flutter run -d web-server --web-port=8081 --release
setup:
	cd backend && ./.venv/bin/python run.py
