"""Message model for the Multi-AI Agent Orchestrator.

Defines the SQLAlchemy ORM model for messages exchanged between agents
and users within sessions.
"""

import uuid
from datetime import datetime
from typing import Optional, Dict, Any

from sqlalchemy import (
    Column,
    String,
    Text,
    DateTime,
    Boolean,
    Integer,
    ForeignKey,
    Index,
    JSON,
)
from sqlalchemy.orm import relationship

from app.database import Base

logger = __import__("logging").getLogger(__name__)


VALID_ROLES = {"user", "assistant", "system"}


class Message(Base):
    """SQLAlchemy ORM model for messages.

    A message represents a single communication within a session. Messages
    can be from users, assistants (AI agents), or system notifications.
    Messages can originate from the browser (captured by Playwright) or
    be sent programmatically.

    Attributes:
        id: Unique identifier (UUID string) for the message.
        session_id: Foreign key linking to the parent session.
        agent_id: Foreign key linking to the agent that sent this message.
        role: The role of the message (user, assistant, system).
        content: The actual message content.
        timestamp: When the message was created.
        is_from_browser: Whether this message was captured from Chrome.
        iteration: Which iteration of the orchestration loop this was sent in.
    """

    __tablename__ = "messages"

    # Columns
    id = Column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True
    )
    session_id = Column(
        String(36),
        ForeignKey("sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    agent_id = Column(
        String(36),
        ForeignKey("agents.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    role = Column(String(20), nullable=False, index=True)
    content = Column(Text, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    is_from_browser = Column(Boolean, default=False, index=True)
    iteration = Column(Integer, default=0, nullable=False)
    content_type = Column(String(20), default="text")
    metadata = Column(JSON, default=dict)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    # Relationships
    session = relationship("Session", back_populates="messages")
    agent = relationship("Agent", back_populates="messages")

    # Indexes
    __table_args__ = (
        Index("idx_messages_session", "session_id", "created_at"),
        Index("idx_messages_agent", "agent_id", "created_at"),
        Index("idx_messages_iteration", "session_id", "iteration"),
        Index("idx_messages_browser", "is_from_browser"),
    )

    def __repr__(self) -> str:
        return f"<Message(id={self.id}, role={self.role}, agent_id={self.agent_id})>"

    def to_dict(self) -> Dict[str, Any]:
        """Convert the Message model to a dictionary representation.

        Returns:
            Dict[str, Any]: Dictionary containing all message fields.
        """
        return {
            "id": self.id,
            "session_id": self.session_id,
            "agent_id": self.agent_id,
            "role": self.role,
            "content": self.content,
            "content_type": self.content_type,
            "timestamp": self.timestamp.isoformat() if self.timestamp else None,
            "is_from_browser": self.is_from_browser,
            "iteration": self.iteration,
            "metadata": self.metadata,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    @classmethod
    def create(
        cls,
        session_id: str,
        agent_id: str,
        role: str,
        content: str,
        iteration: int = 0,
        **kwargs,
    ) -> "Message":
        """Factory method to create a new Message instance.

        Args:
            session_id: The session ID this message belongs to.
            agent_id: The agent ID that sent this message.
            role: The role of the message (user, assistant, system).
            content: The message content.
            iteration: The iteration number of the orchestration loop.
            **kwargs: Additional keyword arguments.

        Returns:
            Message: A new Message instance.
        """
        return cls(
            session_id=session_id,
            agent_id=agent_id,
            role=role,
            content=content,
            iteration=iteration,
            **kwargs,
        )


class MessageTable:
    """Alias for Message for backward compatibility."""

    pass
