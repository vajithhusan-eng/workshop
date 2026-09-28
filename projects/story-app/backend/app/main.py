"""FastAPI application for the Multi-AI Agent Orchestrator.

This module creates the main FastAPI application instance with:
- CORS middleware for cross-origin requests
- Lifespan events for startup and shutdown
- All API routers registered
- Health check endpoint
- Global exception handlers
"""

import logging
import time
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Dict, Any

from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.config import settings
from app.database import init_db, engine, SessionLocal
from app.routers import api_router
from app.services.websocket_manager import WebSocketManager
from app.services.orchestration_engine import OrchestrationEngine

logger = logging.getLogger(__name__)

# Global instances
ws_manager = WebSocketManager()
orchestration_engine = OrchestrationEngine()


async def on_startup():
    """Application startup events: initialize database, services, and connections."""
    logger.info("Starting Multi-AI Agent Orchestrator backend...")
    logger.info(f"Database URL: {settings.DATABASE_URL}")
    logger.info(f"Chrome Profile Path: {settings.CHROME_PROFILE_PATH}")
    logger.info(f"WebSocket URL: {settings.WEBSOCKET_URL}")
    logger.info(f"Port: {settings.PORT}")

    # Initialize database
    try:
        init_db()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")
        raise

    # Initialize Chrome controller
    try:
        from app.services.chrome_controller import ChromeController

        chrome_controller = ChromeController()
        await chrome_controller.initialize()
        logger.info("Chrome controller initialized successfully")
    except ImportError:
        logger.warning(
            "Playwright not installed, Chrome controller will be unavailable"
        )
    except Exception as e:
        logger.warning(f"Chrome controller initialization failed: {e}")

    # Start orchestration engine
    orchestration_engine.start()
    logger.info("Orchestration engine started")

    logger.info("Application startup complete")


async def on_shutdown():
    """Application shutdown events: cleanup resources."""
    logger.info("Shutting down Multi-AI Agent Orchestrator backend...")

    # Stop orchestration engine
    orchestration_engine.stop()
    logger.info("Orchestration engine stopped")

    # Close Chrome browser
    try:
        from app.services.chrome_controller import ChromeController

        chrome_controller = ChromeController()
        await chrome_controller.cleanup()
    except Exception:
        pass

    # Close database connections
    try:
        SessionLocal.remove_all()
    except Exception:
        pass

    logger.info("Application shutdown complete")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown events."""
    await on_startup()
    yield
    await on_shutdown()


# Create FastAPI application
app = FastAPI(
    title="Multi-AI Agent Orchestrator",
    description="""
    A production-ready backend for orchestrating multiple AI agents (ChatGPT, Gemini, DeepSeek)
    through Chrome browser automation. Features session management, agent orchestration,
    real-time WebSocket communication, and Playwright integration.
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include all API routers
app.include_router(api_router)


# Health check endpoint
@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint for monitoring and self-checks."""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0",
        "database": "connected" if engine else "disconnected",
        "chrome": "ready",
    }


# Global exception handlers
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """Handle request validation errors."""
    logger.warning(f"Validation error at {request.url}: {exc.errors()}")
    return JSONResponse(
        status_code=422,
        content={
            "detail": "Validation error",
            "errors": exc.errors(),
            "timestamp": datetime.utcnow().isoformat(),
        },
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    """Handle all uncaught exceptions."""
    logger.error(f"Unhandled exception at {request.url}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "message": str(exc),
            "timestamp": datetime.utcnow().isoformat(),
        },
    )


# Logging configuration
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger.setLevel(logging.INFO)

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=settings.PORT, reload=True)
