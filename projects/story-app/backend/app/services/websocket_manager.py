"""WebSocket manager for the Multi-AI Agent Orchestrator.

Manages WebSocket connections, broadcasting messages, and
tracking connected clients across sessions.
"""

import logging
from typing import Set, Dict, Optional
from datetime import datetime

from fastapi import WebSocket, WebSocketDisconnect

logger = logging.getLogger(__name__)


class WebSocketManager:
    """Manages WebSocket connections and broadcasting.

    Tracks active WebSocket connections organized by session ID
    and provides methods for sending messages, broadcasting,
    and managing connection lifecycle.

    Attributes:
        connections: Dictionary mapping session IDs to sets of WebSocket connections.
        global_connections: Set of connections not tied to a specific session.
    """

    def __init__(self):
        """Initialize the WebSocket manager with empty connection pools."""
        self.connections: Dict[str, Set[WebSocket]] = {}
        self.global_connections: Set[WebSocket] = set()

    async def connect(
        self, websocket: WebSocket, session_id: str, agent_id: Optional[str] = None
    ) -> None:
        """Accept and register a WebSocket connection.

        Args:
            websocket: The WebSocket connection to accept.
            session_id: The session ID to associate with this connection.
            agent_id: Optional agent ID for the connection.
        """
        try:
            await websocket.accept()
        except Exception as e:
            logger.error(f"Error accepting WebSocket: {e}")
            return

        if session_id not in self.connections:
            self.connections[session_id] = set()
        self.connections[session_id].add(websocket)
        logger.info(
            f"WebSocket connected: session={session_id}, agent={agent_id}, total={self.get_connection_count(session_id)}"
        )

    async def disconnect(self, websocket: WebSocket, session_id: str) -> None:
        """Remove a WebSocket connection from the pool.

        Args:
            websocket: The WebSocket to disconnect.
            session_id: The session ID associated with the connection.
        """
        if session_id in self.connections:
            self.connections[session_id].discard(websocket)
            if not self.connections[session_id]:
                del self.connections[session_id]

        self.global_connections.discard(websocket)
        logger.info(
            f"WebSocket disconnected: session={session_id}, remaining={self.get_connection_count(session_id)}"
        )

    async def send_personal(self, message: dict, session_id: str) -> None:
        """Send a message to all WebSocket connections in a session.

        Args:
            message: The message dictionary to send.
            session_id: The session ID to send to.
        """
        if session_id not in self.connections:
            logger.debug(f"No connections for session {session_id}")
            return

        disconnected = set()
        for websocket in self.connections[session_id]:
            try:
                await websocket.send_json(message)
            except WebSocketDisconnect:
                disconnected.add(websocket)
            except Exception as e:
                logger.error(f"Error sending to WebSocket: {e}")
                disconnected.add(websocket)

        # Clean up disconnected clients
        for ws in disconnected:
            self.connections[session_id].discard(ws)
        if self.connections[session_id]:
            logger.debug(
                f"Sent message to {len(self.connections[session_id])} clients in session {session_id}"
            )

    async def broadcast(self, message: dict) -> None:
        """Send a message to all connected WebSocket clients.

        Args:
            message: The message dictionary to broadcast.
        """
        for session_id, websockets in self.connections.items():
            await self.send_personal(message, session_id)

    async def send_to_agent(self, message: dict, agent_id: str) -> None:
        """Send a message to all connections associated with a specific agent.

        Args:
            message: The message dictionary to send.
            agent_id: The agent ID to target.
        """
        for session_id, websockets in self.connections.items():
            for websocket in websockets:
                try:
                    await websocket.send_json(message)
                except Exception:
                    pass

    async def send_error(
        self, session_id: Optional[str], code: str, message: str
    ) -> None:
        """Send an error message to clients.

        Args:
            session_id: The session ID, if any.
            code: Error code identifier.
            message: Human-readable error message.
        """
        error_data = {
            "type": "error",
            "code": code,
            "message": message,
            "session_id": session_id,
            "timestamp": datetime.utcnow().isoformat(),
        }
        target = session_id or "global"
        await self.send_personal(error_data, target)

    async def send_iteration_update(
        self, session_id: str, iteration: int, agent_id: str
    ) -> None:
        """Send an iteration update to session clients.

        Args:
            session_id: The session ID.
            iteration: The current iteration number.
            agent_id: The current agent's ID.
        """
        data = {
            "type": "iteration_update",
            "session_id": session_id,
            "iteration": iteration,
            "current_agent": agent_id,
            "timestamp": datetime.utcnow().isoformat(),
        }
        await self.send_personal(data, session_id)

    async def send_session_started(
        self, session_id: str, agents: list, max_iterations: int = 50
    ) -> None:
        """Send session started notification.

        Args:
            session_id: The session ID.
            list of agents.
            max_iterations: Maximum iterations for the loop.
        """
        data = {
            "type": "session_started",
            "session_id": session_id,
            "agents": agents,
            "max_iterations": max_iterations,
            "timestamp": datetime.utcnow().isoformat(),
        }
        await self.send_personal(data, session_id)

    async def send_session_completed(
        self, session_id: str, reason: str, summary: str, total_iterations: int = 0
    ) -> None:
        """Send session completion notification.

        Args:
            session_id: The session ID.
            reason: The reason for completion.
            summary: Summary of the session.
            total_iterations: Total iterations completed.
        """
        data = {
            "type": "session_completed",
            "session_id": session_id,
            "reason": reason,
            "summary": summary,
            "total_iterations": total_iterations,
            "timestamp": datetime.utcnow().isoformat(),
        }
        await self.send_personal(data, session_id)

    async def send_agent_status(
        self, session_id: str, agent_id: str, status: str
    ) -> None:
        """Send agent status change notification.

        Args:
            session_id: The session ID.
            agent_id: The agent ID.
            status: The new status.
        """
        data = {
            "type": "agent_status",
            "session_id": session_id,
            "agent_id": agent_id,
            "status": status,
            "timestamp": datetime.utcnow().isoformat(),
        }
        await self.send_personal(data, session_id)

    async def send_new_message(self, session_id: str, message: dict) -> None:
        """Send a new message notification.

        Args:
            session_id: The session ID.
            message: The message data.
        """
        data = {
            "type": "new_message",
            "session_id": session_id,
            "message": message,
            "timestamp": datetime.utcnow().isoformat(),
        }
        await self.send_personal(data, session_id)

    def get_connection_count(self, session_id: str) -> int:
        """Get the number of connections for a session.

        Args:
            session_id: The session ID.

        Returns:
            Number of active WebSocket connections.
        """
        return len(self.connections.get(session_id, set()))

    def get_connected_sessions(self) -> list:
        """Get all active session IDs.

        Returns:
            List of session IDs with active connections.
        """
        return list(self.connections.keys())

    def get_total_connections(self) -> int:
        """Get the total number of active WebSocket connections.

        Returns:
            Total count of all active connections.
        """
        return sum(len(ws_set) for ws_set in self.connections.values())

    def is_connected(self, session_id: str) -> bool:
        """Check if there are active connections for a session.

        Args:
            session_id: The session ID.

        Returns:
            True if there are active connections, False otherwise.
        """
        return session_id in self.connections and len(self.connections[session_id]) > 0
