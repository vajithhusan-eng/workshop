"""Agent model for the Multi-AI Agent Orchestrator.

Defines the SQLAlchemy ORM model for agents, representing individual
AI agents (ChatGPT, Gemini, DeepSeek) registered within sessions.
"""

import uuid
from datetime import datetime
from typing import Optional, List, Dict, Any

from sqlalchemy import (
    Column,
    String,
    Text,
    DateTime,
    Integer,
    Boolean,
    JSON,
    Float,
    Index,
    ForeignKey,
)
from sqlalchemy.orm import relationship

from app.database import Base

logger = __import__("logging").getLogger(__name__)


VALID_AGENT_TYPES = {"chatgpt", "gemini", "deepseek"}
VALID_AGENT_ROLES = {"leader", "follower"}
VALID_AGENT_STATUSES = {"idle", "active", "error", "disconnected"}


class Agent(Base):
    """SQLAlchemy ORM model for agents.

    An agent represents an AI service (ChatGPT, Gemini, DeepSeek) that is
    registered within a session. Each agent has a role (leader or follower),
    a web URL for browser automation, and configuration parameters.

    Attributes:
        id: Unique identifier (UUID string) for the agent.
        session_id: Foreign key linking to the parent session.
        name: Human-readable name for the agent.
        type: The agent type (chatgpt, gemini, deepseek).
        provider: The AI provider (same as type for simplicity).
        web_url: The URL of the AI's web interface.
        status: Current connection status of the agent.
        config: JSON configuration for the agent (model, temperature, etc.).
        created_at: Timestamp when the agent was registered.
        last_heartbeat: Timestamp of the last heartbeat from the agent.
        message_count: Number of messages sent by this agent.
    """

    __tablename__ = "agents"

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
    name = Column(String(100), nullable=False)
    type = Column(String(20), nullable=False, index=True)
    web_url = Column(String(500), nullable=False)
    provider = Column(String(20), nullable=False, index=True)
    status = Column(String(20), nullable=False, default="idle", index=True)
    config = Column(JSON, default=dict)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    last_heartbeat = Column(DateTime, nullable=True)
    message_count = Column(Integer, default=0)
    role = Column(String(20), nullable=False, default="follower", index=True)
    is_connected = Column(Boolean, default=False)
    added_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    session = relationship("Session", back_populates="agents")
    configs = relationship(
        "AgentConfig",
        back_populates="agent",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    messages = relationship(
        "Message", back_populates="agent", cascade="all, delete-orphan", lazy="selectin"
    )

    # Indexes
    __table_args__ = (
        Index("idx_agents_session", "session_id"),
        Index("idx_agents_role", "session_id", "role"),
        Index("idx_agents_type", "type"),
        Index("idx_agents_provider", "provider"),
        Index("idx_agents_status", "status"),
    )

    def __repr__(self) -> str:
        return f"<Agent(id={self.id}, name={self.name}, type={self.type}, role={self.role})>"

    def to_dict(self) -> Dict[str, Any]:
        """Convert the Agent model to a dictionary representation.

        Returns:
            Dict[str, Any]: Dictionary containing all agent fields.
        """
        return {
            "id": self.id,
            "session_id": self.session_id,
            "name": self.name,
            "type": self.type,
            "web_url": self.web_url,
            "provider": self.provider,
            "status": self.status,
            "role": self.role,
            "is_connected": self.is_connected,
            "config": self.config,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "last_heartbeat": self.last_heartbeat.isoformat()
            if self.last_heartbeat
            else None,
            "message_count": self.message_count,
        }

    def is_leader(self) -> bool:
        """Check if the agent is designated as a leader.

        Returns:
            bool: True if the agent's role is 'leader', False otherwise.
        """
        return self.role == "leader"

    def set_heartbeat(self) -> None:
        """Update the agent's last heartbeat timestamp to the current time."""
        self.last_heartbeat = datetime.utcnow()

    def increment_message_count(self) -> None:
        """Increment the agent's message count by one."""
        self.message_count += 1

    def disconnect(self) -> None:
        """Mark the agent as disconnected."""
        self.is_connected = False
        self.status = "disconnected"

    def connect(self) -> None:
        """Mark the agent as connected."""
        self.is_connected = True
        self.status = "active"

    @classmethod
    def create(
        cls,
        session_id: str,
        name: str,
        agent_type: str,
        web_url: str,
        provider: str,
        **kwargs,
    ) -> "Agent":
        """Factory method to create a new Agent instance.

        Args:
            session_id: The ID of the session this agent belongs to.
            name: Human-readable name for the agent.
            agent_type: The type of agent (chatgpt, gemini, deepseek).
            web_url: The URL of the AI's web interface.
            provider: The AI provider name.
            **kwargs: Additional keyword arguments.

        Returns:
            Agent: A new Agent instance.
        """
        return cls(
            session_id=session_id,
            name=name,
            type=agent_type,
            provider=provider,
            web_url=web_url,
            **kwargs,
        )

    @property
    def provider_display_name(self) -> str:
        """Get the human-readable display name for the provider."""
        display_names = {
            "chatgpt": "ChatGPT",
            "gemini": "Google Gemini",
            "deepseek": "DeepSeek",
        }
        return display_names.get(self.provider, self.provider.title())


class AgentTable:
    """Alias for Agent for backward compatibility."""

    pass
