"""Agent schemas for the Multi-AI Agent Orchestrator."""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


# Request schemas
class AgentCreate(BaseModel):
    """Schema for creating a new agent."""

    name: str = Field(..., min_length=1, max_length=100)
    role: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(default=None, max_length=1000)
    agent_type: str = Field(default="ai", max_length=50)
    config_id: Optional[str] = Field(default=None)
    is_leader: bool = Field(default=False)


class AgentUpdate(BaseModel):
    """Schema for updating an agent."""

    name: Optional[str] = Field(None, min_length=1, max_length=100)
    role: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = Field(None, max_length=1000)
    is_active: Optional[bool] = Field(None)
    is_leader: Optional[bool] = Field(None)


class AgentConfigCreate(BaseModel):
    """Schema for creating an agent config."""

    name: str = Field(..., min_length=1, max_length=100)
    system_prompt: str = Field(..., min_length=1)
    model_name: str = Field(default="gpt-4", max_length=100)
    temperature: float = Field(default=0.7, ge=0.0, le=2.0)
    max_tokens: int = Field(default=2048, ge=1)
    capabilities: Optional[List[str]] = Field(default=None)


# Response schemas
class AgentConfigResponse(BaseModel):
    """Schema for agent config response."""

    id: str
    name: str
    model_name: str
    temperature: float
    max_tokens: int
    is_default: bool
    capabilities: Optional[List[str]] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class AgentResponse(BaseModel):
    """Schema for agent response."""

    id: str
    name: str
    role: str
    description: Optional[str] = None
    agent_type: str
    is_leader: bool
    is_active: bool
    config_id: Optional[str] = None
    session_id: str
    created_at: datetime

    class Config:
        from_attributes = True


class AgentWithConfigResponse(AgentResponse):
    """Agent response with full configuration."""

    config: Optional[AgentConfigResponse] = None
