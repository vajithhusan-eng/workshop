"""Session schemas for the Multi-AI Agent Orchestrator."""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


# Request schemas
class SessionCreate(BaseModel):
    """Schema for creating a new session."""

    title: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = Field(default=None, max_length=1000)
    created_by: Optional[str] = Field(default=None, max_length=100)


class SessionUpdate(BaseModel):
    """Schema for updating a session."""

    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=1000)
    status: Optional[str] = Field(None)


# Response schemas
class SessionResponse(BaseModel):
    """Schema for session response."""

    id: str
    title: str
    description: Optional[str] = None
    status: str
    story_content: Optional[str] = None
    created_by: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    completed_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class SessionList(BaseModel):
    """Schema for listing sessions."""

    sessions: List[SessionResponse]
    total: int
    page: int
    size: int
