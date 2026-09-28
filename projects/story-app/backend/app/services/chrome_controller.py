"""Chrome controller for the Multi-AI Agent Orchestrator.

Provides Playwright integration for Chrome browser automation,
including navigation, message typing, response reading, and
page management.
"""

import logging
from typing import Optional, Any
from pathlib import Path

try:
    from playwright.async_api import async_playwright, Browser, Page, BrowserContext

    PLAYWRIGHT_AVAILABLE = True
except ImportError:
    PLAYWRIGHT_AVAILABLE = False
    Browser = None
    Page = None
    BrowserContext = None

from app.config import settings

logger = logging.getLogger(__name__)


class ChromeController:
    """Controller for Chrome browser automation via Playwright.

    Manages browser launching, page navigation, message input,
    response extraction, and cookie/session management.

    Attributes:
        browser: The active Playwright browser instance.
        context: The active browser context.
        pages: Dictionary mapping agent IDs to browser pages.
        is_connected: Whether the browser is currently connected.
    """

    def __init__(self):
        """Initialize the Chrome controller.

        Note:
            If Playwright is not installed, browser operations will be
            gracefully unavailable.
        """
        self.browser: Optional[Browser] = None
        self.context: Optional[BrowserContext] = None
        self.pages: dict = {}  # agent_id -> Page
        self.is_connected = False
        self._playwright = None

        if not PLAYWRIGHT_AVAILABLE:
            logger.warning(
                "Playwright not installed. Chrome controller will be unavailable."
            )
        else:
            logger.info("ChromeController initialized")

    async def initialize(self) -> bool:
        """Initialize the Chrome browser with user profile.

        Launches Chrome with the user's profile path for authentication
        persistence.

        Returns:
            True if initialization was successful, False otherwise.
        """
        if not PLAYWRIGHT_AVAILABLE:
            logger.warning("Playwright not available, cannot initialize Chrome")
            return False

        try:
            self._playwright = await async_playwright().start()
            profile_path = Path(settings.CHROME_PROFILE_PATH).expanduser()
            profile_path.mkdir(parents=True, exist_ok=True)

            self.browser = await self._playwright.chromium.launch(
                headless=settings.HEADLESS,
                user_data_dir=str(profile_path),
                args=[
                    "--disable-blink-features=AutomationControlled",
                    "--no-sandbox",
                    "--disable-dev-shm-usage",
                ]
                if settings.HEADLESS
                else [],
            )

            self.context = await self.browser.new_context()
            self.is_connected = True
            logger.info("Chrome browser initialized successfully")
            return True
        except Exception as e:
            logger.error(f"Failed to initialize Chrome: {e}")
            self.is_connected = False
            return False

    async def launch_browser(
        self, profile_path: Optional[str] = None
    ) -> Optional[Browser]:
        """Launch Chrome browser with optional profile.

        Args:
            profile_path: Optional path to Chrome user profile.

        Returns:
            The launched Browser instance, or None on failure.
        """
        if not PLAYWRIGHT_AVAILABLE or not self._playwright:
            logger.error("Playwright not available")
            return None

        try:
            path = Path(profile_path or settings.CHROME_PROFILE_PATH).expanduser()
            path.mkdir(parents=True, exist_ok=True)

            self.browser = await self._playwright.chromium.launch(
                headless=settings.HEADLESS,
                user_data_dir=str(path),
            )
            self.is_connected = True
            logger.info(f"Browser launched with profile: {path}")
            return self.browser
        except Exception as e:
            logger.error(f"Error launching browser: {e}")
            return None

    async def navigate_to_page(
        self, agent, url: Optional[str] = None
    ) -> Optional[Page]:
        """Navigate to an agent's web interface.

        Args:
            agent: The agent object with web_url.
            url: Optional override URL.

        Returns:
            The Page object, or None on failure.
        """
        if not self.browser or not self.is_connected:
            logger.error("Browser not connected")
            return None

        try:
            target_url = url or agent.web_url
            page = await self.browser.new_page()
            await page.goto(target_url, wait_until="networkidle", timeout=30000)

            agent_id = getattr(agent, "id", str(agent))
            self.pages[agent_id] = page
            logger.info(f"Navigated to {target_url} for agent {agent_id}")
            return page
        except Exception as e:
            logger.error(f"Error navigating to {url or agent.web_url}: {e}")
            return None

    async def type_message(self, page: Page, message: str) -> bool:
        """Type a message into the chat input field.

        Args:
            page: The browser page to type into.
            message: The message content to type.

        Returns:
            True if typing was successful, False otherwise.
        """
        if not page:
            logger.error("No page provided for typing")
            return False

        try:
            # Common selectors for chat input fields
            input_selectors = [
                "textarea[placeholder*='message']",
                "textarea[placeholder*='chat']",
                "input[type='text']",
                "div[contenteditable='true']",
                "textarea",
                "[data-testid='chat-input']",
            ]

            for selector in input_selectors:
                try:
                    input_element = await page.wait_for_selector(selector, timeout=5000)
                    if input_element:
                        await input_element.fill(message)
                        await page.keyboard.press("Enter")
                        logger.info(f"Typed message into {selector}")
                        return True
                except Exception:
                    continue

            logger.error("Could not find chat input field")
            return False
        except Exception as e:
            logger.error(f"Error typing message: {e}")
            return False

    async def read_response(self, page: Page, timeout: int = 30000) -> Optional[str]:
        """Extract AI response from the page.

        Waits for new content to appear and extracts the response text.

        Args:
            page: The browser page to read from.
            timeout: Maximum time to wait for a response (ms).

        Returns:
            The response text, or None if extraction failed.
        """
        if not page:
            logger.error("No page provided for reading response")
            return None

        try:
            # Common selectors for chat messages
            response_selectors = [
                "[data-message-role='assistant']",
                ".message-content",
                "[class*='response']",
                ".chat-response",
                "[class*='assistant']",
                ".flex-1",  # Common chat bubble class
            ]

            for selector in response_selectors:
                try:
                    content = await page.wait_for_selector(selector, timeout=timeout)
                    if content:
                        text = await content.inner_text()
                        logger.info(f"Read response from {selector}")
                        return text.strip()
                except Exception:
                    continue

            logger.warning("Could not find response element on page")
            return None
        except Exception as e:
            logger.error(f"Error reading response: {e}")
            return None

    async def execute_agent_message(self, agent, content: str) -> Optional[str]:
        """Execute the full flow for an agent message: navigate, type, read.

        Args:
            agent: The agent object with web_url.
            content: The message content to send.

        Returns:
            The AI's response text, or None if execution failed.
        """
        if not self.browser or not self.is_connected:
            logger.error("Browser not connected")
            return None

        try:
            # Navigate to agent's page
            page = await self.navigate_to_page(agent)
            if not page:
                return None

            # Type the message
            success = await self.type_message(page, content)
            if not success:
                return None

            # Wait and read the response
            await page.wait_for_timeout(2000)  # Wait for response to start
            response = await self.read_response(page)

            if response:
                logger.info(f"Agent {agent.name} responded successfully")
            else:
                logger.warning(f"No response from agent {agent.name}")

            return response

        except Exception as e:
            logger.error(f"Error executing agent message: {e}")
            return None

    async def screenshot(self, page: Page, path: Optional[str] = None) -> bool:
        """Capture a page screenshot.

        Args:
            page: The browser page to screenshot.
            path: Optional path to save the screenshot.

        Returns:
            True if screenshot was taken successfully, False otherwise.
        """
        if not page:
            logger.error("No page for screenshot")
            return False

        try:
            if not path:
                path = f"screenshot_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
            await page.screenshot(path=path, full_page=True)
            logger.info(f"Screenshot saved to {path}")
            return True
        except Exception as e:
            logger.error(f"Error taking screenshot: {e}")
            return False

    async def close_browser(self) -> None:
        """Close the Chrome browser."""
        try:
            if self.browser:
                await self.browser.close()
                self.browser = None
                self.is_connected = False
                logger.info("Chrome browser closed")
        except Exception as e:
            logger.error(f"Error closing browser: {e}")

    async def cleanup(self) -> None:
        """Cleanup all resources."""
        try:
            await self.close_browser()
            self.pages.clear()
            logger.info("Chrome controller cleanup complete")
        except Exception as e:
            logger.error(f"Error during cleanup: {e}")

    def is_browser_connected(self) -> bool:
        """Check if the browser is connected.

        Returns:
            True if the browser is connected, False otherwise.
        """
        return self.is_connected and self.browser is not None

    async def get_page_content(self, page: Page) -> str:
        """Get the full page content.

        Args:
            page: The browser page.

        Returns:
            The page's HTML content as a string.
        """
        if not page:
            return ""

        try:
            content = await page.content()
            return content
        except Exception as e:
            logger.error(f"Error getting page content: {e}")
            return ""

    async def connect_agent(self, agent) -> bool:
        """Connect an agent to the Chrome browser.

        Args:
            agent: The agent object.

        Returns:
            True if connection was successful, False otherwise.
        """
        try:
            if not self.browser or not self.is_connected:
                if not await self.initialize():
                    return False

            page = await self.navigate_to_page(agent)
            if page:
                agent_id = getattr(agent, "id", str(agent))
                self.pages[agent_id] = page
                agent.is_connected = True
                agent.connect()
                logger.info(f"Agent {agent_id} connected to Chrome")
                return True
            return False
        except Exception as e:
            logger.error(f"Error connecting agent to Chrome: {e}")
            return False
