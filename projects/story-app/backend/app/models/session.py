"""Session model for the Multi-AI Agent Orchestrator.

Defines the SQLAlchemy ORM model for sessions, representing isolated
projects with their own agents and conversation history.
"""

import uuid
from datetime import datetime
from typing import Optional, List, Dict, Any

from sqlalchemy import Column, String, Text, DateTime, Integer, JSON, Index
from sqlalchemy.orm import relationship, declarative_base

from app.database import Base

logger = __import__("logging").getLogger(__name__)


class Session(Base):
    """SQLAlchemy ORM model for sessions.

    A session represents an isolated project where multiple AI agents
    can collaborate. Each session has its own set of agents and message
    history.

    Attributes:
        id: Unique identifier (UUID string) for the session.
        name: User-visible name for the session.
        description: Detailed description of the session's purpose.
        status: Current status of the session (active, completed, archived, deleted).
        agent_ids: List of agent IDs associated with this session.
        created_at: Timestamp when the session was created.
        updated_at: Timestamp when the session was last updated.
        leader_id: ID of the designated leader agent.
    """

    __tablename__ = "sessions"

    # Columns
    id = Column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True
    )
    name = Column(String(200), nullable=False)
    description = Column(Text, default="")
    status = Column(String(20), nullable=False, default="active", index=True)
    agent_ids = Column(JSON, default=list)
    description_text = Column(Text, default="")
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    updated_at = Column(
        DateTime, default=datetime.utcnow, nullable=False, onupdate=datetime.utcnow
    )
    leader_id = Column(String(36), nullable=True, index=True)
    max_iterations = Column(Integer, default=50)
    current_iteration = Column(Integer, default=0)
    termination_reason = Column(String(100), nullable=True)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    config = Column(JSON, default=dict)
    created_by = Column(String(100), nullable=False)

    # Relationships
    agents = relationship(
        "Agent", back_populates="session", cascade="all, delete-orphan", lazy="selectin"
    )
    messages = relationship(
        "Message",
        back_populates="session",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    # Indexes
    __table_args__ = (
        Index("idx_sessions_status", "status"),
        Index("idx_sessions_created_at", "created_at"),
        Index("idx_sessions_updated_at", "updated_at"),
        Index("idx_sessions_created_by", "created_by", "created_at"),
    )

    def __repr__(self) -> str:
        return f"<Session(id={self.id}, name={self.name}, status={self.status})>"

    def to_dict(self) -> Dict[str, Any]:
        """Convert the Session model to a dictionary representation.

        Returns:
            Dict[str, Any]: Dictionary containing all session fields.
        """
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "status": self.status,
            "agent_ids": self.agent_ids,
            "leader_id": self.leader_id,
            "max_iterations": self.max_iterations,
            "current_iteration": self.current_iteration,
            "termination_reason": self.termination_reason,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "started_at": self.started_at.isoformat() if self.started_at else None,
            "completed_at": self.completed_at.isoformat()
            if self.completed_at
            else None,
            "config": self.config,
            "created_by": self.created_by,
        }

    def is_active(self) -> bool:
        """Check if the session is currently active.

        Returns:
            bool: True if the session status is 'active', False otherwise.
        """
        return self.status == "active"

    def mark_complete(self, reason: str = "max_iterations") -> None:
        """Mark the session as completed.

        Args:
            reason: The reason for completion (e.g., 'max_iterations', 'user_stop', 'consensus').
        """
        self.status = "completed"
        self.completed_at = datetime.utcnow()
        self.termination_reason = reason
        logger.info(f"Session {self.id} marked as completed: {reason}")

    def mark_active(self) -> None:
        """Mark the session as active and set start time."""
        self.status = "active"
        self.started_at = datetime.utcnow()

    @classmethod
    def create(
        cls, name: str, description: str = "", created_by: str = "user", **kwargs
    ) -> "Session":
        """Factory method to create a new Session instance.

        Args:
            name: The name of the session.
            description: Optional description.
            created_by: The user ID who created the session.
            **kwargs: Additional keyword arguments for other fields.

        Returns:
            Session: A new Session instance.
        """
        return cls(
            name=name,
            description=description,
            created_by=created_by,
            **kwargs,
        )


class SessionTable:
    """Alias for Session for backward compatibility."""

    pass
