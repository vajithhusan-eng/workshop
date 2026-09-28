"""Database module for the Multi-AI Agent Orchestrator backend.

This module provides SQLAlchemy engine, session factory, and base model
for all database operations. Uses SQLite by default for local-first storage.
"""

from typing import Generator, Any
from sqlalchemy import create_engine, MetaData
from sqlalchemy.orm import sessionmaker, declarative_base, Session
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

from app.config import settings

logger = __import__("logging").getLogger(__name__)

# Determine if we're using SQLite or async database
is_sqlite = settings.DATABASE_URL.startswith("sqlite")

# Create engine
if is_sqlite:
    engine = create_engine(
        settings.DATABASE_URL,
        echo=False,
        connect_args={"check_same_thread": False},
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=10,
    )
else:
    engine = create_engine(
        settings.DATABASE_URL,
        echo=False,
        pool_pre_ping=True,
        pool_size=20,
        max_overflow=40,
    )

# Session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Async session factory (for future async support)
async_engine = create_async_engine(
    settings.DATABASE_URL.replace("sqlite:///", "sqlite+aiosqlite:///")
    if is_sqlite
    else settings.DATABASE_URL,
    echo=False,
    pool_pre_ping=True,
)
async_session = async_sessionmaker(
    async_engine, class_=AsyncSession, expire_on_commit=False
)

# Base model for all SQLAlchemy ORM classes
Base = declarative_base(metadata=MetaData())

# Named metadata for convenience
metadata = Base.metadata


def init_db() -> None:
    """Initialize the database by creating all tables defined in Base.metadata.

    This function should be called once at application startup. It creates
    all tables that don't exist yet; if tables already exist, it does nothing.
    """
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("All database tables created/verified successfully")
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")
        raise


def get_db() -> Generator[Session, None, None]:
    """Dependency generator that provides a database session.

    Yields:
        Session: A SQLAlchemy database session.

    Note:
        The session is automatically closed after use. This function
        is designed to be used as a FastAPI Depends dependency.

    Example:
        ```python
        @app.get("/sessions")
        async def get_sessions(db: Session = Depends(get_db)):
            sessions = db.query(Session).all()
            return sessions
        ```
    """
    db = SessionLocal()
    try:
        yield db
    except Exception as e:
        logger.error(f"Database session error: {e}")
        db.rollback()
        raise
    finally:
        db.close()


async def get_async_db() -> AsyncGenerator[AsyncSession, None]:
    """Async dependency generator for async database sessions."""
    async with async_session() as session:
        try:
            yield session
        except Exception as e:
            logger.error(f"Async database session error: {e}")
            await session.rollback()
            raise
        finally:
            await session.close()


def close_db() -> None:
    """Dispose of all database engine connections."""
    try:
        engine.dispose()
        logger.info("Database connections closed")
    except Exception as e:
        logger.error(f"Error closing database connections: {e}")


# Module-level database health check
def check_db_connection() -> bool:
    """Check if the database connection is healthy.

    Returns:
        bool: True if the database connection is healthy, False otherwise.
    """
    try:
        with SessionLocal() as db:
            db.execute("SELECT 1")
        return True
    except Exception:
        return False
