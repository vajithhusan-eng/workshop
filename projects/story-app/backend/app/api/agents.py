"""API endpoints for agent management.

Provides CRUD operations for agents registered within sessions,
including connection control and leader designation.
"""

import logging
from typing import List, Optional, Dict, Any
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.agent import Agent, AgentTable
from app.models.session import Session, SessionTable
from app.models.message import Message, MessageTable
from app.schemas.agent import AgentCreate, AgentUpdate, AgentResponse
from app.services.leader_election import LeaderElectionManager
from app.services.chrome_controller import ChromeController

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/sessions/{session_id}/agents", tags=["agents"])

_leader_election = LeaderElectionManager()
_chrome_controller = ChromeController()


@router.post("/", response_model=AgentResponse, status_code=status.HTTP_201_CREATED)
async def register_agent(
    session_id: str,
    payload: AgentCreate,
    db: Session = Depends(get_db),
):
    """Register a new agent in a session.

    Args:
        session_id: The session ID to register the agent in.
        payload: Agent registration data.
        db: Database session dependency.

    Returns:
        The created AgentResponse.
    """
    try:
        session = db.query(Session).filter(Session.id == session_id).first()
        if not session:
            raise HTTPException(
                status_code=404, detail=f"Session {session_id} not found"
            )

        agent = Agent(
            session_id=session_id,
            name=payload.name,
            type=payload.type,
            provider=payload.provider,
            web_url=payload.web_url,
            status="idle",
            config=payload.config or {},
            role=payload.role,
        )
        db.add(agent)
        db.commit()
        db.refresh(agent)
        logger.info(f"Agent {agent.id} registered in session {session_id}")
        return AgentResponse.model_validate(agent)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error registering agent: {e}")
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Error registering agent: {e}")


@router.get("/", response_model=List[AgentResponse])
async def list_agents(
    session_id: str,
    db: Session = Depends(get_db),
):
    """List all agents in a session.

    Args:
        session_id: The session ID.
        db: Database session dependency.

    Returns:
        List of AgentResponse objects.
    """
    try:
        session = db.query(Session).filter(Session.id == session_id).first()
        if not session:
            raise HTTPException(
                status_code=404, detail=f"Session {session_id} not found"
            )

        agents = db.query(Agent).filter(Agent.session_id == session_id).all()
        return [AgentResponse.model_validate(agent) for agent in agents]
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error listing agents for session {session_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error listing agents: {e}")


@router.get("/{agent_id}", response_model=AgentResponse)
async def get_agent(
    session_id: str,
    agent_id: str,
    db: Session = Depends(get_db),
):
    """Get details about a specific agent.

    Args:
        session_id: The session ID.
        agent_id: The agent ID.
        db: Database session dependency.

    Returns:
        AgentResponse with agent details.
    """
    try:
        agent = (
            db.query(Agent)
            .filter(Agent.id == agent_id, Agent.session_id == session_id)
            .first()
        )
        if not agent:
            raise HTTPException(
                status_code=404,
                detail=f"Agent {agent_id} not found in session {session_id}",
            )
        return AgentResponse.model_validate(agent)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting agent {agent_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting agent: {e}")


@router.put("/{agent_id}", response_model=AgentResponse)
async def update_agent(
    session_id: str,
    agent_id: str,
    payload: AgentUpdate,
    db: Session = Depends(get_db),
):
    """Update an agent's configuration.

    Args:
        session_id: The session ID.
        agent_id: The agent ID to update.
        payload: Fields to update.
        db: Database session dependency.

    Returns:
        The updated AgentResponse.
    """
    try:
        agent = (
            db.query(Agent)
            .filter(Agent.id == agent_id, Agent.session_id == session_id)
            .first()
        )
        if not agent:
            raise HTTPException(status_code=404, detail=f"Agent {agent_id} not found")

        update_data = payload.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(agent, key, value)

        agent.updated_at = datetime.utcnow() if hasattr(agent, "updated_at") else None
        db.commit()
        db.refresh(agent)
        logger.info(f"Agent {agent_id} updated")
        return AgentResponse.model_validate(agent)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating agent {agent_id}: {e}")
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Error updating agent: {e}")


@router.delete("/{agent_id}", status_code=status.HTTP_200_OK)
async def remove_agent(
    session_id: str,
    agent_id: str,
    db: Session = Depends(get_db),
):
    """Remove an agent from a session.

    Args:
        session_id: The session ID.
        agent_id: The agent ID to remove.
        db: Database session dependency.

    Returns:
        Confirmation message.
    """
    try:
        agent = (
            db.query(Agent)
            .filter(Agent.id == agent_id, Agent.session_id == session_id)
            .first()
        )
        if not agent:
            raise HTTPException(status_code=404, detail=f"Agent {agent_id} not found")

        db.delete(agent)
        db.commit()
        logger.info(f"Agent {agent_id} removed from session {session_id}")
        return {"message": f"Agent {agent_id} removed successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error removing agent {agent_id}: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error removing agent: {e}")


@router.post("/{agent_id}/connect")
async def connect_agent(
    session_id: str,
    agent_id: str,
    db: Session = Depends(get_db),
):
    """Connect an agent to Chrome browser via Playwright.

    Args:
        session_id: The session ID.
        agent_id: The agent ID to connect.
        db: Database session dependency.

    Returns:
        Connection status.
    """
    try:
        agent = (
            db.query(Agent)
            .filter(Agent.id == agent_id, Agent.session_id == session_id)
            .first()
        )
        if not agent:
            raise HTTPException(status_code=404, detail=f"Agent {agent_id} not found")

        success = await _chrome_controller.connect_agent(agent)
        if success:
            agent.connect()
            db.commit()
            logger.info(f"Agent {agent_id} connected to Chrome")
            return {
                "agent_id": agent_id,
                "connected": True,
                "browser_url": agent.web_url,
            }
        else:
            raise HTTPException(
                status_code=500, detail="Failed to connect agent to Chrome"
            )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error connecting agent {agent_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error connecting agent: {e}")


@router.post("/{agent_id}/disconnect")
async def disconnect_agent(
    session_id: str,
    agent_id: str,
    db: Session = Depends(get_db),
):
    """Disconnect an agent from Chrome browser.

    Args:
        session_id: The session ID.
        agent_id: The agent ID to disconnect.
        db: Database session dependency.

    Returns:
        Disconnection status.
    """
    try:
        agent = (
            db.query(Agent)
            .filter(Agent.id == agent_id, Agent.session_id == session_id)
            .first()
        )
        if not agent:
            raise HTTPException(status_code=404, detail=f"Agent {agent_id} not found")

        agent.disconnect()
        db.commit()
        logger.info(f"Agent {agent_id} disconnected from Chrome")
        return {"agent_id": agent_id, "disconnected": True}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error disconnecting agent {agent_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error disconnecting agent: {e}")


@router.post("/{agent_id}/set-leader")
async def set_leader(
    session_id: str,
    agent_id: str,
    db: Session = Depends(get_db),
):
    """Designate an agent as the session leader.

    Args:
        session_id: The session ID.
        agent_id: The agent ID to set as leader.
        db: Database session dependency.

    Returns:
        Confirmation message.
    """
    try:
        agent = (
            db.query(Agent)
            .filter(Agent.id == agent_id, Agent.session_id == session_id)
            .first()
        )
        if not agent:
            raise HTTPException(status_code=404, detail=f"Agent {agent_id} not found")

        _leader_election.designate_leader(session_id, agent_id)
        session = db.query(Session).filter(Session.id == session_id).first()
        if session:
            session.leader_id = agent_id
            db.commit()
        logger.info(f"Agent {agent_id} designated as leader for session {session_id}")
        return {
            "session_id": session_id,
            "leader_id": agent_id,
            "message": "Leader set successfully",
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error setting leader for session {session_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error setting leader: {e}")


@router.get("/{agent_id}/status")
async def get_agent_status(
    session_id: str,
    agent_id: str,
    db: Session = Depends(get_db),
):
    """Get the connection status of an agent.

    Args:
        session_id: The session ID.
        agent_id: The agent ID.
        db: Database session dependency.

    Returns:
        Agent status information.
    """
    try:
        agent = (
            db.query(Agent)
            .filter(Agent.id == agent_id, Agent.session_id == session_id)
            .first()
        )
        if not agent:
            raise HTTPException(status_code=404, detail=f"Agent {agent_id} not found")

        return {
            "agent_id": agent.id,
            "name": agent.name,
            "status": agent.status,
            "is_connected": agent.is_connected,
            "last_heartbeat": agent.last_heartbeat,
            "message_count": agent.message_count,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting status for agent {agent_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting agent status: {e}")
