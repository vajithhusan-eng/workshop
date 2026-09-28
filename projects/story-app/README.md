# Multi-AI Agent Orchestrator

A sophisticated system for orchestrating multiple AI agents working collaboratively on story creation. Built with FastAPI (Python) backend and Flutter desktop frontend.

## Features

- **Multi-Agent Orchestration**: Coordinate multiple AI agents working together on story creation
- **Leader Election**: Automatic leader election among agents for coordinated decision-making
- **Real-Time Communication**: WebSocket-based real-time messaging between agents and the UI
- **Chrome Integration**: Browser automation via Playwright for agent tasks
- **Story Lifecycle Management**: Complete session lifecycle from creation to completion

## Project Structure

```
story-app/
├── backend/          # FastAPI backend server
├── frontend/         # Flutter desktop application
├── scripts/          # Setup and build scripts
├── Makefile          # Project commands
├── docker-compose.yml
├── .env.example
└── ARCHITECTURE.md
```

## Quick Start

### Prerequisites

- Python 3.11+
- Flutter 3.0+
- Docker & Docker Compose
- Node.js (for Playwright)

### Installation

```bash
# Copy environment file
cp .env.example .env

# Install backend dependencies
cd backend
pip install -r requirements.txt
pip install uvicorn[standard] aiosqlite playwright
playwright install chromium

# Run the backend
python run.py
```

### Development

```bash
# Start both backend and frontend
make dev

# Or use Docker
docker-compose up --build
```

### Run Story Orchestration

```bash
make story
```

## API Documentation

The backend API is available at `http://localhost:8000/docs` (Swagger UI) once running.

### Endpoints

- `GET /health` - Health check
- `GET /` - Root endpoint
- `POST /api/v1/sessions` - Create a session
- `GET /api/v1/sessions` - List sessions
- `POST /api/v1/agents` - Create an agent
- `POST /api/v1/messages` - Send a message
- `WS /ws/{session_id}` - WebSocket connection

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation.

## License

MIT
