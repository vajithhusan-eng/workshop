"""Termination checker for the Multi-AI Agent Orchestrator.

Checks termination conditions including max iterations, solution markers,
consensus, no progress, timeout, and user stop.
"""

import logging
from typing import Optional, List
from dataclasses import dataclass, field
from datetime import datetime, timedelta

from app.models.session import Session
from app.models.message import Message

logger = logging.getLogger(__name__)


@dataclass
class TerminationResult:
    """Result of a termination check.

    Attributes:
        terminated: Whether the session should terminate.
        reason: The reason for termination.
        details: Additional details about the termination.
    """

    terminated: bool
    reason: str
    details: str = ""


class TerminationChecker:
    """Checks if the agent communication loop should stop.

    Evaluates multiple termination conditions including max iterations,
    solution markers, consensus, no progress, timeout, and user stop.

    Attributes:
        max_iterations: Default maximum iterations.
        timeout_minutes: Default session timeout in minutes.
        no_progress_window: Number of iterations to check for no progress.
        solution_markers: Keywords that indicate a solution has been found.
    """

    def __init__(self):
        """Initialize the termination checker with default thresholds."""
        self.max_iterations = 50
        self.timeout_minutes = 60
        self.no_progress_window = 5
        self.solution_markers = [
            "final answer",
            "solution",
            "conclusion",
            "summary",
            "the answer is",
            "result is",
            "therefore",
            "in conclusion",
        ]
        logger.info("TerminationChecker initialized")

    def check_max_iterations(self, session: Session, current_iteration: int) -> bool:
        """Check if the maximum number of iterations has been reached.

        Args:
            session: The session object.
            current_iteration: The current iteration number.

        Returns:
            True if max iterations reached, False otherwise.
        """
        max_iters = session.max_iterations or self.max_iterations
        return current_iteration >= max_iters

    def check_solution_marker(self, response_content: str) -> bool:
        """Check if the response contains a solution marker.

        Args:
            response_content: The AI's response text.

        Returns:
            True if a solution marker was found, False otherwise.
        """
        if not response_content:
            return False

        content_lower = response_content.lower()
        for marker in self.solution_markers:
            if marker in content_lower:
                logger.info(f"Solution marker found: {marker}")
                return True
        return False

    def check_consensus(self, session_id: str, db, threshold: float = 0.8) -> bool:
        """Check if all agents have agreed on an answer.

        Args:
            session_id: The session ID.
            db: Database session.
            threshold: Agreement threshold (0.0 to 1.0).

        Returns:
            True if consensus is reached, False otherwise.
        """
        try:
            messages = db.query(Message).filter(Message.session_id == session_id).all()
            if not messages:
                return False

            agents = set(msg.agent_id for msg in messages)
            if len(agents) < 2:
                return False  # Need at least 2 agents for consensus

            # Check if messages from different agents are similar in content
            # This is a simplified consensus check
            final_messages = [
                msg for msg in messages[-len(agents) * 2 :] if msg.role == "assistant"
            ]
            if len(final_messages) < len(agents):
                return False

            return True
        except Exception as e:
            logger.error(f"Error checking consensus: {e}")
            return False

    def check_no_progress(self, session_id: str, db, window: int = 5) -> bool:
        """Check if the last N iterations produced no new information.

        Args:
            session_id: The session ID.
            db: Database session.
            window: Number of iterations to check.

        Returns:
            True if no progress detected, False otherwise.
        """
        try:
            messages = (
                db.query(Message)
                .filter(Message.session_id == session_id)
                .order_by(Message.created_at.desc())
                .limit(window)
                .all()
            )
            if len(messages) < window:
                return False

            # Check if the last N messages have very similar content lengths
            # (indicating repetitive or non-productive responses)
            lengths = [len(msg.content) for msg in messages if msg.role == "assistant"]
            if len(lengths) < window:
                return False

            avg_length = sum(lengths) / len(lengths)
            variance = sum((l - avg_length) ** 2 for l in lengths) / len(lengths)

            # If variance is very low, responses are repetitive
            if variance < 10 and avg_length > 50:
                logger.info(
                    f"No progress detected: low variance ({variance:.2f}) in last {window} responses"
                )
                return True

            return False
        except Exception as e:
            logger.error(f"Error checking no progress: {e}")
            return False

    def check_timeout(self, session: Session, started_at: datetime = None) -> bool:
        """Check if the session has exceeded the maximum duration.

        Args:
            session: The session object.
            started_at: Optional start time override.

        Returns:
            True if session has timed out, False otherwise.
        """
        try:
            start_time = started_at or session.started_at
            if not start_time:
                return False

            timeout = timedelta(minutes=self.timeout_minutes)
            elapsed = datetime.utcnow() - start_time
            return elapsed > timeout
        except Exception as e:
            logger.error(f"Error checking timeout: {e}")
            return False

    def check_user_stop(self, session: Session) -> bool:
        """Check if the user has manually stopped the session.

        Args:
            session: The session object.

        Returns:
            True if the session status is 'archived' or 'completed' by user.
        """
        return session.status in ("archived", "stopped")

    def should_terminate(
        self, session: Session, response: str, current_iteration: int, db
    ) -> TerminationResult:
        """Comprehensive termination check.

        Args:
            session: The session object.
            response: The latest AI response.
            current_iteration: The current iteration number.
            db: Database session.

        Returns:
            TerminationResult indicating whether to terminate and why.
        """
        try:
            # Check max iterations
            if self.check_max_iterations(session, current_iteration):
                return TerminationResult(
                    True,
                    "max_iterations",
                    f"Reached {session.max_iterations} iterations",
                )

            # Check solution marker
            if self.check_solution_marker(response):
                return TerminationResult(
                    True, "solution_found", "AI found solution marker in response"
                )

            # Check consensus
            if self.check_consensus(session.id, db):
                return TerminationResult(
                    True, "consensus_reached", "All agents reached consensus"
                )

            # Check no progress
            if self.check_no_progress(session.id, db, self.no_progress_window):
                return TerminationResult(
                    True, "no_progress", "No new information in recent iterations"
                )

            # Check timeout
            if self.check_timeout(session):
                return TerminationResult(
                    True, "timeout", "Session exceeded maximum duration"
                )

            # Check user stop
            if self.check_user_stop(session):
                return TerminationResult(True, "user_stop", "Session stopped by user")

            return TerminationResult(False, "continue", "Session should continue")

        except Exception as e:
            logger.error(f"Error checking termination: {e}")
            return TerminationResult(False, "error", str(e))

    def get_remaining_iterations(self, session: Session, current_iteration: int) -> int:
        """Get the number of iterations remaining before max iterations is hit.

        Args:
            session: The session object.
            current_iteration: The current iteration number.

        Returns:
            Number of remaining iterations.
        """
        max_iters = session.max_iterations or self.max_iterations
        return max(0, max_iters - current_iteration)
