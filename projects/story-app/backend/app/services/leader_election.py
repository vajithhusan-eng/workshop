"""Leader election module for the Multi-AI Agent Orchestrator.

Manages leader designation, health checks, and leader rotation
among agents within sessions.
"""

import logging
import time
from typing import Optional, Dict
from datetime import datetime

logger = logging.getLogger(__name__)


class LeaderElectionManager:
    """Manages leader election and health monitoring for agents.

    Handles user-designated leaders, heartbeat tracking, and
    automatic leader rotation if the current leader becomes unresponsive.

    Attributes:
        leader_heartbeats: Dictionary mapping session:agent to last heartbeat timestamp.
        heartbeat_interval: Seconds between expected heartbeats.
        heartbeat_timeout: Seconds after which a leader is considered unresponsive.
    """

    def __init__(self):
        """Initialize the leader election manager."""
        self.leader_heartbeats: Dict[str, float] = {}
        self.heartbeat_interval = 30  # seconds
        self.heartbeat_timeout = 90  # seconds
        logger.info("LeaderElectionManager initialized")

    def designate_leader(self, session_id: str, agent_id: str) -> bool:
        """Designate an agent as the leader for a session.

        Args:
            session_id: The session ID.
            agent_id: The agent ID to designate as leader.

        Returns:
            True if the leader was designated successfully, False otherwise.
        """
        try:
            self.leader_heartbeats[f"{session_id}:{agent_id}"] = time.time()
            logger.info(
                f"Agent {agent_id} designated as leader for session {session_id}"
            )
            return True
        except Exception as e:
            logger.error(f"Error designating leader for session {session_id}: {e}")
            return False

    async def check_leader_health(self, session_id: str, agent_id: str) -> bool:
        """Check if the current leader is responsive.

        Args:
            session_id: The session ID.
            agent_id: The agent ID to check.

        Returns:
            True if the leader is responsive, False if timeout has been exceeded.
        """
        key = f"{session_id}:{agent_id}"
        last_heartbeat = self.leader_heartbeats.get(key, 0)
        age = time.time() - last_heartbeat
        is_healthy = age < self.heartbeat_timeout

        if not is_healthy:
            logger.warning(
                f"Leader {agent_id} for session {session_id} is unresponsive (last heartbeat {age:.0f}s ago)"
            )

        return is_healthy

    async def rotate_leader(self, session_id: str, new_leader_id: str) -> bool:
        """Promote a follower to leader.

        Args:
            session_id: The session ID.
            new_leader_id: The agent ID to promote to leader.

        Returns:
            True if the leader was rotated successfully, False otherwise.
        """
        try:
            # Remove old leader heartbeat
            old_keys = [
                k for k in self.leader_heartbeats if k.startswith(f"{session_id}:")
            ]
            for key in old_keys:
                del self.leader_heartbeats[key]

            # Set new leader heartbeat
            self.leader_heartbeats[f"{session_id}:{new_leader_id}"] = time.time()
            logger.info(f"Leader rotated to {new_leader_id} for session {session_id}")
            return True
        except Exception as e:
            logger.error(f"Error rotating leader for session {session_id}: {e}")
            return False

    def get_leader(self, session_id: str) -> Optional[str]:
        """Get the current leader agent ID for a session.

        Args:
            session_id: The session ID.

        Returns:
            The leader agent ID, or None if no leader is designated.
        """
        for key in self.leader_heartbeats:
            if key.startswith(f"{session_id}:"):
                return key.split(":")[1]
        return None

    async def heartbeat(self, session_id: str, agent_id: str) -> None:
        """Record a heartbeat for an agent.

        Args:
            session_id: The session ID.
            agent_id: The agent ID sending the heartbeat.
        """
        self.leader_heartbeats[f"{session_id}:{agent_id}"] = time.time()

    def get_leader_heartbeat_age(self, session_id: str, agent_id: str) -> float:
        """Get the age (in seconds) of the last heartbeat for a leader.

        Args:
            session_id: The session ID.
            agent_id: The agent ID.

        Returns:
            Age of the last heartbeat in seconds.
        """
        key = f"{session_id}:{agent_id}"
        last_heartbeat = self.leader_heartbeats.get(key, 0)
        return time.time() - last_heartbeat

    def is_leader_responsive(self, session_id: str, agent_id: str) -> bool:
        """Check if a leader agent is currently responsive.

        Args:
            session_id: The session ID.
            agent_id: The agent ID.

        Returns:
            True if the leader is responsive, False otherwise.
        """
        return (
            self.get_leader_heartbeat_age(session_id, agent_id) < self.heartbeat_timeout
        )

    def remove_session(self, session_id: str) -> None:
        """Remove all leader election data for a session.

        Args:
            session_id: The session ID to clean up.
        """
        keys_to_remove = [
            k for k in self.leader_heartbeats if k.startswith(f"{session_id}:")
        ]
        for key in keys_to_remove:
            del self.leader_heartbeats[key]
        logger.info(f"Leader election data cleaned up for session {session_id}")
