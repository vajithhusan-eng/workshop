"""AgentConfig model for the Multi-AI Agent Orchestrator.

Defines the SQLAlchemy ORM model for storing agent-specific configuration
parameters like model selection, temperature, max tokens, and custom prompts.
"""

import uuid
from datetime import datetime
from typing import Optional, Dict, Any

from sqlalchemy import (
    Column,
    String,
    Text,
    Float,
    Integer,
    DateTime,
    ForeignKey,
    Index,
    JSON,
)
from sqlalchemy.orm import relationship

from app.database import Base

logger = __import__("logging").getLogger(__name__)


class AgentConfig(Base):
    """SQLAlchemy ORM model for agent configurations.

    Stores per-agent configuration including model selection, temperature,
    max tokens, and custom prompts. Each agent can have multiple configuration
    entries for different provider-specific settings.

    Attributes:
        id: Unique identifier (UUID string) for the config entry.
        agent_id: Foreign key linking to the parent agent.
        model: The AI model to use (e.g., gpt-4o, gemini-pro).
        temperature: Sampling temperature for the AI model.
        max_tokens: Maximum number of tokens in the response.
        custom_prompt: Custom system prompt for the agent.
    """

    __tablename__ = "agent_configs"

    # Columns
    id = Column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4()), index=True
    )
    agent_id = Column(
        String(36),
        ForeignKey("agents.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    model = Column(String(100), default="")
    temperature = Column(Float, default=0.7)
    max_tokens = Column(Integer, default=4096)
    custom_prompt = Column(Text, default="")
    config_key = Column(String(100), default="default")
    updated_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    agent = relationship("Agent", back_populates="configs")

    # Indexes
    __table_args__ = (
        Index("idx_agent_configs_agent", "agent_id"),
        Index("idx_agent_configs_key", "agent_id", "config_key"),
    )

    def __repr__(self) -> str:
        return (
            f"<AgentConfig(id={self.id}, agent_id={self.agent_id}, model={self.model})>"
        )

    def to_dict(self) -> Dict[str, Any]:
        """Convert the AgentConfig model to a dictionary representation.

        Returns:
            Dict[str, Any]: Dictionary containing all config fields.
        """
        return {
            "id": self.id,
            "agent_id": self.agent_id,
            "model": self.model,
            "temperature": self.temperature,
            "max_tokens": self.max_tokens,
            "custom_prompt": self.custom_prompt,
            "config_key": self.config_key,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }

    @classmethod
    def create(
        cls,
        agent_id: str,
        model: str = "",
        temperature: float = 0.7,
        max_tokens: int = 4096,
        custom_prompt: str = "",
        **kwargs,
    ) -> "AgentConfig":
        """Factory method to create a new AgentConfig instance.

        Args:
            agent_id: The agent ID this config belongs to.
            model: The AI model identifier.
            temperature: Sampling temperature (0.0 to 1.0).
            max_tokens: Maximum tokens in the response.
            custom_prompt: Custom system prompt.
            **kwargs: Additional keyword arguments.

        Returns:
            AgentConfig: A new AgentConfig instance.
        """
        return cls(
            agent_id=agent_id,
            model=model,
            temperature=temperature,
            max_tokens=max_tokens,
            custom_prompt=custom_prompt,
            **kwargs,
        )


class AgentConfigTable:
    """Alias for AgentConfig for backward compatibility."""

    pass
