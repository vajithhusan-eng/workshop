"""Router definitions for the Multi-AI Agent Orchestrator."""

from fastapi import APIRouter
from app.api import agents_router, messages_router, sessions_router, websocket_router

api_router = APIRouter()

api_router.include_router(agents_router, prefix="/agents", tags=["agents"])
api_router.include_router(messages_router, prefix="/messages", tags=["messages"])
api_router.include_router(sessions_router, prefix="/sessions", tags=["sessions"])
api_router.include_router(websocket_router, prefix="/ws", tags=["websocket"])

__all__ = ["api_router"]
