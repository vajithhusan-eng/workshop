"""Message schemas for the Multi-AI Agent Orchestrator."""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


# Request schemas
class MessageCreate(BaseModel):
    """Schema for creating a new message."""

    content: str = Field(..., min_length=1)
    sender_type: str = Field(..., max_length=50)
    sender_agent_id: Optional[str] = Field(default=None)
    session_id: str
    parent_message_id: Optional[str] = Field(default=None)
    metadata_: Optional[dict] = Field(default=None, alias="metadata")


# Response schemas
class MessageResponse(BaseModel):
    """Schema for message response."""

    id: str
    message_id: str
    content: str
    sender_type: str
    sender_agent_id: Optional[str] = None
    session_id: str
    parent_message_id: Optional[str] = None
    metadata: Optional[dict] = None
    created_at: datetime

    class Config:
        from_attributes = True
        populate_by_name = True


class MessageList(BaseModel):
    """Schema for listing messages."""

    messages: List[MessageResponse]
    total: int
    session_id: str
