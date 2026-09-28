"""Pydantic settings configuration for the Multi-AI Agent Orchestrator."""

from pydantic_settings import BaseSettings
from pydantic import Field
from typing import List


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Project
    project_name: str = "Multi-AI Agent Orchestrator"
    project_version: str = "1.0.0"
    debug: bool = False

    # Server
    host: str = Field(default="0.0.0.0", env="HOST")
    port: int = Field(default=8000, env="PORT")
    reload: bool = Field(default=True, env="RELOAD")

    # Database
    database_url: str = Field(
        default="sqlite+aiosqlite:///./sessions.db", env="DATABASE_URL"
    )

    # Security
    secret_key: str = Field(
        default="your-secret-key-change-in-production", env="SECRET_KEY"
    )
    algorithm: str = Field(default="HS256", env="ALGORITHM")
    access_token_expire_minutes: int = Field(
        default=30, env="ACCESS_TOKEN_EXPIRE_MINUTES"
    )
    api_key: str = Field(default="default-api-key", env="API_KEY")

    # CORS
    allowed_origins: List[str] = Field(
        default=["http://localhost:3000", "http://localhost:8080"],
        env="ALLOWED_ORIGINS",
    )

    # Playwright / Chrome
    chromium_path: str = Field(default="/usr/bin/chromium", env="CHROMIUM_PATH")
    headless: bool = Field(default=True, env="HEADLESS")

    # Orchestration
    max_agents: int = Field(default=5, env="MAX_AGENTS")
    max_iterations: int = Field(default=10, env="MAX_ITERATIONS")
    leader_election_interval: int = Field(default=5, env="LEADER_ELECTION_INTERVAL")
    termination_timeout: int = Field(default=300, env="TERMINATION_TIMEOUT")

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
