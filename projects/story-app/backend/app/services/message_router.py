"""Message router for the Multi-AI Agent Orchestrator.

Routes messages between agents based on round-robin or leader priority
and builds context for each agent's response.
"""

import logging
from typing import List, Optional, Dict, Any
from datetime import datetime

from app.database import SessionLocal
from app.models.message import Message, MessageTable
from app.models.agent import Agent, AgentTable
from app.models.session import Session, SessionTable
from app.services.websocket_manager import WebSocketManager

logger = logging.getLogger(__name__)


class MessageRouter:
    """Routes messages to correct agents based on round-robin or leader priority.

    Attributes:
        message_queues: Per-session message queues (in-memory).
        ws_manager: WebSocket manager for broadcasting messages.
    """

    def __init__(self):
        """Initialize the message router."""
        self.message_queues: Dict[str, List[Dict[str, Any]]] = {}
        self.ws_manager = WebSocketManager()
        logger.info("MessageRouter initialized")

    def get_next_speaker(self, session: Session, iteration: int) -> Optional[Agent]:
        """Determine which agent speaks next.

        Strategy:
        - Leader speaks on even iterations (0, 2, 4, ...)
        - Followers speak on odd iterations (1, 3, 5, ...)
        - Round-robin among followers
        - Leader always speaks first and last

        Args:
            session: The session object.
            iteration: The current iteration number.

        Returns:
            The next Agent to speak, or None if no agents available.
        """
        try:
            agents = session.agents
            if not agents:
                return None

            leaders = [a for a in agents if a.is_leader()]
            followers = [a for a in agents if not a.is_leader()]

            if not leaders:
                return agents[iteration % len(agents)]
            if not followers:
                return leaders[0]

            if iteration % 2 == 0:
                return leaders[0]
            else:
                follower_index = (iteration - 1) // 2 % len(followers)
                return followers[follower_index]

        except Exception as e:
            logger.error(f"Error getting next speaker: {e}")
            return None

    def build_context(self, session: Session, agent_id: str, iteration: int, db) -> str:
        """Build the context message for an agent.

        Includes all previous messages so agents can reference them.

        Args:
            session: The session object.
            agent_id: The agent ID to build context for.
            iteration: The current iteration number.
            db: Database session.

        Returns:
            Context string with all previous messages.
        """
        try:
            previous_messages = (
                db.query(Message)
                .filter(
                    Message.session_id == session.id,
                    Message.created_at.isbefore(datetime.utcnow()),
                )
                .order_by(Message.created_at.asc())
                .all()
            )

            context_parts = []
            for msg in previous_messages:
                agent_name = msg.agent.name if msg.agent else "Unknown"
                prefix = f"[{agent_name}]" if msg.role != "user" else ""
                context_parts.append(f"{prefix} {msg.role}: {msg.content[:500]}")

            # Add context about the current agent
            agent = db.query(Agent).filter(Agent.id == agent_id).first()
            agent_name = agent.name if agent else "Agent"
            context = (
                f"You are {agent_name}. Here is the conversation so far:\n\n"
                + "\n\n".join(context_parts)
            )

            return context

        except Exception as e:
            logger.error(f"Error building context: {e}")
            return "Please provide your response."

    def get_messages_for_context(
        self, session_id: str, iteration: int, db
    ) -> List[Message]:
        """Get previous messages for context building.

        Args:
            session_id: The session ID.
            iteration: The current iteration number.
            db: Database session.

        Returns:
            List of previous Message objects.
        """
        try:
            messages = (
                db.query(Message)
                .filter(
                    Message.session_id == session_id, Message.iteration <= iteration
                )
                .order_by(Message.created_at.asc())
                .all()
            )
            return messages
        except Exception as e:
            logger.error(f"Error getting messages for context: {e}")
            return []

    async def route_message(
        self, session_id: str, agent_id: str, content: str, db
    ) -> Message:
        """Route and save a message to an agent.

        Args:
            session_id: The session ID.
            agent_id: The agent ID to route the message to.
            content: The message content.
            db: Database session.

        Returns:
            The saved Message object.
        """
        try:
            message = Message(
                session_id=session_id,
                agent_id=agent_id,
                role="user",
                content=content,
                iteration=0,
            )
            db.add(message)
            db.commit()
            db.refresh(message)

            # Broadcast via WebSocket
            await self.ws_manager.send_new_message(session_id, message.to_dict())
            logger.info(f"Message routed to agent {agent_id} in session {session_id}")

            return message
        except Exception as e:
            logger.error(f"Error routing message: {e}")
            db.rollback()
            raise

    async def broadcast_to_session(self, session_id: str, message: dict) -> None:
        """Broadcast a message to all agents in a session.

        Args:
            session_id: The session ID.
            message: The message dictionary to broadcast.
        """
        await self.ws_manager.send_personal(message, session_id)
        logger.info(f"Broadcast to session {session_id}")

    def add_to_queue(self, session_id: str, message: dict) -> None:
        """Add a message to the session's message queue.

        Args:
            session_id: The session ID.
            message: The message to queue.
        """
        if session_id not in self.message_queues:
            self.message_queues[session_id] = []
        self.message_queues[session_id].append(message)
        logger.debug(f"Message added to queue for session {session_id}")

    def get_queue(self, session_id: str) -> List[Dict[str, Any]]:
        """Get the message queue for a session.

        Args:
            session_id: The session ID.

        Returns:
            List of queued messages.
        """
        return self.message_queues.get(session_id, [])

    def clear_queue(self, session_id: str) -> None:
        """Clear the message queue for a session.

        Args:
            session_id: The session ID.
        """
        if session_id in self.message_queues:
            self.message_queues[session_id] = []
            logger.info(f"Message queue cleared for session {session_id}")
