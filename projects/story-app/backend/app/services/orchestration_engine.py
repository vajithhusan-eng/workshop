"""Orchestration engine for the Multi-AI Agent Orchestrator.

The core brain of the system — manages agent communication loops,
coordinates message routing, handles leader election, and checks
termination conditions.
"""

import asyncio
import logging
from typing import Optional, Dict, Any, List
from datetime import datetime

from app.services.message_router import MessageRouter
from app.services.leader_election import LeaderElectionManager
from app.services.termination_checker import TerminationChecker
from app.services.chrome_controller import ChromeController
from app.services.websocket_manager import WebSocketManager
from app.models.session import Session
from app.models.agent import Agent
from app.models.message import Message
from app.database import SessionLocal

logger = logging.getLogger(__name__)


class OrchestrationEngine:
    """Core orchestration engine for managing agent communication loops.

    Manages the communication loop between AI agents, handles leader
    election, routes messages, checks termination conditions, and
    coordinates Chrome browser automation via Playwright.

    Attributes:
        running: Whether the engine is currently running any loops.
        active_loops: Set of session IDs with running loops.
        message_router: Message routing component.
        leader_election: Leader election component.
        termination_checker: Termination condition checker.
        chrome_controller: Chrome browser controller.
        ws_manager: WebSocket manager for real-time updates.
    """

    def __init__(self):
        """Initialize the orchestration engine with all sub-services."""
        self.running = False
        self.active_loops: set = set()
        self._loops: Dict[str, asyncio.Task] = {}

        self.message_router = MessageRouter()
        self.leader_election = LeaderElectionManager()
        self.termination_checker = TerminationChecker()
        self.chrome_controller = ChromeController()
        self.ws_manager = WebSocketManager()

        logger.info("OrchestrationEngine initialized")

    def start(self) -> None:
        """Start the orchestration engine. Called during application startup."""
        self.running = True
        logger.info("Orchestration engine started")

    def stop(self) -> None:
        """Stop all running orchestration loops. Called during application shutdown."""
        self.running = False
        for session_id, task in self._loops.items():
            task.cancel()
            logger.info(f"Cancelled loop for session {session_id}")
        self._loops.clear()
        self.active_loops.clear()
        logger.info("All orchestration loops stopped")

    async def start_session(self, session_id: str) -> bool:
        """Start the orchestration loop for a specific session.

        Args:
            session_id: The session ID to start the loop for.

        Returns:
            True if the loop was started successfully, False otherwise.
        """
        if session_id in self.active_loops:
            logger.warning(f"Session {session_id} already has an active loop")
            return False

        try:
            self.active_loops.add(session_id)
            task = asyncio.create_task(self.run(session_id))
            self._loops[session_id] = task
            logger.info(f"Orchestration loop started for session {session_id}")
            return True
        except Exception as e:
            logger.error(
                f"Failed to start orchestration loop for session {session_id}: {e}"
            )
            self.active_loops.discard(session_id)
            return False

    async def stop_session(self, session_id: str) -> bool:
        """Stop the orchestration loop for a specific session.

        Args:
            session_id: The session ID to stop.

        Returns:
            True if the loop was stopped successfully, False otherwise.
        """
        if session_id not in self.active_loops:
            logger.warning(f"Session {session_id} does not have an active loop")
            return False

        try:
            if session_id in self._loops:
                self._loops[session_id].cancel()
                try:
                    await self._loops[session_id]
                except asyncio.CancelledError:
                    pass
                del self._loops[session_id]

            self.active_loops.discard(session_id)
            logger.info(f"Orchestration loop stopped for session {session_id}")
            return True
        except Exception as e:
            logger.error(
                f"Error stopping orchestration loop for session {session_id}: {e}"
            )
            return False

    async def run(self, session_id: str) -> None:
        """Main entry point for the orchestration loop.

        Runs the communication loop until termination conditions are met.

        Args:
            session_id: The session ID to run the loop for.
        """
        db = SessionLocal()
        try:
            session = db.query(Session).filter(Session.id == session_id).first()
            if not session:
                logger.error(f"Session {session_id} not found")
                return

            logger.info(f"Starting orchestration loop for session {session_id}")

            # Notify clients that session has started
            agents = db.query(Agent).filter(Agent.session_id == session_id).all()
            await self.ws_manager.send_session_started(
                session_id, [a.to_dict() for a in agents], session.max_iterations
            )

            iteration = 0
            max_iterations = session.max_iterations or 50
            terminated = False
            termination_reason = None

            while not terminated and iteration < max_iterations and self.running:
                try:
                    # Get the next speaker
                    current_agent = await self.get_next_speaker(
                        session_id, iteration, db
                    )
                    if not current_agent:
                        logger.warning(f"No agent available for iteration {iteration}")
                        break

                    # Notify clients of iteration update
                    await self.ws_manager.send_iteration_update(
                        session_id, iteration, current_agent.id
                    )

                    # Build context for the agent
                    context = await self.build_context(
                        session_id, current_agent.id, iteration, db
                    )

                    # Execute agent turn via Chrome
                    response = await self.execute_agent_turn(
                        session_id, current_agent, context, iteration
                    )

                    if response:
                        # Store the response
                        message = Message(
                            session_id=session_id,
                            agent_id=current_agent.id,
                            role="assistant",
                            content=response,
                            iteration=iteration,
                            is_from_browser=True,
                        )
                        db.add(message)
                        db.commit()

                        # Update session iteration count
                        session.current_iteration = iteration + 1
                        db.commit()

                        # Push to Flutter via WebSocket
                        await self.ws_manager.send_new_message(
                            session_id, message.to_dict()
                        )

                        # Check termination
                        (
                            terminated,
                            termination_reason,
                        ) = await self.termination_checker.should_terminate(
                            session, response, iteration, db
                        )

                        if terminated:
                            logger.info(
                                f"Termination condition met at iteration {iteration}: {termination_reason}"
                            )
                            break

                    iteration += 1

                except asyncio.CancelledError:
                    logger.info(
                        f"Orchestration loop cancelled for session {session_id}"
                    )
                    break
                except Exception as e:
                    logger.error(
                        f"Error in orchestration loop iteration {iteration}: {e}"
                    )
                    await self.ws_manager.send_error(session_id, "LOOP_ERROR", str(e))
                    iteration += 1
                    continue

            # Mark session as complete
            await self.mark_session_complete(
                session_id, termination_reason or "max_iterations"
            )

        except Exception as e:
            logger.error(f"Error in orchestration loop for session {session_id}: {e}")
        finally:
            db.close()
            self.active_loops.discard(session_id)
            self.ws_manager.send_session_completed(
                session_id,
                termination_reason or "max_iterations",
                "Session completed",
                iteration,
            )
            logger.info(f"Orchestration loop ended for session {session_id}")

    async def execute_agent_turn(
        self, session_id: str, agent: Agent, context: str, iteration: int
    ) -> Optional[str]:
        """Execute a single agent turn via Chrome browser automation.

        Args:
            session_id: The session ID.
            agent: The agent to execute the turn for.
            context: The context message to send to the agent.
            iteration: The current iteration number.

        Returns:
            The AI's response string, or None if execution failed.
        """
        try:
            if not agent.is_connected:
                logger.warning(f"Agent {agent.id} is not connected to Chrome")
                await self.ws_manager.send_error(
                    session_id,
                    "AGENT_DISCONNECTED",
                    f"Agent {agent.name} is not connected",
                )
                return None

            # Execute via Chrome controller
            response = await self.chrome_controller.execute_agent_message(
                agent, context
            )
            logger.info(f"Agent {agent.id} responded at iteration {iteration}")
            return response

        except Exception as e:
            logger.error(f"Error executing agent turn for {agent.id}: {e}")
            await self.ws_manager.send_error(session_id, "EXECUTION_ERROR", str(e))
            return None

    async def get_next_speaker(
        self, session_id: str, iteration: int, db
    ) -> Optional[Agent]:
        """Determine which agent speaks next based on round-robin or leader priority.

        Args:
            session_id: The session ID.
            iteration: The current iteration number.
            db: Database session.

        Returns:
            The next Agent to speak, or None if no agents available.
        """
        try:
            agents = db.query(Agent).filter(Agent.session_id == session_id).all()
            if not agents:
                return None

            leaders = [a for a in agents if a.is_leader()]
            followers = [a for a in agents if not a.is_leader()]

            if not leaders and not followers:
                return None

            if not leaders:
                # No leader, round-robin among all
                return agents[iteration % len(agents)]

            if not followers:
                # Only leader
                return leaders[0]

            # Leader speaks on even iterations, followers on odd
            if iteration % 2 == 0:
                return leaders[0]
            else:
                follower_index = (iteration - 1) // 2 % len(followers)
                return followers[follower_index]

        except Exception as e:
            logger.error(f"Error determining next speaker: {e}")
            return None

    async def build_context(
        self, session_id: str, agent_id: str, iteration: int, db
    ) -> str:
        """Build the context message for an agent.

        Includes all previous messages so agents can reference them.

        Args:
            session_id: The session ID.
            agent_id: The agent ID to build context for.
            iteration: The current iteration number.
            db: Database session.

        Returns:
            Context string with all previous messages.
        """
        try:
            messages = (
                db.query(Message)
                .filter(Message.session_id == session_id)
                .order_by(Message.created_at.asc())
                .all()
            )

            context_parts = []
            for msg in messages:
                agent_name = msg.agent.name if msg.agent else "Unknown"
                prefix = f"[{agent_name}]" if msg.role != "user" else ""
                context_parts.append(f"{prefix} {msg.role}: {msg.content[:500]}")

            context = "\n\n".join(context_parts)

            # Add context about the current agent
            agent = db.query(Agent).filter(Agent.id == agent_id).first()
            agent_name = agent.name if agent else "Agent"
            context = f"You are {agent_name}. Here is the conversation so far:\n\n{context}\n\nPlease continue."

            return context

        except Exception as e:
            logger.error(f"Error building context for agent {agent_id}: {e}")
            return "Please provide your response."

    async def mark_session_complete(self, session_id: str, reason: str) -> None:
        """Mark a session as completed.

        Args:
            session_id: The session ID to complete.
            reason: The reason for completion.
        """
        try:
            db = SessionLocal()
            session = db.query(Session).filter(Session.id == session_id).first()
            if session:
                session.mark_complete(reason)
                db.commit()
                logger.info(f"Session {session_id} marked as complete: {reason}")
            db.close()
        except Exception as e:
            logger.error(f"Error marking session {session_id} as complete: {e}")
