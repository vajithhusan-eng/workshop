"""API routes for the Multi-AI Agent Orchestrator."""

from app.api.agents import router as agents_router
from app.api.messages import router as messages_router
from app.api.sessions import router as sessions_router
from app.api.websocket import router as websocket_router

__all__ = [
    "agents_router",
    "messages_router",
    "sessions_router",
    "websocket_router",
]
