"""Dependency injection module for the Multi-AI Agent Orchestrator backend.

This module provides FastAPI dependency functions for database sessions,
WebSocket managers, authentication, error handling, and pagination utilities.
"""

from typing import Generator, AsyncGenerator, Optional, Dict, Any, List
from fastapi import Depends, WebSocket, WebSocketDisconnect, HTTPException, Query
from fastapi.security import APIKeyHeader
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import SessionLocal, async_session, get_async_db
from app.config import settings
from app.services.websocket_manager import WebSocketManager
from app.services.orchestration_engine import OrchestrationEngine

# Global service instances
_ws_manager = WebSocketManager()
_orchestration_engine = OrchestrationEngine()

# API key header scheme for authentication
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


# ---------------------------------------------------------------------------
# Database dependencies
# ---------------------------------------------------------------------------


def get_ws_manager() -> WebSocketManager:
    """Dependency that returns the global WebSocketManager instance.

    Returns:
        WebSocketManager: The WebSocket manager instance.
    """
    return _ws_manager


def get_orchestration_engine() -> OrchestrationEngine:
    """Dependency that returns the global OrchestrationEngine instance.

    Returns:
        OrchestrationEngine: The orchestration engine instance.
    """
    return _orchestration_engine


def get_db() -> Generator[Session, None, None]:
    """FastAPI dependency that provides a database session.

    Yields:
        Session: A SQLAlchemy database session that is automatically closed.

    Usage:
        ```python
        @app.get("/sessions")
        async def get_sessions(db: Session = Depends(get_db)):
            ...
        ```
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


async def get_async_db() -> AsyncGenerator[AsyncSession, None]:
    """Async FastAPI dependency for async database sessions."""
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()


# ---------------------------------------------------------------------------
# Authentication dependencies
# ---------------------------------------------------------------------------


async def get_current_user(
    api_key: Optional[str] = Depends(api_key_header),
) -> str:
    """Async dependency for API key authentication.

    Args:
        api_key: The API key from the X-API-Key request header.

    Returns:
        str: The authenticated user identifier.

    Raises:
        HTTPException: If the API key is missing or invalid.
    """
    if not api_key or api_key != settings.API_KEY:
        raise HTTPException(
            status_code=401,
            detail="Invalid or missing API key",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return "authenticated_user"


# ---------------------------------------------------------------------------
# WebSocket dependencies
# ---------------------------------------------------------------------------


def get_websocket_manager() -> WebSocketManager:
    """Dependency that returns the global WebSocketManager instance.

    Returns:
        WebSocketManager: The WebSocket manager instance.
    """
    return _ws_manager


# ---------------------------------------------------------------------------
# Error handling exceptions
# ---------------------------------------------------------------------------


class ValidationError(Exception):
    """Raised when input validation fails.

    Attributes:
        message: A human-readable description of the validation error.
        field: The name of the field that failed validation, if applicable.
    """

    def __init__(self, message: str, field: Optional[str] = None):
        self.message = message
        self.field = field
        super().__init__(self.message)


class NotFoundError(Exception):
    """Raised when a requested resource does not exist.

    Attributes:
        resource_type: The type of resource that was not found.
        resource_id: The identifier of the resource that was not found.
    """

    def __init__(self, resource_type: str, resource_id: str):
        self.resource_type = resource_type
        self.resource_id = resource_id
        self.message = f"{resource_type} with id '{resource_id}' not found"
        super().__init__(self.message)


class PermissionDeniedError(Exception):
    """Raised when a user does not have permission to perform an action."""

    def __init__(self, action: str, resource: str = ""):
        self.action = action
        self.resource = resource
        self.message = f"Permission denied to {action} on {resource}".strip()
        super().__init__(self.message)


class ConflictError(Exception):
    """Raised when a resource conflict occurs (e.g., duplicate entry)."""

    def __init__(self, message: str):
        self.message = message
        super().__init__(self.message)


class ServiceUnavailableError(Exception):
    """Raised when an external service is unavailable."""

    def __init__(self, service_name: str):
        self.service_name = service_name
        self.message = f"Service '{service_name}' is currently unavailable"
        super().__init__(self.message)


# ---------------------------------------------------------------------------
# Pagination helper
# ---------------------------------------------------------------------------


class PaginationParams:
    """Pagination parameters extracted from query string arguments.

    Attributes:
        page: The page number (1-indexed).
        page_size: The number of items per page.
        offset: The computed offset for the database query.
    """

    def __init__(self, page: int, page_size: int, offset: int):
        self.page = page
        self.page_size = page_size
        self.offset = offset

    def __repr__(self) -> str:
        return f"PaginationParams(page={self.page}, page_size={self.page_size}, offset={self.offset})"


async def get_pagination(
    page: int = Query(1, ge=1, description="Page number (1-indexed)"),
    page_size: int = Query(50, ge=1, le=1000, description="Items per page"),
) -> PaginationParams:
    """Async dependency that parses pagination query parameters.

    Args:
        page: The page number (must be >= 1).
        page_size: The number of items per page (1 <= page_size <= 1000).

    Returns:
        PaginationParams: Computed pagination parameters including offset.
    """
    offset = (page - 1) * page_size
    return PaginationParams(page=page, page_size=page_size, offset=offset)


class PaginatedResult(Dict[str, Any]):
    """Represents a paginated result set.

    Attributes:
        items: The items on the current page.
        total: Total number of items across all pages.
        page: Current page number.
        page_size: Number of items per page.
        total_pages: Total number of pages.
        has_next: Whether there is a next page.
        has_prev: Whether there is a previous page.
    """

    def __init__(
        self,
        items: List[Any],
        total: int,
        page: int,
        page_size: int,
    ):
        total_pages = max(1, (total + page_size - 1) // page_size)
        super().__init__(
            items=items,
            total=total,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
            has_next=page < total_pages,
            has_prev=page > 1,
        )


def build_paginated_response(
    items: List[Any],
    total: int,
    page: int,
    page_size: int,
) -> PaginatedResult:
    """Build a paginated response dictionary.

    Args:
        items: The items for the current page.
        total: Total number of items.
        page: Current page number.
        page_size: Number of items per page.

    Returns:
        PaginatedResult: A dictionary with pagination metadata and items.
    """
    return PaginatedResult(items=items, total=total, page=page, page_size=page_size)


# ---------------------------------------------------------------------------
# WebSocket connection wrapper
# ---------------------------------------------------------------------------


class WebSocketConnection:
    """Represents a WebSocket connection with session context.

    Attributes:
        websocket: The active WebSocket connection.
        session_id: The associated session ID, if any.
        agent_id: The associated agent ID, if any.
    """

    def __init__(
        self, websocket: WebSocket, session_id: str = None, agent_id: str = None
    ):
        self.websocket = websocket
        self.session_id = session_id
        self.agent_id = agent_id

    async def send(self, data: dict) -> None:
        """Send a JSON message through the WebSocket."""
        await self.websocket.send_json(data)

    async def receive(self) -> dict:
        """Receive and parse a JSON message from the WebSocket."""
        data = await self.websocket.receive_json()
        return data
