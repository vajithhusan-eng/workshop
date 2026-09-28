"""Pydantic schema definitions for the Multi-AI Agent Orchestrator.

This module exports all request/response schemas used throughout
the API layer for data validation and serialization.
"""

from datetime import datetime
from typing import List, Dict, Any, Optional

from app.schemas.session import (
    SessionCreate,
    SessionUpdate,
    SessionResponse,
    SessionDetail,
)
from app.schemas.agent import AgentCreate, AgentUpdate, AgentResponse
from app.schemas.message import MessageCreate, MessageResponse
from app.schemas.websocket import (
    WSMessage,
    WSTyping,
    WSMessageResponse,
    WSErrorResponse,
    WSConnectionState,
)

__all__ = [
    # Session schemas
    "SessionCreate",
    "SessionUpdate",
    "SessionResponse",
    "SessionDetail",
    # Agent schemas
    "AgentCreate",
    "AgentUpdate",
    "AgentResponse",
    # Message schemas
    "MessageCreate",
    "MessageResponse",
    # WebSocket schemas
    "WSMessage",
    "WSTyping",
    "WSMessageResponse",
    "WSErrorResponse",
    "WSConnectionState",
]
