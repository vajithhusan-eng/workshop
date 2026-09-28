"""WebSocket endpoint for real-time communication.

Handles WebSocket connections for real-time bidirectional communication
between the frontend and the backend orchestration engine.
"""

import logging
import json
import uuid
from typing import Optional, Set
from datetime import datetime

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query

from app.database import get_db
from app.services.websocket_manager import WebSocketManager
from app.services.orchestration_engine import OrchestrationEngine
from app.services.message_router import MessageRouter
from app.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(tags=["websocket"])

_ws_manager = WebSocketManager()
_orchestration_engine = OrchestrationEngine()
_message_router = MessageRouter()

# Track active sessions for orchestration
_active_sessions: Set[str] = set()


async def websocket_endpoint(
    websocket: WebSocket,
    session_id: Optional[str] = Query(None, description="Session ID to join"),
    agent_id: Optional[str] = Query(
        None, description="Agent ID associated with connection"
    ),
):
    """WebSocket endpoint for real-time communication.

    Handles connection, disconnection, and message routing between
    the frontend and the orchestration engine.

    Args:
        websocket: The active WebSocket connection.
        session_id: Optional session ID to join.
        agent_id: Optional agent ID associated with this connection.
    """
    await _ws_manager.connect(websocket, session_id or "global", agent_id)
    client_id = str(uuid.uuid4())
    logger.info(
        f"WebSocket connected: client={client_id}, session={session_id}, agent={agent_id}"
    )

    try:
        while True:
            try:
                data = await websocket.receive_json()
            except ValueError:
                await _ws_manager.send_error(
                    session_id or "global", "INVALID_JSON", "Message is not valid JSON"
                )
                continue

            await _handle_message(data, websocket, session_id, agent_id)

    except WebSocketDisconnect:
        logger.info(f"WebSocket disconnected: client={client_id}, session={session_id}")
    except Exception as e:
        logger.error(f"WebSocket error for client {client_id}: {e}")
    finally:
        await _ws_manager.disconnect(websocket, session_id or "global")


async def _handle_message(
    data: dict,
    websocket: WebSocket,
    session_id: Optional[str],
    agent_id: Optional[str],
):
    """Handle incoming WebSocket messages.

    Args:
        data: The parsed JSON message data.
        websocket: The WebSocket connection.
        session_id: The session ID, if any.
        agent_id: The agent ID, if any.
    """
    try:
        msg_type = data.get("type", "")

        if msg_type == "send_message":
            await _handle_send_message(data, session_id, agent_id)
        elif msg_type == "start_loop":
            await _handle_start_loop(data, session_id)
        elif msg_type == "stop_loop":
            await _handle_stop_loop(data, session_id)
        elif msg_type == "heartbeat":
            await _handle_heartbeat(data, session_id, agent_id)
        elif msg_type == "update_agent":
            await _handle_update_agent(data, session_id, agent_id)
        elif msg_type == "get_status":
            await _handle_get_status(session_id)
        else:
            await _ws_manager.send_error(
                session_id or "global",
                "UNKNOWN_TYPE",
                f"Unknown message type: {msg_type}",
            )
            logger.warning(f"Unknown WebSocket message type: {msg_type}")

    except Exception as e:
        logger.error(f"Error handling WebSocket message: {e}")
        await _ws_manager.send_error(session_id or "global", "HANDLE_ERROR", str(e))


async def _handle_send_message(
    data: dict, session_id: Optional[str], agent_id: Optional[str]
):
    """Handle sending a message to an agent via WebSocket."""
    try:
        content = data.get("content", "")
        if not content:
            await _ws_manager.send_error(
                session_id, "EMPTY_CONTENT", "Message content cannot be empty"
            )
            return

        message_data = {
            "session_id": session_id,
            "agent_id": agent_id,
            "content": content,
            "role": data.get("role", "user"),
            "timestamp": datetime.utcnow().isoformat(),
        }

        # Broadcast to session
        await _ws_manager.send_personal(message_data, session_id or "global")
        logger.info(
            f"Message sent via WebSocket: session={session_id}, agent={agent_id}"
        )

    except Exception as e:
        logger.error(f"Error handling send_message: {e}")
        await _ws_manager.send_error(session_id, "SEND_ERROR", str(e))


async def _handle_start_loop(data: dict, session_id: Optional[str]):
    """Handle starting the orchestration loop."""
    if not session_id:
        await _ws_manager.send_error(
            None, "NO_SESSION", "Session ID is required to start loop"
        )
        return

    try:
        _active_sessions.add(session_id)
        await _orchestration_engine.start_session(session_id)
        await _ws_manager.send_personal(
            {
                "type": "session_started",
                "session_id": session_id,
                "agents": [],
                "max_iterations": 50,
                "timestamp": datetime.utcnow().isoformat(),
            },
            session_id,
        )
        logger.info(f"Orchestration loop started for session {session_id}")
    except Exception as e:
        await _ws_manager.send_error(session_id, "START_ERROR", str(e))


async def _handle_stop_loop(data: dict, session_id: Optional[str]):
    """Handle stopping the orchestration loop."""
    if not session_id:
        return

    try:
        _active_sessions.discard(session_id)
        await _orchestration_engine.stop_session(session_id)
        await _ws_manager.send_personal(
            {
                "type": "session_stopped",
                "session_id": session_id,
                "timestamp": datetime.utcnow().isoformat(),
            },
            session_id,
        )
        logger.info(f"Orchestration loop stopped for session {session_id}")
    except Exception as e:
        await _ws_manager.send_error(session_id, "STOP_ERROR", str(e))


async def _handle_heartbeat(
    data: dict, session_id: Optional[str], agent_id: Optional[str]
):
    """Handle heartbeat from client."""
    await _ws_manager.send_personal(
        {
            "type": "heartbeat_ack",
            "session_id": session_id,
            "timestamp": datetime.utcnow().isoformat(),
        },
        session_id or "global",
    )

    # Update leader heartbeat if agent_id provided
    if agent_id and session_id:
        try:
            from app.services.leader_election import LeaderElectionManager

            leader_election = LeaderElectionManager()
            await leader_election.heartbeat(session_id, agent_id)
        except Exception:
            pass


async def _handle_update_agent(
    data: dict, session_id: Optional[str], agent_id: Optional[str]
):
    """Handle agent configuration updates."""
    if not session_id or not agent_id:
        return

    config = data.get("config", {})
    try:
        await _ws_manager.send_personal(
            {
                "type": "agent_updated",
                "session_id": session_id,
                "agent_id": agent_id,
                "config": config,
                "timestamp": datetime.utcnow().isoformat(),
            },
            session_id,
        )
    except Exception as e:
        logger.error(f"Error updating agent {agent_id}: {e}")


async def _handle_get_status(session_id: Optional[str]):
    """Handle status requests."""
    if not session_id:
        return

    try:
        await _ws_manager.send_personal(
            {
                "type": "status",
                "session_id": session_id,
                "is_running": session_id in _active_sessions,
                "timestamp": datetime.utcnow().isoformat(),
            },
            session_id,
        )
    except Exception as e:
        logger.error(f"Error sending status for session {session_id}: {e}")


# Initialize router
@router.websocket("/ws")
async def websocket_endpoint_handler(
    websocket: WebSocket,
    session_id: Optional[str] = Query(None),
    agent_id: Optional[str] = Query(None),
):
    """WebSocket endpoint handler."""
    await websocket_endpoint(websocket, session_id, agent_id)


@router.get("/ws/health")
async def websocket_health():
    """Check WebSocket server health."""
    return {
        "status": "connected",
        "active_sessions": len(_active_sessions),
        "connected_clients": _ws_manager.connections,
        "timestamp": datetime.utcnow().isoformat(),
    }
