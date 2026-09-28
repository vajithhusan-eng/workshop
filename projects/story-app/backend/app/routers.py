"""API router registrations for the Multi-AI Agent Orchestrator.

This module creates the main API router and includes all sub-routers
for sessions, agents, messages, and WebSocket endpoints.
"""

from fastapi import APIRouter

from app.api.sessions import router as sessions_router
from app.api.agents import router as agents_router
from app.api.messages import router as messages_router
from app.api.websocket import router as websocket_router

# Main API router
api_router = APIRouter()

# Include all sub-routers
api_router.include_router(sessions_router)
api_router.include_router(agents_router)
api_router.include_router(messages_router)
api_router.include_router(websocket_router)

__all__ = ["api_router"]
