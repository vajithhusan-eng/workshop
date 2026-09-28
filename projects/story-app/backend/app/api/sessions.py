"""API endpoints for session management.

Provides CRUD operations for sessions including creation, retrieval,
update, deletion, and orchestration control.
"""

import logging
from typing import List, Optional, Dict, Any
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.session import (
    SessionCreate,
    SessionUpdate,
    SessionResponse,
    SessionDetail,
    SessionStatus,
)
from app.schemas.message import MessageResponse
from app.services.orchestration_engine import OrchestrationEngine
from app.services.websocket_manager import WebSocketManager

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/sessions", tags=["sessions"])

# Service instances
_orchestration_engine = OrchestrationEngine()
_ws_manager = WebSocketManager()


@router.get("/", response_model=List[SessionResponse])
async def list_sessions(
    page: int = Query(default=1, ge=1, description="Page number"),
    size: int = Query(default=20, ge=1, le=100, description="Page size"),
    status: Optional[str] = Query(None, description="Filter by session status"),
    db: Session = Depends(get_db),
):
    """List all sessions with optional pagination and filtering.

    Args:
        page: Page number for pagination.
        size: Number of results per page.
        status: Optional filter by session status.
        db: Database session dependency.

    Returns:
        List of SessionResponse objects.
    """
    try:
        offset = (page - 1) * size
        query = db.query(type("Session", (), {}))  # Will be replaced
        if status:
            query = query.filter(Session.status == status)
        total = (
            db.query(Session).filter(Session.status == status).count()
            if status
            else db.query(Session).count()
        )
        sessions = (
            db.query(Session)
            .filter(Session.status == status)
            .offset(offset)
            .limit(size)
            .all()
            if status
            else db.query(Session).offset(offset).limit(size).all()
        )
        return sessions
    except Exception as e:
        logger.error(f"Error listing sessions: {e}")
        raise HTTPException(status_code=500, detail=f"Error listing sessions: {e}")


@router.post("/", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
async def create_session(
    payload: SessionCreate,
    db: Session = Depends(get_db),
):
    """Create a new session.

    Args:
        payload: Session creation data.
        db: Database session dependency.

    Returns:
        The created SessionResponse.
    """
    try:
        session = Session(
            name=payload.name,
            description=payload.description or "",
            status="active",
            agent_ids=[],
            max_iterations=payload.max_iterations,
            created_by=payload.created_by or "user",
            config=payload.config or {},
        )
        db.add(session)
        db.commit()
        db.refresh(session)
        logger.info(f"Session created: {session.id}")
        return SessionResponse.model_validate(session)
    except Exception as e:
        logger.error(f"Error creating session: {e}")
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Error creating session: {e}")


@router.get("/{session_id}", response_model=SessionDetail)
async def get_session(
    session_id: str,
    db: Session = Depends(get_db),
):
    """Get detailed information about a specific session.

    Args:
        session_id: The session ID.
        db: Database session dependency.

    Returns:
        SessionDetail with agents and messages included.
    """
    try:
        session = db.query(Session).filter(Session.id == session_id).first()
        if not session:
            raise HTTPException(
                status_code=404, detail=f"Session {session_id} not found"
            )
        return SessionDetail.model_validate(session)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting session {session_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting session: {e}")


@router.put("/{session_id}", response_model=SessionResponse)
async def update_session(
    session_id: str,
    payload: SessionUpdate,
    db: Session = Depends(get_db),
):
    """Update an existing session.

    Args:
        session_id: The session ID to update.
        payload: Fields to update.
        db: Database session dependency.

    Returns:
        The updated SessionResponse.
    """
    try:
        session = db.query(Session).filter(Session.id == session_id).first()
        if not session:
            raise HTTPException(
                status_code=404, detail=f"Session {session_id} not found"
            )

        update_data = payload.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(session, key, value)

        session.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(session)
        logger.info(f"Session {session_id} updated")
        return SessionResponse.model_validate(session)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating session {session_id}: {e}")
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Error updating session: {e}")


@router.delete("/{session_id}", status_code=status.HTTP_200_OK)
async def delete_session(
    session_id: str,
    db: Session = Depends(get_db),
):
    """Delete a session and all associated data.

    Args:
        session_id: The session ID to delete.
        db: Database session dependency.

    Returns:
        Confirmation message.
    """
    try:
        session = db.query(Session).filter(Session.id == session_id).first()
        if not session:
            raise HTTPException(
                status_code=404, detail=f"Session {session_id} not found"
            )

        db.delete(session)
        db.commit()
        logger.info(f"Session {session_id} deleted")
        return {
            "message": f"Session {session_id} deleted successfully",
            "deleted_id": session_id,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting session {session_id}: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error deleting session: {e}")


@router.post("/{session_id}/start")
async def start_session(
    session_id: str,
    db: Session = Depends(get_db),
):
    """Start the orchestration engine for a session.

    Args:
        session_id: The session ID to start.
        db: Database session dependency.

    Returns:
        Confirmation message.
    """
    try:
        session = db.query(Session).filter(Session.id == session_id).first()
        if not session:
            raise HTTPException(
                status_code=404, detail=f"Session {session_id} not found"
            )

        session.mark_active()
        db.commit()

        # Start orchestration engine
        await _orchestration_engine.start_session(session_id)
        logger.info(f"Session {session_id} started")
        return {"message": f"Session {session_id} started", "session_id": session_id}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error starting session {session_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error starting session: {e}")


@router.post("/{session_id}/stop")
async def stop_session(
    session_id: str,
    db: Session = Depends(get_db),
):
    """Stop the orchestration engine for a session.

    Args:
        session_id: The session ID to stop.
        db: Database session dependency.

    Returns:
        Confirmation message.
    """
    try:
        session = db.query(Session).filter(Session.id == session_id).first()
        if not session:
            raise HTTPException(
                status_code=404, detail=f"Session {session_id} not found"
            )

        await _orchestration_engine.stop_session(session_id)
        session.status = "archived"
        db.commit()
        logger.info(f"Session {session_id} stopped")
        return {"message": f"Session {session_id} stopped", "session_id": session_id}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error stopping session {session_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error stopping session: {e}")


@router.get("/{session_id}/messages", response_model=List[MessageResponse])
async def get_session_messages(
    session_id: str,
    agent_id: Optional[str] = Query(None, description="Filter by agent ID"),
    limit: int = Query(default=100, ge=1, le=1000),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
):
    """Get all messages for a session.

    Args:
        session_id: The session ID.
        agent_id: Optional filter by agent ID.
        limit: Maximum number of messages to return.
        offset: Pagination offset.
        db: Database session dependency.

    Returns:
        List of MessageResponse objects.
    """
    try:
        query = db.query(Message).filter(Message.session_id == session_id)
        if agent_id:
            query = query.filter(Message.agent_id == agent_id)
        messages = (
            query.order_by(Message.created_at.asc()).offset(offset).limit(limit).all()
        )
        return [MessageResponse.model_validate(msg) for msg in messages]
    except Exception as e:
        logger.error(f"Error getting messages for session {session_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting messages: {e}")


@router.get("/{session_id}/status", response_model=SessionStatus)
async def get_session_status(
    session_id: str,
    db: Session = Depends(get_db),
):
    """Get real-time status of a session.

    Args:
        session_id: The session ID.
        db: Database session dependency.

    Returns:
        SessionStatus with current state information.
    """
    try:
        session = db.query(Session).filter(Session.id == session_id).first()
        if not session:
            raise HTTPException(
                status_code=404, detail=f"Session {session_id} not found"
            )

        agents_count = db.query(Agent).filter(Agent.session_id == session_id).count()
        messages_count = (
            db.query(Message).filter(Message.session_id == session_id).count()
        )

        return SessionStatus(
            session_id=session.id,
            status=session.status,
            current_iteration=session.current_iteration,
            max_iterations=session.max_iterations,
            agents_count=agents_count,
            messages_count=messages_count,
            is_running=session.status == "active",
            started_at=session.started_at,
            completed_at=session.completed_at,
            termination_reason=session.termination_reason,
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting status for session {session_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting status: {e}")
