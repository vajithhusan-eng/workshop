.PHONY: help dev build clean story appimage setup

help: ## Show this help message
	@echo "Multi-AI Agent Orchestrator - Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make help     - Show this help message"
	@echo "  make dev      - Start development servers"
	@echo "  make build    - Build the project"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make story    - Start story orchestration"
	@echo "  make appimage - Build Linux AppImage"
	@echo "  make setup    - Setup all dependencies"

dev: ## Start backend and frontend development servers
	@echo "Starting backend server..."
	cd backend && pip install -r requirements.txt && python run.py &
	@echo "Starting frontend..."
	cd frontend && flutter pub get && flutter run &
	@echo "Development servers started!"

build: ## Build the project
	@echo "Building backend Docker image..."
	cd backend && docker build -t story-app-backend .
	@echo "Building frontend..."
	cd frontend && flutter build linux
	@echo "Build complete!"

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	cd backend && rm -f sessions.db
	cd frontend && flutter clean
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "Clean complete!"

story: ## Start story orchestration
	@echo "Starting story orchestration..."
	cd backend && python run.py

appimage: ## Build Linux AppImage
	@echo "Building AppImage..."
	bash scripts/build_appimage.sh

setup: ## Setup all dependencies
	@echo "Setting up Multi-AI Agent Orchestrator..."
	cd backend && pip install -r requirements.txt
	cd backend && pip install uvicorn[standard] aiosqlite playwright
	cd backend && playwright install chromium
	cd frontend && flutter pub get
	mkdir -p backend/data
	@echo "Setup complete!"
