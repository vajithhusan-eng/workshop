"""WebSocket Pydantic schemas for the Multi-AI Agent Orchestrator.

Defines request and response models for WebSocket communication
between the Flutter frontend and the backend.
"""

from datetime import datetime
from typing import Optional, Dict, Any

from pydantic import BaseModel, Field, field_validator, ConfigDict


class WSMessage(BaseModel):
    """Schema for incoming WebSocket messages from clients.

    Attributes:
        type: The type of WebSocket message event.
        session_id: The associated session ID, if applicable.
        agent_id: The associated agent ID, if applicable.
        content: The message content, if applicable.
        data: Additional data payload.
        timestamp: When the message was sent (auto-filled if None).
    """

    model_config = ConfigDict(extra="forbid")

    type: str = Field(..., description="Message type")
    session_id: Optional[str] = Field(None, description="Associated session ID")
    agent_id: Optional[str] = Field(None, description="Associated agent ID")
    content: Optional[str] = Field(None, description="Message content")
    data: Optional[Dict[str, Any]] = Field(None, description="Additional data")
    timestamp: Optional[datetime] = Field(None, description="Message timestamp")

    @field_validator("timestamp")
    @classmethod
    def fill_timestamp(cls, v: Optional[datetime]) -> datetime:
        """Auto-fill timestamp if not provided."""
        return v or datetime.utcnow()

    @field_validator("type")
    @classmethod
    def validate_type(cls, v: str) -> str:
        """Validate message type is not empty."""
        if not v or not v.strip():
            raise ValueError("Message type cannot be empty")
        return v


class WSTyping(BaseModel):
    """Schema for WebSocket typing indicator events.

    Attributes:
        event_type: The type of typing event.
        payload: The event payload data.
    """

    model_config = ConfigDict(from_attributes=True)

    event_type: str = Field(..., description="Typing event type")
    payload: Dict[str, Any] = Field(default_factory=dict, description="Event payload")


class WSMessageResponse(BaseModel):
    """Schema for outgoing WebSocket messages from the server.

    Attributes:
        type: The type of WebSocket message event.
        session_id: The associated session ID.
        agent_id: The associated agent ID.
        content: The message content.
        data: Additional data payload.
        timestamp: When the message was sent.
        success: Whether the message was processed successfully.
    """

    model_config = ConfigDict(from_attributes=True)

    type: str
    session_id: Optional[str] = None
    agent_id: Optional[str] = None
    content: Optional[str] = None
    data: Optional[Dict[str, Any]] = None
    timestamp: datetime
    success: bool = True


class WSErrorResponse(BaseModel):
    """Schema for WebSocket error messages.

    Attributes:
        type: Always "error".
        code: Error code identifier.
        message: Human-readable error message.
        session_id: The associated session ID, if applicable.
        timestamp: When the error occurred.
    """

    model_config = ConfigDict(from_attributes=True)

    type: str = "error"
    code: str = Field(..., description="Error code")
    message: str = Field(..., description="Error message")
    session_id: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class WSConnectionState(BaseModel):
    """Schema for WebSocket connection state.

    Attributes:
        connected: Whether the client is connected.
        session_id: The active session ID, if any.
        agent_id: The active agent ID, if any.
    """

    model_config = ConfigDict(from_attributes=True)

    connected: bool = Field(default=False, description="Connection status")
    session_id: Optional[str] = Field(None, description="Active session ID")
    agent_id: Optional[str] = Field(None, description="Active agent ID")


class WSSessionStarted(BaseModel):
    """Schema for session started events."""

    model_config = ConfigDict(from_attributes=True)

    type: str = "session_started"
    session_id: str
    agents: list
    max_iterations: int
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class WSSessionCompleted(BaseModel):
    """Schema for session completed events."""

    model_config = ConfigDict(from_attributes=True)

    type: str = "session_completed"
    session_id: str
    reason: str
    summary: str
    total_iterations: int
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class WSIterationUpdate(BaseModel):
    """Schema for iteration update events."""

    model_config = ConfigDict(from_attributes=True)

    type: str = "iteration_update"
    session_id: str
    iteration: int
    current_agent: str
    total_iterations: int
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class WSNewMessage(BaseModel):
    """Schema for new message events from agents."""

    model_config = ConfigDict(from_attributes=True)

    type: str = "new_message"
    session_id: str
    message: Dict[str, Any]
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class WSAgentStatus(BaseModel):
    """Schema for agent status change events."""

    model_config = ConfigDict(from_attributes=True)

    type: str = "agent_status"
    session_id: str
    agent_id: str
    status: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
