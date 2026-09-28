"""API endpoints for message management.

Provides endpoints for sending and retrieving messages within sessions.
"""

import logging
from typing import List, Optional, Dict, Any
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.message import Message, MessageTable
from app.models.agent import Agent, AgentTable
from app.models.session import Session, SessionTable
from app.schemas.message import (
    MessageCreate,
    MessageResponse,
    MessageHistoryResponse,
    MessageStats,
)
from app.services.message_router import MessageRouter
from app.services.websocket_manager import WebSocketManager

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/sessions/{session_id}/messages", tags=["messages"])

_message_router = MessageRouter()
_ws_manager = WebSocketManager()


@router.post("/", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def send_message(
    session_id: str,
    payload: MessageCreate,
    db: Session = Depends(get_db),
):
    """Send a message to an agent within a session.

    Args:
        session_id: The session ID.
        payload: Message data including agent_id, content, and role.
        db: Database session dependency.

    Returns:
        The created MessageResponse.
    """
    try:
        # Verify session exists
        session = db.query(Session).filter(Session.id == session_id).first()
        if not session:
            raise HTTPException(
                status_code=404, detail=f"Session {session_id} not found"
            )

        # Verify agent exists
        agent = (
            db.query(Agent)
            .filter(Agent.id == payload.agent_id, Agent.session_id == session_id)
            .first()
        )
        if not agent:
            raise HTTPException(
                status_code=404,
                detail=f"Agent {payload.agent_id} not found in session {session_id}",
            )

        # Create message
        message = Message(
            session_id=session_id,
            agent_id=payload.agent_id,
            role=payload.role,
            content=payload.content,
            iteration=payload.iteration,
            is_from_browser=payload.is_from_browser,
            content_type=payload.content_type,
        )
        db.add(message)
        db.commit()
        db.refresh(message)

        # Update agent message count
        agent.increment_message_count()
        db.commit()

        # Broadcast via WebSocket
        await _ws_manager.send_personal(message.to_dict(), session_id)

        logger.info(f"Message sent by agent {payload.agent_id} in session {session_id}")
        return MessageResponse.model_validate(message)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error sending message in session {session_id}: {e}")
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Error sending message: {e}")


@router.get("/", response_model=List[MessageResponse])
async def get_messages(
    session_id: str,
    agent_id: Optional[str] = Query(None, description="Filter messages by agent ID"),
    limit: int = Query(
        default=100, ge=1, le=1000, description="Maximum number of messages"
    ),
    offset: int = Query(default=0, ge=0, description="Pagination offset"),
    db: Session = Depends(get_db),
):
    """Retrieve messages for a session.

    Args:
        session_id: The session ID.
        agent_id: Optional filter by agent ID.
        limit: Maximum number of messages to return.
        offset: Pagination offset.
        db: Database session dependency.

    Returns:
        List of MessageResponse objects ordered by timestamp.
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


@router.get("/history", response_model=Dict[str, Any])
async def get_history(
    session_id: str,
    db: Session = Depends(get_db),
):
    """Get full conversation history for a session.

    Args:
        session_id: The session ID.
        db: Database session dependency.

    Returns:
        Dictionary with session info and full message history.
    """
    try:
        session = db.query(Session).filter(Session.id == session_id).first()
        if not session:
            raise HTTPException(
                status_code=404, detail=f"Session {session_id} not found"
            )

        messages = (
            db.query(Message)
            .filter(Message.session_id == session_id)
            .order_by(Message.created_at.asc())
            .all()
        )
        agents = db.query(Agent).filter(Agent.session_id == session_id).all()

        return {
            "session_id": session_id,
            "session_name": session.name,
            "total_messages": len(messages),
            "agents_count": len(agents),
            "agents": [agent.to_dict() for agent in agents],
            "messages": [msg.to_dict() for msg in messages],
            "created_at": session.created_at.isoformat()
            if session.created_at
            else None,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting history for session {session_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting history: {e}")


@router.get("/stats", response_model=MessageStats)
async def get_message_stats(
    session_id: str,
    db: Session = Depends(get_db),
):
    """Get message statistics for a session.

    Args:
        session_id: The session ID.
        db: Database session dependency.

    Returns:
        Message statistics including counts by agent, role, and iteration.
    """
    try:
        messages = db.query(Message).filter(Message.session_id == session_id).all()

        if not messages:
            return MessageStats(
                session_id=session_id,
                total_messages=0,
                messages_by_agent={},
                messages_by_role={},
                messages_by_iteration={},
                from_browser_count=0,
                average_messages_per_iteration=0.0,
            )

        messages_by_agent = {}
        messages_by_role = {}
        messages_by_iteration = {}
        from_browser_count = 0
        total_iterations = set()

        for msg in messages:
            messages_by_agent[msg.agent_id] = messages_by_agent.get(msg.agent_id, 0) + 1
            messages_by_role[msg.role] = messages_by_role.get(msg.role, 0) + 1
            messages_by_iteration[msg.iteration] = (
                messages_by_iteration.get(msg.iteration, 0) + 1
            )
            total_iterations.add(msg.iteration)
            if msg.is_from_browser:
                from_browser_count += 1

        iterations_count = len(total_iterations)
        avg = len(messages) / iterations_count if iterations_count > 0 else 0.0

        return MessageStats(
            session_id=session_id,
            total_messages=len(messages),
            messages_by_agent=messages_by_agent,
            messages_by_role=messages_by_role,
            messages_by_iteration=messages_by_iteration,
            from_browser_count=from_browser_count,
            average_messages_per_iteration=avg,
        )
    except Exception as e:
        logger.error(f"Error getting message stats for session {session_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting statistics: {e}")
