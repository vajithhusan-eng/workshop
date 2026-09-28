"""Entry point for the Multi-AI Agent Orchestrator backend."""

import uvicorn

if __name__ == "__main__":
    print("=" * 60)
    print("  Multi-AI Agent Orchestrator")
    print("  Starting FastAPI backend on http://0.0.0.0:8000")
    print("=" * 60)
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info",
    )
