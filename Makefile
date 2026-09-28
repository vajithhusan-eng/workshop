.PHONY: help backend frontend setup clean story-app story-app-dev story-app-build story-app-clean story-app-appimage push story-app-appimage

help:
	@echo "WORKSHOP Commands:"
	@echo "  make backend        - Start finance backend"
	@echo "  make frontend       - Start flutter web"
	@echo "  make story-app      - Start story-app"
	@echo "  make story-app-dev  - Start story-app dev mode"
	@echo "  make story-app-build - Build story-app"
	@echo "  make story-app-clean - Clean story-app artifacts"
	@echo "  make story-app-appimage - Build story-app AppImage"
	@echo "  make setup          - Setup all projects"
	@echo "  make clean          - Clean all build artifacts"
	@echo "  make push           - Auto-push all changes to GitHub"

push:
	@echo "🚀 Pushing to GitHub..."
	gh repo view vajithhusan-eng/workshop --json name 2>/dev/null && git push origin master || git push origin master
	@echo "✅ Done!"

backend:
	cd backend && ./.venv/bin/python run.py

frontend:
	cd frontend && flutter run -d web-server --web-port=8081 --release

story-app:
	cd projects/story-app && make dev

story-app-dev:
	cd projects/story-app && make dev

story-app-build:
	cd projects/story-app && make build

story-app-clean:
	cd projects/story-app && make clean

story-app-appimage:
	cd projects/story-app && make appimage

setup:
	cd backend && ./.venv/bin/python run.py
	cd projects/story-app && make setup
	cd frontend && flutter run -d web-server --web-port=8081 --release

story-app-appimage:
	cd projects/story-app && make appimage

.PHONY: story-app-appimage
story-app-appimage:
	cd projects/story-app && bash scripts/build_appimage.sh
