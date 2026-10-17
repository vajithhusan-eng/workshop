# Multi-AI Agent Orchestrator — Architecture Design Document

> **Project**: Multi-AI Agent Orchestrator (Ubuntu Linux Desktop App)
> **Target Platform**: Ubuntu Linux (AppImage)
> **Backend**: Python/FastAPI
> **Frontend**: Flutter Desktop
> **Browser Automation**: Playwright MCP Server
> **Document Version**: 1.0 | **Date**: 2026-09-28
> **Author**: Architecture Design Session

---

## Table of Contents

1. [Overview and System Summary](#1-overview-and-system-summary)
2. [Architecture Diagram](#2-architecture-diagram)
3. [Component Breakdown and Responsibilities](#3-component-breakdown-and-responsibilities)
4. [Data Models and Relationships](#4-data-models-and-relationships)
5. [API Design](#5-api-design)
6. [Communication Flow](#6-communication-flow)
7. [Chrome Browser Integration Plan](#7-chrome-browser-integration-plan)
8. [Session Management Design](#8-session-management-design)
9. [Tech Stack Justification](#9-tech-stack-justification)
10. [Implementation Plan](#10-implementation-plan)
11. [Risks and Mitigations](#11-risks-and-mitigations)

---

## 1. Overview and System Summary

### 1.1 Problem Statement

Users who work with multiple AI agents (ChatGPT, Gemini, DeepSeek) for research currently rely on manual copy-paste between ChatGPT group chats. This is slow, error-prone, and lacks persistent organization. There is no unified interface to coordinate multiple AI agents working together on a single problem.

### 1.2 Solution Summary

The Multi-AI Agent Orchestrator is a **desktop application** that serves as a central coordination hub for multiple AI agents. It:

- **Connects** to AI agent web interfaces via Chrome browser automation (Playwright)
- **Orchestrates** agent communication using a leader-follower model
- **Manages sessions** — each session is an isolated project with its own set of agents and conversation history
- **Provides real-time chat** interface via WebSocket communication
- **Runs on Ubuntu Linux** as a self-contained AppImage

### 1.3 Core Design Principles

| Principle | Implementation |
|-----------|---------------|
| **Local-first** | All data stored locally (SQLite); no cloud dependency |
| **Browser-as-interface** | Playwright controls Chrome to interact with AI web apps |
| **Session isolation** | Each session = independent project, agents, and message history |
| **Real-time** | WebSocket-based communication for instant UI updates |
| **Extensible** | Agent type abstraction allows adding new AI providers |
| **User-controlled** | User designates leaders, adds/removes agents, sets termination conditions |

### 1.4 Key Stakeholders

- **End User**: Researcher who needs to coordinate multiple AI agents
- **System**: FastAPI backend, Flutter frontend, Playwright browser controller
- **AI Agents**: ChatGPT, Gemini, DeepSeek (web-based interfaces)

---

## 2. Architecture Diagram

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        FLUTTER DESKTOP APP                           │
│                     (Linux AppImage / tar.gz)                        │
│                                                                      │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────────────┐ │
│  │  Session     │  │  Chat        │  │  Agent Config              │ │
│  │  List View   │  │  Interface   │  │  Panel                     │ │
│  │  Manager     │  │  (Multi-     │  │  (Add/Remove/Configure     │ │
│  │              │  │   Agent)     │  │   Agents)                  │ │
│  └──────┬───────┘  └──────┬───────┘  └────────────┬───────────────┘ │
│         │                 │                       │                 │
│  ┌──────┴─────────────────┴───────────────────────┴───────────────┐ │
│  │                    Flutter State Management                    │ │
│  │                  (Riverpod / StateNotifier)                    │ │
│  └──────────────────────────────┬─────────────────────────────────┘ │
│                                 │ WebSocket                        │
└─────────────────────────────────┼──────────────────────────────────┘
                                  │ ws://localhost:8000/ws
                                  │
┌─────────────────────────────────┼──────────────────────────────────┐
│                     FASTAPI BACKEND (localhost:8000)                │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                   Orchestration Engine                       │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐  │   │
│  │  │ Leader       │  │ Message      │  │ Termination       │  │   │
│  │  │ Election     │  │ Router       │  │ Condition         │  │   │
│  │  │ Manager      │  │              │  │ Checker           │  │   │
│  │  └──────────────┘  └──────────────┘  └───────────────────┘  │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │           Agent Communication Loop                    │   │   │
│  │  │  While NOT terminated:                                │   │   │
│  │  │    1. Route message to current speaker               │   │   │
│  │  │    2. Execute via Playwright (Chrome)                │   │   │
│  │  │    3. Capture response                               │   │   │
│  │  │    4. Determine next speaker                         │   │   │
│  │  │    5. Check termination                              │   │   │
│  │  └──────────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────────┐  │
│  │  Session        │  │  Agent          │  │  Message           │  │
│  │  Manager        │  │  Registry       │  │  Store             │  │
│  │  (CRUD)         │  │  (Register/     │  │  (CRUD)            │  │
│  │                 │  │   Configure)    │  │                    │  │
│  └─────────────────┘  └─────────────────┘  └────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              Playwright Controller                            │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │   │
│  │  │ Chrome       │  │ Page         │  │ Auth             │   │   │
│  │  │ Browser      │  │ Manager      │  │ Handler          │   │   │
│  │  │ Instance     │  │              │  │                  │   │   │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              WebSocket Server                                 │   │
│  │  (Real-time bidirectional communication with Flutter app)    │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│              ┌─────────────────────────┐                            │
│              │      SQLite Database     │                            │
│              │   (sessions.db)          │                            │
│              └─────────────────────────┘                            │
└──────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ Playwright MCP Protocol
                                  │
┌─────────────────────────────────┼──────────────────────────────────┐
│                    GOOGLE CHROME                                        │
│                   (User Profile)                                       │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐     │
│  │ ChatGPT      │  │ Gemini       │  │ DeepSeek             │     │
│  │ (web.app)    │  │ (gemini.google│ │ (deepseek.com)       │     │
│  │              │  │  .com)       │  │                      │     │
│  └──────────────┘  └──────────────┘  └──────────────────────┘     │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Interaction Diagram

```
User Action Flow:
════════════════

┌──────┐     ┌──────────┐     ┌───────────────┐     ┌──────────┐     ┌──────────┐
│Flutter│────▶│FastAPI   │────▶│Orchestration  │────▶│Playwright│────▶│ Chrome   │
│Desktop│     │Backend   │     │Engine         │     │Controller│     │(AI Web)  │
│App    │◀────│WebSocket │◀────│               │◀────│          │◀────│          │
└──────┘     └──────────┘     └───────────────┘     └──────────┘     └──────────┘
    │               │                │                   │                    │
    │ Session CRUD  │ Agent Mgmt     │ Leader Election   │ Navigate to       │
    │ Chat Send     │ Message Route  │ Msg Routing       │ Web Interfaces    │
    │ UI Update     │ Terminate      │ Loop Control      │ Type/Read Msgs  │
    │ Config Save   │                │                   │                     │
    ▼               ▼                ▼                   ▼                    │
┌──────────────────────────────────────────────────────────────────────────────┐
│                              SQLite Database                                  │
│  sessions │ agents │ messages │ agent_configs                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Data Flow

```
                    ┌──────────────┐
                    │   USER INPUT │
                    │  (Flutter UI)│
                    └──────┬───────┘
                           │ WebSocket message
                           ▼
                    ┌──────────────┐
                    │ FastAPI      │
                    │ WebSocket    │
                    │ Endpoint     │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ Orchestration│
                    │ Engine       │
                    │              │
                    │ • Identify   │
                    │   current    │
                    │   speaker    │
                    │ • Check      │
                    │   termination│
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              │                         │
              ▼                         ▼
     ┌──────────────┐         ┌──────────────┐
     │ Leader Agent │         │ Follower     │
     │ (if speaking)│         │ Agent        │
     └──────┬───────┘         └──────┬───────┘
            │                       │
            ▼                       ▼
     ┌──────────────┐         ┌──────────────┐
     │ Playwright   │         │ Playwright   │
     │ → Chrome     │         │ → Chrome     │
     │ → Web Page   │         │ → Web Page   │
     └──────┬───────┘         └──────┬───────┘
            │                       │
            ▼                       ▼
     ┌──────────────┐         ┌──────────────┐
     │ ChatGPT      │         │ Gemini       │
     │ (reads/      │         │ (reads/      │
     │  types msg)  │         │  types msg)  │
     └──────┬───────┘         └──────┬───────┘
            │                       │
            ▼                       ▼
     ┌─────────────────────────────────────────┐
     │  Response captured by Playwright        │
     │  → Sent back to Orchestration Engine     │
     │  → Stored in SQLite                      │
     │  → Pushed to Flutter via WebSocket       │
     │  → UI updated                            │
     └─────────────────────────────────────────┘
```

---

## 3. Component Breakdown and Responsibilities

### 3.1 Component Map

```
story-app/
├── backend/                          # Python/FastAPI
│   ├── main.py                       # App entry point
│   ├── config.py                     # Configuration settings
│   ├── database/                     # Database layer
│   │   ├── __init__.py
│   │   ├── models.py                 # SQLAlchemy ORM models
│   │   ├── migrations/               # Alembic migrations
│   │   └── repository.py             # Data access layer
│   ├── api/                          # API routes
│   │   ├── __init__.py
│   │   ├── sessions.py               # Session CRUD endpoints
│   │   ├── agents.py                 # Agent management endpoints
│   │   ├── messages.py               # Message endpoints
│   │   └── websocket.py              # WebSocket handlers
│   ├── services/                     # Business logic
│   │   ├── __init__.py
│   │   ├── orchestration_engine.py   # Core orchestration logic
│   │   ├── leader_election.py        # Leader election & health
│   │   ├── message_router.py         # Message routing between agents
│   │   ├── termination_checker.py    # Termination condition checker
│   │   └── chrome_controller.py      # Playwright Chrome interaction
│   ├── models/                       # Pydantic schemas
│   │   ├── __init__.py
│   │   ├── session.py
│   │   ├── agent.py
│   │   └── message.py
│   ├── workers/                      # Background tasks
│   │   ├── __init__.py
│   │   └── agent_loop_worker.py      # Agent communication loop
│   └── requirements.txt
│
├── frontend/                         # Flutter Desktop
│   ├── lib/
│   │   ├── main.dart                 # App entry point
│   │   ├── app.dart                  # App widget tree
│   │   ├── providers/                # Riverpod providers
│   │   │   ├── session_provider.dart
│   │   │   ├── chat_provider.dart
│   │   │   └── agent_provider.dart
│   │   ├── screens/                  # Page-level widgets
│   │   │   ├── session_list_screen.dart
│   │   │   ├── chat_screen.dart
│   │   │   └── agent_config_screen.dart
│   │   ├── widgets/                  # Reusable components
│   │   │   ├── message_bubble.dart
│   │   │   ├── agent_avatar.dart
│   │   │   ├── chat_input.dart
│   │   │   └── session_card.dart
│   │   ├── services/                 # Frontend services
│   │   │   ├── websocket_service.dart
│   │   │   ├── api_client.dart
│   │   │   └── chrome_manager.dart
│   │   ├── models/                   # Dart data models
│   │   │   ├── session_model.dart
│   │   │   ├── agent_model.dart
│   │   │   └── message_model.dart
│   │   └── theme/                    # App theming
│   │       └── app_theme.dart
│   ├── pubspec.yaml
│   └── linux/                        # Linux-specific build config
│       └── cmake/
│
├── playwright/                       # Playwright configuration
│   ├── playwright.config.ts
│   └── chromium/                     # Chromium binary paths
│
├── tools/                            # Utility scripts
│   ├── build_appimage.sh             # AppImage build script
│   ├── build_linux.sh                # Linux tar.gz build
│   └── setup_chrome_profile.sh       # Chrome profile setup
│
└── tests/                            # Test suite
    ├── backend/
    │   ├── test_orchestration.py
    │   ├── test_websocket.py
    │   └── test_api.py
    └── frontend/
        └── test_*.dart
```

### 3.2 Backend Components

#### 3.2.1 FastAPI Application Server

**Responsibility**: Central HTTP/WebSocket server handling all client requests

| Function | Detail |
|----------|--------|
| REST API | Session CRUD, Agent CRUD, Message retrieval |
| WebSocket | Real-time bidirectional communication with Flutter |
| CORS | Allow connections from localhost Flutter app |
| Auth | Simple token-based (API key stored in config) |
| Health | `/health` endpoint for AppImage self-check |

#### 3.2.2 Orchestration Engine

**Responsibility**: Core brain of the system — manages agent communication loops

| Function | Detail |
|----------|--------|
| **Communication Loop** | Main while-loop that drives agent-to-agent conversation |
| **Speaker Selection** | Determines which agent speaks next based on round-robin or role |
| **Message Dispatch** | Sends messages to agents via Playwright/Chrome |
| **Response Capture** | Extracts AI responses from web pages |
| **State Tracking** | Maintains conversation state for each session |
| **Loop Termination** | Checks termination conditions after each exchange |

```python
# Pseudo-code for the orchestration loop
async def communication_loop(session_id: str):
    session = session_manager.get(session_id)
    terminated = False
    max_iterations = session.max_iterations or 50
    iteration = 0
    
    while not terminated and iteration < max_iterations:
        current_agent = get_next_speaker(session, iteration)
        
        if current_agent.role == "leader":
            # Leader initiates or continues the problem
            message = generate_leader_message(session, iteration)
        else:
            # Follower responds to previous agent
            message = generate_follower_message(session, iteration)
        
        # Execute via Playwright
        response = await chrome_controller.execute_message(
            agent=current_agent,
            message=message,
            session_id=session_id
        )
        
        # Store response
        await message_store.save(session_id, current_agent.id, response)
        
        # Push to Flutter via WebSocket
        await websocket_manager.send(session_id, response)
        
        # Check termination
        terminated = termination_checker.check(response, session)
        iteration += 1
    
    await session_manager.mark_complete(session_id)
```

#### 3.2.3 Leader Election Manager

**Responsibility**: Manages which agent is the leader and monitors leader health

| Function | Detail |
|----------|--------|
| **Leader Designation** | User assigns leader role; stored in session config |
| **Leader Health Check** | Heartbeat mechanism to detect unresponsive leaders |
| **Leader Rotation** | Optional: rotate leader if current leader fails |
| **Fallback** | If leader becomes unresponsive, promote a follower |

```python
class LeaderElectionManager:
    def __init__(self):
        self.leader_heartbeats: Dict[str, float] = {}
        self.heartbeat_interval = 30  # seconds
        self.heartbeat_timeout = 90   # seconds
    
    def designate_leader(self, session_id: str, agent_id: str):
        """Set an agent as leader for a session"""
        # Update session config in database
        # Initialize heartbeat tracking
    
    async def check_leader_health(self, session_id: str) -> bool:
        """Check if current leader is responsive"""
        leader = self.get_leader(session_id)
        last_heartbeat = self.leader_heartbeats.get(f"{session_id}:{leader.id}", 0)
        return (time.time() - last_heartbeat) < self.heartbeat_timeout
    
    async def rotate_leader(self, session_id: str, new_leader_id: str):
        """Promote a follower to leader"""
        # Atomic update in database
        # Notify all agents via WebSocket
        # Update leader election state
```

#### 3.2.4 Message Router

**Responsibility**: Routes messages between agents in the correct order

| Function | Detail |
|----------|--------|
| **Message Queue** | Per-session message queue (in-memory priority queue) |
| **Ordering** | Ensures messages are processed in correct sequence |
| **Fan-out** | Broadcasts messages from leader to all followers |
| **Deduplication** | Prevents duplicate message processing |
| **Retry Logic** | Retries failed message deliveries |

#### 3.2.5 Termination Condition Checker

**Responsibility**: Determines when the agent communication loop should stop

| Condition | Description |
|-----------|-------------|
| **Max Iterations** | Hard limit on conversation turns (default: 50) |
| **Problem Solved** | AI responds with solution completion indicator |
| **User Stop** | User manually stops the session |
| **Timeout** | Session exceeds maximum duration (configurable) |
| **Consensus Reached** | All agents agree on an answer |
| **No Progress** | Last N iterations produced no new information |

```python
class TerminationChecker:
    def check(self, response: str, session: Session) -> bool:
        # Check for explicit solution markers
        if self._contains_solution_marker(response):
            return True
        
        # Check max iterations
        if session.message_count >= session.max_iterations:
            return True
        
        # Check for consensus
        if self._agents_agreed(session):
            return True
        
        # Check for no progress (last 5 responses are repetitive)
        if self._no_progress(session, window=5):
            return True
        
        return False
```

#### 3.2.6 Chrome Controller (Playwright Integration)

**Responsibility**: Controls Chrome browser to interact with AI web interfaces

| Function | Detail |
|----------|--------|
| **Browser Launch** | Start Chrome with user's profile |
| **Page Navigation** | Navigate to ChatGPT, Gemini, DeepSeek URLs |
| **Message Input** | Type messages into chat input fields |
| **Message Reading** | Extract messages from conversation bubbles |
| **Screenshot/Capture** | Capture page state for verification |
| **Cookie Management** | Maintain authentication cookies |
| **Error Handling** | Handle network errors, page reloads, CAPTCHAs |

### 3.3 Frontend Components

#### 3.3.1 Flutter Desktop Application

**Responsibility**: User interface for managing sessions, chatting, and configuring agents

| Component | Responsibility |
|-----------|---------------|
| **Session List Screen** | Display all sessions with create/edit/delete |
| **Chat Screen** | Real-time multi-agent conversation view |
| **Agent Config Screen** | Add/remove agents, set roles, configure URLs |
| **Chrome Manager** | Control Chrome launch, connect/disconnect |
| **WebSocket Service** | Maintain WebSocket connection to backend |
| **State Management** | Riverpod-based reactive state |

#### 3.3.2 Key Widgets

| Widget | Purpose |
|--------|---------|
| `SessionCard` | Visual representation of a session in the list |
| `MessageBubble` | Individual message display with agent avatar |
| `ChatInput` | Message input with agent selector |
| `AgentAvatar` | Colored avatar for each agent type |
| `ConnectionStatus` | Chrome/Playwright connection indicator |
| `SessionProgress` | Shows iteration count, termination status |

### 3.4 Playwright MCP Server

**Responsibility**: Bridge between backend and Chrome browser

| Function | Detail |
|----------|--------|
| **Tool Interface** | Exposes `navigate`, `click`, `type`, `read`, `screenshot` tools |
| **Chrome Profile** | Connects to existing Chrome profile for auth persistence |
| **Session Management** | Maintains separate browser contexts per session |
| **Event Monitoring** | Listens for page changes, new messages, errors |
| **Headless Control** | Can run headless or with visible Chrome window |

---

## 4. Data Models and Relationships

### 4.1 Entity Relationship Diagram

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│   SESSION    │       │    AGENT     │       │   MESSAGE    │
├─────────────┤       ├─────────────┤       ├─────────────┤
│ id (PK)      │──1───┤ session_id  │       │ id (PK)      │
│ name         │       │ agent_id(PK) │       │ session_id   │
│ description  │       │ session_id   │       │ agent_id     │
│ created_at   │       │ type         │       │ agent_id(FK) │
│ updated_at   │       │ web_url      │       │ content      │
│ status       │       │ role         │       │ role         │
│ max_iter     │       │ status       │       │ content      │
│ current_iter │       │ config       │       │ timestamp    │
│ agent_ids    │       │ added_at     │       │              │
│ leader_id    │       │             │       │              │
│ created_by   │       │             │       │              │
└──────┬───────┘       └─────────────┘       └──────┬──────┘
       │                                             │
       │ 1:N                                         │ N:1
       │                                             │
       └─────────────────────────────────────────────┘
```

### 4.2 Detailed Schema

#### 4.2.1 Session Model

```sql
CREATE TABLE sessions (
    id              TEXT PRIMARY KEY,           -- UUID
    name            TEXT NOT NULL,               -- User-visible name
    description     TEXT DEFAULT '',
    status          TEXT NOT NULL DEFAULT 'active', -- active, completed, archived, deleted
    created_by      TEXT NOT NULL,               -- User ID
    leader_id       TEXT,                         -- Agent ID of the leader
    max_iterations  INTEGER DEFAULT 50,          -- Max communication rounds
    current_iteration INTEGER DEFAULT 0,
    termination_reason TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    started_at      TIMESTAMP,
    completed_at    TIMESTAMP,
    config          JSONB DEFAULT '{}'            -- Session-specific configuration
);

-- Index for fast session listing
CREATE INDEX idx_sessions_created_by ON sessions(created_by, created_at DESC);
CREATE INDEX idx_sessions_status ON sessions(status);
CREATE INDEX idx_sessions_updated_at ON sessions(updated_at DESC);
```

#### 4.2.2 Agent Model

```sql
CREATE TABLE agents (
    id              TEXT PRIMARY KEY,           -- UUID
    session_id      TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,               -- e.g., "ChatGPT", "Gemini"
    type            TEXT NOT NULL,               -- 'chatgpt', 'gemini', 'deepseek'
    role            TEXT NOT NULL DEFAULT 'follower', -- 'leader', 'follower'
    web_url         TEXT NOT NULL,               -- URL of the AI web interface
    status          TEXT NOT NULL DEFAULT 'idle', -- 'idle', 'active', 'error', 'disconnected'
    is_connected    BOOLEAN DEFAULT FALSE,       -- Chrome connection status
    config          JSONB DEFAULT '{}',           -- Provider-specific config
    added_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_heartbeat  TIMESTAMP,
    message_count   INTEGER DEFAULT 0
);

CREATE INDEX idx_agents_session ON agents(session_id);
CREATE INDEX idx_agents_role ON agents(session_id, role);
```

#### 4.2.3 Message Model

```sql
CREATE TABLE messages (
    id              TEXT PRIMARY KEY,           -- UUID
    session_id      TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    agent_id        TEXT NOT NULL REFERENCES agents(id),
    role            TEXT NOT NULL,                -- 'user', 'assistant', 'system'
    content         TEXT NOT NULL,                -- Full message content
    content_type    TEXT DEFAULT 'text',          -- 'text', 'image', 'code', 'file'
    iteration       INTEGER NOT NULL,             -- Which round this was sent
    is_from_chrome  BOOLEAN DEFAULT FALSE,        -- Was this captured from Chrome?
    metadata        JSONB DEFAULT '{}',           -- Additional metadata
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_messages_session ON messages(session_id, created_at);
CREATE INDEX idx_messages_agent ON messages(agent_id, created_at);
CREATE INDEX idx_messages_iteration ON messages(session_id, iteration);
```

#### 4.2.4 Agent Configuration

```sql
CREATE TABLE agent_configs (
    id              TEXT PRIMARY KEY,
    agent_id        TEXT NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
    key             TEXT NOT NULL,
    value           TEXT NOT NULL,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### 4.3 Model Relationships Summary

| Relationship | Type | Description |
|-------------|------|-------------|
| Session → Agent | 1:N | One session has multiple agents |
| Session → Message | 1:N | One session has many messages |
| Agent → Message | 1:N | One agent sends many messages |
| Agent → AgentConfig | 1:N | One agent has multiple config entries |
| Agent → Config (agent_configs) | N:1 | Config entries belong to an agent |

### 4.4 JSONB Configuration Examples

**Agent Config Example:**
```json
{
    "chatgpt": {
        "model": "gpt-4o",
        "temperature": 0.7,
        "max_tokens": 4096,
        "system_prompt": "You are a research assistant..."
    },
    "gemini": {
        "model": "gemini-pro",
        "temperature": 0.5,
        "system_prompt": "You are a fact-checker..."
    }
}
```

**Session Config Example:**
```json
{
    "termination_rules": {
        "max_iterations": 50,
        "timeout_minutes": 60,
        "require_consensus": false
    },
    "display_settings": {
        "show_agent_avatars": true,
        "group_by_agent": true,
        "stream_responses": true
    }
}
```

---

## 5. API Design

### 5.1 API Base URL

```
Base URL: http://localhost:8000/api/v1
WebSocket: ws://localhost:8000/ws
```

### 5.2 Authentication

```yaml
# Simple API key authentication
# Stored in ~/.config/multi-ai-orchestrator/config.json
{
    "api_key": "sk-xxxxxxxxxxxxxxxxxxxxxxxx",
    "chrome_profile_path": "/home/user/.config/google-chrome",
    "port": 8000
}
```

Header for all REST requests:
```
Authorization: Bearer <api_key>
```

### 5.3 Session Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/sessions` | List all sessions (paginated) |
| `POST` | `/sessions` | Create a new session |
| `GET` | `/sessions/{id}` | Get session details |
| `PUT` | `/sessions/{id}` | Update session (name, config, etc.) |
| `DELETE` | `/sessions/{id}` | Delete a session |
| `POST` | `/sessions/{id}/start` | Start the orchestration loop |
| `POST` | `/sessions/{id}/stop` | Stop the orchestration loop |
| `GET` | `/sessions/{id}/messages` | Get all messages for a session |
| `GET` | `/sessions/{id}/status` | Get real-time session status |

**Create Session Request:**
```json
{
    "name": "Research Project: Quantum Computing",
    "description": "Exploring quantum algorithms with multiple AI agents",
    "leader_agent_type": "chatgpt",
    "follower_agent_types": ["gemini", "deepseek"],
    "max_iterations": 50,
    "agents": [
        {
            "name": "ChatGPT",
            "type": "chatgpt",
            "role": "leader",
            "web_url": "https://chatgpt.com",
            "config": { "model": "gpt-4o" }
        },
        {
            "name": "Gemini",
            "type": "gemini",
            "role": "follower",
            "web_url": "https://gemini.google.com",
            "config": { "model": "gemini-pro" }
        }
    ]
}
```

**Create Session Response:**
```json
{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Research Project: Quantum Computing",
    "status": "created",
    "created_at": "2026-09-28T10:00:00Z",
    "updated_at": "2026-09-28T10:00:00Z",
    "agents": [...],
    "leader_id": "agent-chatgpt-uuid"
}
```

### 5.4 Agent Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/agents` | List all agents |
| `POST` | `/agents` | Register a new agent |
| `GET` | `/agents/{id}` | Get agent details |
| `PUT` | `/agents/{id}` | Update agent configuration |
| `DELETE` | `/agents/{id}` | Remove an agent |
| `POST` | `/agents/{id}/connect` | Connect agent to Chrome |
| `POST` | `/agents/{id}/disconnect` | Disconnect agent from Chrome |
| `POST` | `/agents/{id}/set-leader` | Set agent as leader |
| `GET` | `/agents/{id}/status` | Get agent connection status |

### 5.5 Message Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/messages/{session_id}` | Get messages for a session |
| `GET` | `/messages/{session_id}/history` | Get full conversation history |
| `POST` | `/messages/{session_id}/send` | Send a message to an agent |
| `GET` | `/messages/{session_id}/stats` | Get message statistics |

**Send Message Request:**
```json
{
    "agent_id": "agent-chatgpt-uuid",
    "content": "Analyze the quantum entanglement paper",
    "role": "user"
}
```

### 5.6 WebSocket Events

**Client → Server Events:**
```typescript
// Send a message to an agent
{ type: "send_message", session_id: "...", agent_id: "...", content: "..." }

// Start orchestration
{ type: "start_loop", session_id: "..." }

// Stop orchestration
{ type: "stop_loop", session_id: "..." }

// Update agent config
{ type: "update_agent", session_id: "...", agent_id: "...", config: {...} }

// Heartbeat
{ type: "heartbeat", session_id: "..." }
```

**Server → Client Events:**
```typescript
// New message from an agent
{ type: "new_message", session_id: "...", message: {...} }

// Agent status change
{ type: "agent_status", session_id: "...", agent_id: "...", status: "active" }

// Loop iteration update
{ type: "iteration_update", session_id: "...", iteration: 5, current_agent: "..." }

// Session started
{ type: "session_started", session_id: "...", agents: [...] }

// Session completed
{ type: "session_completed", session_id: "...", reason: "max_iterations", summary: "..." }

// Error
{ type: "error", session_id: "...", code: "...", message: "..." }

// Chrome connection status
{ type: "chrome_status", session_id: "...", connected: true }
```

### 5.7 Health and System Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check |
| `GET` | `/chrome/status` | Chrome/Playwright connection status |
| `GET` | `/chrome/profiles` | List available Chrome profiles |
| `POST` | `/chrome/launch` | Launch Chrome |
| `POST` | `/chrome/stop` | Stop Chrome |

---

## 6. Communication Flow

### 6.1 Overview: How Agents Talk to Each Other

The core innovation of this system is that AI agents **communicate through the browser**, not through APIs. The orchestration engine uses Playwright to control Chrome, which reads from and writes to the web interfaces of ChatGPT, Gemini, and DeepSeek.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AGENT COMMUNICATION FLOW                          │
│                                                                      │
│  Phase 1: Initialization                                             │
│  ════════════════════                                                │
│  User creates session → Adds agents → Sets leader → Starts loop     │
│                                                                      │
│  Phase 2: First Message                                              │
│  ════════════════                                                    │
│  1. Orchestration engine picks leader agent                          │
│  2. Playwright navigates to ChatGPT                                  │
│  3. Types the user's initial prompt into ChatGPT                     │
│  4. Waits for ChatGPT response                                       │
│  5. Captures response from web page                                  │
│  6. Stores in SQLite → Pushes to Flutter via WS                      │
│                                                                      │
│  Phase 3: Agent Exchange Loop                                        │
│  ══════════════════════════════                                      │
│  7. Determine next agent (follower)                                  │
│  8. Navigate to that agent's web interface                           │
│  9. Reference previous response (copy-paste between tabs)            │
│  10. Type follow-up question                                        │
│  11. Capture response                                               │
│  12. Repeat from step 7                                             │
│                                                                      │
│  Phase 4: Termination                                                │
│  ═════════════════                                                   │
│  13. Check termination conditions                                     │
│  14. If terminated → Mark session complete → Notify Flutter         │
│  15. If not → Continue loop                                         │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.2 Detailed Message Exchange Sequence

```
Timeline: Iteration 0 → 1 → 2 → 3 → ... → N

Iteration 0:
  Leader (ChatGPT):  [User Prompt] → ChatGPT → Response A
  
Iteration 1:
  Follower (Gemini): [Reference Response A] → Gemini → Response B
  
Iteration 2:
  Follower (DeepSeek): [Reference Response A, B] → DeepSeek → Response C
  
Iteration 3:
  Leader (ChatGPT):  [Reference A, B, C] → ChatGPT → Response D
  
Iteration 4:
  Follower (Gemini): [Reference A, B, C, D] → Gemini → Response E
  
  ... (continues until termination)

Termination:
  All agents have responded to iteration 45
  Termination checker finds consensus → Stop loop
  Session marked as "completed"
  Summary generated
```

### 6.3 Message Routing Logic

```python
class MessageRouter:
    def get_next_speaker(self, session: Session, iteration: int) -> Agent:
        """
        Determine which agent speaks next.
        
        Strategy:
        - Leader speaks on even iterations (0, 2, 4, ...)
        - Followers speak on odd iterations (1, 3, 5, ...)
        - Round-robin among followers
        - Leader always speaks first and last
        """
        agents = session.get_agents_ordered()
        leader = session.get_leader()
        followers = session.get_followers()
        
        if iteration == 0:
            return leader
        
        if iteration % 2 == 0:
            return leader
        
        # Round-robin among followers
        follower_index = (iteration - 1) // 2 % len(followers)
        return followers[follower_index]
    
    def build_context(self, session: Session, agent: Agent, iteration: int) -> str:
        """
        Build the context message for an agent.
        Includes all previous messages so agents can reference them.
        """
        previous_messages = message_store.get_messages(session.id, up_to=iteration)
        
        context_parts = []
        for msg in previous_messages:
            if msg.agent_id != agent.id or msg.role == "system":
                context_parts.append(f"{msg.role}: {msg.content}")
            else:
                # Include all previous agents' messages for cross-reference
                for prev_msg in previous_messages:
                    context_parts.append(f"[{prev_msg.agent.name}] {prev_msg.role}: {prev_msg.content}")
        
        return "\n\n".join(context_parts)
```

### 6.4 Context Propagation Between Agents

The key challenge is ensuring each agent can see previous responses. The system uses two strategies:

1. **Reference Injection**: When sending a message to an agent, the orchestration engine includes references to previous responses:
   ```
   "Previous analysis from ChatGPT: [Response A]
    Gemini's response: [Response B]
    
    Please build on this analysis..."
   ```

2. **Chat History Copy**: For web-based agents, the Playwright controller navigates to the agent's page and the context is typed into the chat input, effectively copying previous discussion into each new prompt.

### 6.5 Concurrent Agent Communication (Advanced)

For future enhancement, the system supports sending messages to multiple agents simultaneously:

```python
async def parallel_communication(session: Session, messages: Dict[str, str]):
    """Send messages to multiple agents concurrently"""
    tasks = []
    for agent_id, content in messages.items():
        task = chrome_controller.execute_message(agent_id, content)
        tasks.append(task)
    
    responses = await asyncio.gather(*tasks, return_exceptions=True)
    
    # Collect and store all responses
    for agent_id, response in zip(messages.keys(), responses):
        await message_store.save(session.id, agent_id, response)
```

### 6.6 Communication Loop State Machine

```
                    ┌─────────────┐
                    │   IDLE      │
                    │ (Waiting    │
                    │  for start) │
                    └──────┬──────┘
                           │ User starts session
                           ▼
                    ┌─────────────┐
                    │   INITIALIZE│
                    │ (Setup      │
                    │  Chrome)    │
                    └──────┬──────┘
                           │ Chrome launched
                           ▼
                    ┌─────────────┐
                    │   FIRST_MSG │
                    │ (Leader     │
                    │  speaks)    │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ TERMINATE│ │ CONTINUE │ │ ERROR    │
        │(Stop loop│ │(Next     │ │(Retry/   │
        │ Session) │ │ Agent)   │ │ Escalate)│
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │            │            │
             │            ▼            │
             │     ┌──────────────┐    │
             │     │ NEXT_ITER    │    │
             │     │ (Follower   │    │
             │     │  speaks)     │    │
             │     └──────┬───────┘    │
             │            │            │
             │            └────────────┘
             │
             ▼
     ┌─────────────┐
     │ COMPLETED   │
     │ (Generate   │
     │  Summary,   │
     │  Save to    │
     │  History)   │
     └─────────────┘
```

---

## 7. Chrome Browser Integration Plan

### 7.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Chrome Integration Layer               │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐ │
│  │            Playwright Controller                      │ │
│  │                                                       │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │ │
│  │  │ Browser      │  │ Page        │  │ Context     │  │ │
│  │  │ Manager      │  │ Navigator   │  │ Manager     │  │ │
│  │  │              │  │             │  │             │  │ │
│  │  │ • Launch     │  │ • Navigate  │  │ • Isolate   │  │ │
│  │  │ • Connect    │  │ • Reload    │  │   sessions  │  │ │
│  │  │ • Screenshot │  │ • Scroll    │  │ • Cookies   │  │ │
│  │  │ • Close      │  │ • Wait      │  │ • Storage   │  │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐ │
│  │            Chrome Profile Strategy                    │ │
│  │                                                       │ │
│  │  User Profile: ~/.config/google-chrome               │ │
│  │  ├── Default profile (with AI site logins)           │ │
│  │  ├── Extension: Multi-AI Orchestrator                │ │
│  │  └── Saved passwords for ChatGPT/Gemini/DeepSeek    │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### 7.2 Chrome Profile Setup

#### 7.2.1 Profile Discovery

```bash
# Check for existing Chrome profiles
ls ~/.config/google-chrome/Default/
ls ~/Library/Application Support/Google/Chrome/  # macOS fallback

# Common profile locations on Ubuntu
~/.config/google-chrome/Default/
~/.config/chromium/Default/
```

#### 7.2.2 Profile Configuration

```python
class ChromeProfileManager:
    def find_profiles(self) -> List[ChromeProfile]:
        """Find all Chrome profiles on the system"""
        profiles = []
        
        # Check standard locations
        locations = [
            Path.home() / ".config/google-chrome",
            Path.home() / ".config/chromium",
        ]
        
        for location in locations:
            if location.exists():
                for profile_dir in location.iterdir():
                    if profile_dir.is_dir():
                        profiles.append(ChromeProfile(
                            name=profile_dir.name,
                            path=str(location / profile_dir),
                            is_default=(profile_dir.name == "Default")
                        ))
        
        return profiles
    
    def launch_with_profile(self, profile_path: str, headless: bool = False) -> Browser:
        """Launch Chrome with specified user profile"""
        from playwright.sync_api import sync_playwright
        
        playwright = sync_playwright().start()
        browser = playwright.chromium.launch(
            headless=headless,
            args=[
                f"--user-data-dir={profile_path}",
                "--no-sandbox",
                "--disable-dev-shm-usage",
                "--disable-gpu",
                "--enable-features=BrowserSignin",
                "--enable-benchmarking-mode",
            ]
        )
        return browser
```

### 7.3 Page Interaction Strategy

#### 7.3.1 ChatGPT Interaction

```python
class ChatGPTController:
    URL = "https://chatgpt.com"
    
    async def navigate_to_chat(self, page):
        """Navigate to ChatGPT and wait for chat interface"""
        await page.goto(self.URL, wait_until="networkidle")
        await page.wait_for_selector("[data-testid='chat-input']", timeout=15000)
    
    async def send_message(self, page, message: str) -> str:
        """Type a message and send it"""
        chat_input = await page.wait_for_selector("[data-testid='chat-input']")
        await chat_input.fill(message)
        
        # Press Enter to send
        await chat_input.press("Enter")
        
        # Wait for response
        await page.wait_for_selector("[data-testid='message-content']", timeout=60000)
        
        # Extract the latest response
        messages = await page.query_selector_all("[data-testid='message-content']")
        latest_message = messages[-1]
        return await latest_message.inner_text()
    
    async def get_conversation_history(self, page) -> List[dict]:
        """Extract all messages from the conversation"""
        messages = await page.query_selector_all("[data-testid='message-content']")
        return [{"role": m.get_attribute("data-role"), "content": await m.inner_text()} 
                for m in messages]
```

#### 7.3.2 Gemini Interaction

```python
class GeminiController:
    URL = "https://gemini.google.com/app"
    
    async def navigate_to_chat(self, page):
        await page.goto(self.URL, wait_until="networkidle")
        await page.wait_for_selector("[aria-label='Ask something']", timeout=15000)
    
    async def send_message(self, page, message: str) -> str:
        input_field = await page.wait_for_selector("[aria-label='Ask something']")
        await input_field.fill(message)
        await input_field.press("Enter")
        
        # Wait for Gemini response
        await page.wait_for_selector(".response-content", timeout=60000)
        
        # Extract response
        response_el = await page.wait_for_selector(".response-content")
        return await response_el.inner_text()
```

#### 7.3.3 DeepSeek Interaction

```python
class DeepSeekController:
    URL = "https://deepseek.com"
    
    async def navigate_to_chat(self, page):
        await page.goto(self.URL, wait_until="networkidle")
        await page.wait_for_selector("[placeholder='Send a message']", timeout=15000)
    
    async def send_message(self, page, message: str) -> str:
        input_field = await page.wait_for_selector("[placeholder='Send a message']")
        await input_field.fill(message)
        await input_field.press("Enter")
        
        await page.wait_for_selector(".thinking-result", timeout=60000)
        response_el = await page.wait_for_selector(".markdown-text")
        return await response_el.inner_text()
```

### 7.4 Multi-Tab Strategy

```
Chrome Window
├── Tab 1: ChatGPT    (Leader)
├── Tab 2: Gemini     (Follower 1)
├── Tab 3: DeepSeek   (Follower 2)
└── Tab 4: Monitoring (Orchestrator console)
```

Each agent gets its own browser tab/context. The orchestration engine switches between tabs to send messages and read responses.

```python
class MultiTabManager:
    def __init__(self, browser):
        self.browser = browser
        self.tabs: Dict[str, Page] = {}  # agent_id → page
    
    async def setup_agent_tabs(self, agents: List[Agent]):
        """Open a tab for each agent"""
        for agent in agents:
            page = await self.browser.new_page()
            await page.goto(agent.web_url)
            self.tabs[agent.id] = page
    
    async def switch_to_agent(self, agent_id: str) -> Page:
        """Switch focus to a specific agent's tab"""
        page = self.tabs[agent_id]
        await page.bring_to_front()
        return page
    
    async def close_agent_tab(self, agent_id: str):
        """Close a specific agent's tab"""
        if agent_id in self.tabs:
            await self.tabs[agent_id].close()
            del self.tabs[agent_id]
```

### 7.5 Authentication Handling

```python
class AuthManager:
    def __init__(self, chrome_profile_path: str):
        self.profile_path = chrome_profile_path
    
    def verify_authentication(self, page, agent_type: str) -> bool:
        """Check if user is logged into the AI service"""
        if agent_type == "chatgpt":
            # Check for user avatar or profile indicator
            return page.query_selector("[data-testid='user-avatar']") is not None
        elif agent_type == "gemini":
            return page.query_selector("[aria-label='Profile']") is not None
        return False
    
    def handle_unauthenticated(self, page, agent_type: str):
        """If not logged in, prompt user or show login instructions"""
        # Open the login page in a visible Chrome window
        # Let user manually authenticate
        # After authentication, save cookies for future sessions
        pass
    
    def save_session_cookies(self, browser, session_id: str):
        """Save cookies for persistent authentication"""
        cookies = browser.contexts[0].cookies()
        cookie_storage.save(session_id, cookies)
```

### 7.6 Error Handling and Recovery

```python
class ChromeErrorHandler:
    async def handle_page_error(self, page, agent_id: str):
        """Handle common Chrome/Playwright errors"""
        try:
            # Check if page needs reload
            if await page.evaluate("document.readyState") != "complete":
                await page.reload()
                await page.wait_for_load_state("networkidle")
            
            # Check for CAPTCHA
            if "captcha" in await page.title().lower():
                raise CAPTCHADetectedError("CAPTCHA detected, user intervention required")
            
            # Check for session expiry
            if await self.is_session_expired(page):
                await self.reauthenticate(page, agent_id)
                
        except Exception as e:
            await self.recover_from_error(page, agent_id, e)
    
    async def recover_from_error(self, page, agent_id: str, error: Exception):
        """Attempt to recover from any error"""
        retry_count = 0
        while retry_count < 3:
            try:
                await page.reload()
                await page.wait_for_load_state("networkidle")
                return True
            except:
                retry_count += 1
                await asyncio.sleep(2 ** retry_count)  # Exponential backoff
        
        raise MaxRetriesExceededError(f"Failed to recover agent {agent_id}")
```

---

## 8. Session Management Design

### 8.1 Session Lifecycle

```
                    ┌──────────────┐
                    │   CREATED    │
                    │ (Initial     │
                    │  state)      │
                    └──────┬───────┘
                           │ User configures agents
                           ▼
                    ┌──────────────┐
                    │   CONFIGURED │
                    │ (Agents      │
                    │  added,      │
                    │  leader set) │
                    └──────┬───────┘
                           │ User clicks "Start"
                           ▼
                    ┌──────────────┐
                    │   RUNNING    │
                    │ (Orchestration│
                    │  Loop Active)│
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ COMPLETE │ │ STOPPED  │ │ ERROR    │
        │(Solved)  │ │(User     │ │(Error    │
        │ Summary  │ │ stopped) │ │ handled) │
        └──────────┘ └──────────┘ └──────────┘
              │            │
              │            ▼
              │     ┌──────────┐
              │     │ ARCHIVED │
              │     │(Preserve │
              │     │ history, │
              │     │ no loop) │
              │     └──────────┘
              │
              ▼
        ┌──────────┐
        │  DELETED │
        │(Removed  │
        │  from    │
        │  storage)│
        └──────────┘
```

### 8.2 Session State Management

```python
class SessionState(Enum):
    CREATED = "created"
    CONFIGURED = "configured"
    RUNNING = "running"
    PAUSED = "paused"
    COMPLETED = "completed"
    STOPPED = "stopped"
    ERROR = "error"
    ARCHIVED = "archived"
    DELETED = "deleted"

class SessionManager:
    def create(self, name: str, description: str, created_by: str) -> Session:
        """Create a new session in CREATED state"""
        session = Session(
            id=str(uuid4()),
            name=name,
            description=description,
            status=SessionState.CREATED,
            created_by=created_by
        )
        db.save(session)
        return session
    
    def configure_agents(self, session_id: str, agents: List[AgentConfig]) -> Session:
        """Add agents to a session, transition to CONFIGURED"""
        session = self.get(session_id)
        if session.status != SessionState.CREATED:
            raise InvalidStateError("Can only add agents to CREATED sessions")
        
        for config in agents:
            agent = Agent(
                id=str(uuid4()),
                session_id=session_id,
                **config
            )
            db.save(agent)
            session.agents.append(agent)
        
        session.status = SessionState.CONFIGURED
        session.updated_at = datetime.now()
        db.save(session)
        return session
    
    def start(self, session_id: str) -> Session:
        """Start the orchestration loop"""
        session = self.get(session_id)
        if session.status != SessionState.CONFIGURED:
            raise InvalidStateError("Can only start CONFIGURED sessions")
        
        session.status = SessionState.RUNNING
        session.started_at = datetime.now()
        db.save(session)
        
        # Start the orchestration loop in background
        asyncio.create_task(orchestration_engine.run(session_id))
        return session
    
    def stop(self, session_id: str) -> Session:
        """Stop the orchestration loop"""
        session = self.get(session_id)
        if session.status != SessionState.RUNNING:
            raise InvalidStateError("Can only stop RUNNING sessions")
        
        session.status = SessionState.STOPPED
        session.completed_at = datetime.now()
        db.save(session)
        return session
    
    def archive(self, session_id: str) -> Session:
        """Archive session (preserve history)"""
        session = self.get(session_id)
        session.status = SessionState.ARCHIVED
        db.save(session)
        return session
    
    def delete(self, session_id: str):
        """Permanently delete session and all data"""
        # Delete messages (CASCADE)
        db.execute("DELETE FROM messages WHERE session_id = ?", (session_id,))
        # Delete agents (CASCADE)
        db.execute("DELETE FROM agents WHERE session_id = ?", (session_id,))
        # Delete session
        db.execute("DELETE FROM sessions WHERE id = ?", (session_id,))
```

### 8.3 Session List Management

The Flutter frontend displays sessions in a scrollable list with the following features:

| Feature | Implementation |
|---------|---------------|
| **Create** | Floating action button → Create session dialog |
| **Edit** | Tap on session card → Edit name/description |
| **Delete** | Swipe left on session card → Confirm delete |
| **Start** | Tap → Start orchestration → Navigate to chat |
| **Filter** | By status (active, completed, archived) |
| **Sort** | By date, name, status |
| **Search** | Search by session name |

### 8.4 Session Data Persistence

```python
# SQLite database configuration
DATABASE_CONFIG = {
    "url": "sqlite:///~/.config/multi-ai-orchestrator/sessions.db",
    "connect_args": {"check_same_thread": False},
    "pool_size": 5,
    "echo": False,  # Set True for debugging
}

# Database initialization
def init_db():
    """Initialize the database with all tables"""
    Base.metadata.create_all(bind=engine)
    
    # Create indexes
    create_indexes()
    
    # Initialize default configuration
    initialize_default_config()

# Auto-migration with Alembic
# alembic revision --autogenerate -m "Add new tables"
# alembic upgrade head
```

### 8.5 Session Backup and Export

```python
class SessionExporter:
    def export_session(self, session_id: str, format: str = "json"):
        """Export session data for backup or sharing"""
        session = self.get(session_id)
        messages = self.message_store.get_all(session_id)
        agents = self.agent_registry.get_all(session_id)
        
        data = {
            "session": session.to_dict(),
            "agents": [a.to_dict() for a in agents],
            "messages": [m.to_dict() for m in messages],
            "exported_at": datetime.now().isoformat()
        }
        
        if format == "json":
            return json.dumps(data, indent=2)
        elif format == "markdown":
            return self._to_markdown(data)
```

---

## 9. Tech Stack Justification

### 9.1 Flutter for Desktop

| Criterion | Flutter | Tauri | Verdict |
|-----------|---------|-------|---------|
| **Cross-platform** | ✅ Linux, macOS, Windows, Mobile | ✅ Linux, macOS, Windows | Flutter wins (mobile support) |
| **Performance** | ✅ Skia rendering, 60fps | ⚠️ WebView-based | Flutter wins |
| **UI flexibility** | ✅ Full custom rendering | ⚠️ Limited by WebView | Flutter wins |
| **AppImage support** | ✅ `flutter build linux` + `linuxdeploy` | ✅ AppImage via `tauri build` | Both work |
| **Package size** | ⚠️ ~50-100MB | ✅ ~20-50MB | Tauri wins |
| **Development speed** | ✅ Hot reload, Dart | ⚠️ Rust + web frontend | Flutter wins |
| **Community** | ✅ Massive | ⚠️ Growing | Flutter wins |
| **WebSocket support** | ✅ `web_socket_channel` | ✅ via Tauri APIs | Both work |
| **Desktop menu bar** | ✅ Native | ✅ Native | Both work |
| **System tray** | ✅ `tray_manager` package | ✅ Tauri tray API | Both work |
| **File system access** | ✅ `path_provider` | ✅ `tauri fs` | Both work |
| **Auto-update** | ✅ `auto_updater` package | ✅ Tauri updater | Both work |

**Decision: Flutter** — Despite larger package size, Flutter provides superior cross-platform support (including future mobile), better UI flexibility, faster development cycle, and a larger community. The user explicitly requested Flutter.

### 9.2 FastAPI for Backend

| Criterion | FastAPI | Flask | Django |
|-----------|---------|-------|--------|
| **Async support** | ✅ Native async/await | ⚠️ Limited | ⚠️ ASGI support |
| **Performance** | ✅ High (Starlette) | ⚠️ Lower | ⚠️ Moderate |
| **WebSocket** | ✅ Built-in | ⚠️ Flask-SocketIO | ⚠️ Django Channels |
| **Type safety** | ✅ Pydantic models | ❌ No | ⚠️ Optional |
| **Auto docs** | ✅ OpenAPI/Swagger | ⚠️ Flask-Swagger | ⚠️ Django REST |
| **Learning curve** | ⚠️ Moderate | ✅ Low | ⚠️ High |
| **Lightweight** | ✅ Minimal deps | ✅ Minimal | ❌ Heavy |

**Decision: FastAPI** — Native async support is critical for the WebSocket communication loop. Pydantic models provide type safety for all data schemas. OpenAPI docs help with debugging and future API extensions.

### 9.3 SQLite for Database

| Criterion | SQLite | PostgreSQL | Redis |
|-----------|--------|------------|-------|
| **Local storage** | ✅ Perfect fit | ❌ Requires server | ❌ Not for persistence |
| **Setup complexity** | ✅ Zero config | ❌ Server setup | ❌ Server setup |
| **Performance** | ✅ Excellent for local | ✅ Excellent | ✅ Fast |
| **Concurrency** | ⚠️ Limited | ✅ High | ✅ High |
| **Reliability** | ✅ ACID compliant | ✅ ACID compliant | ⚠️ Eventually consistent |
| **Backup** | ✅ Single file copy | ✅ pg_dump | ⚠️ RDB/AOF |
| **AppImage compatible** | ✅ Embedded in AppImage | ❌ Needs server | ❌ Needs server |
| **Future scaling** | ⚠️ Single machine | ✅ Distributed | ✅ Distributed |

**Decision: SQLite** — For a local desktop application, SQLite is the obvious choice. No server required, single file database, ACID compliant, excellent performance for local use. If the user ever wants multi-device sync, we can migrate to PostgreSQL later without changing the ORM layer.

### 9.4 Playwright for Chrome Control

| Criterion | Playwright | Selenium | Puppeteer |
|-----------|-----------|----------|-----------|
| **Python support** | ✅ Official | ✅ | ❌ Node.js only |
| **Browser support** | ✅ Chromium, Firefox, WebKit | ✅ All | ⚠️ Chrome only |
| **Auto-wait** | ✅ Built-in | ❌ Manual | ⚠️ Partial |
| **Speed** | ✅ Fast | ⚠️ Slow | ✅ Fast |
| **MCP server** | ✅ Already configured | ❌ No | ❌ No |
| **Modern approach** | ✅ Recommended | ⚠️ Legacy | ⚠️ Chrome only |

**Decision: Playwright** — Already configured in the MCP environment. Native Python support. Auto-wait strategies reduce flaky tests. Already part of the existing infrastructure.

### 9.5 WebSocket for Real-Time Communication

| Criterion | WebSocket | REST Polling | Server-Sent Events |
|-----------|-----------|-------------|-------------------|
| **Bidirectional** | ✅ Full duplex | ❌ Request-response | ❌ Server→client only |
| **Latency** | ✅ Near real-time | ⚠️ Polling delay | ✅ Real-time |
| **Overhead** | ✅ Low after handshake | ❌ HTTP headers each poll | ✅ Low |
| **Complexity** | ⚠️ Connection management | ✅ Simple | ✅ Simple |
| **Flutter support** | ✅ `web_socket_channel` | ✅ `http` package | ✅ `sse` package |
| **FastAPI support** | ✅ Native | ✅ Built-in | ⚠️ Requires extensions |

**Decision: WebSocket** — Essential for real-time chat experience. Bidirectional communication needed for both sending messages and receiving agent responses. FastAPI has excellent WebSocket support.

### 9.6 Riverpod for Flutter State Management

| Criterion | Riverpod | BLoC | Provider | GetX |
|-----------|----------|------|----------|------|
| **Type safety** | ✅ Compile-time | ⚠️ Runtime | ⚠️ Runtime | ❌ No |
| **Boilerplate** | ✅ Low | ❌ High | ✅ Low | ✅ Very low |
| **Testability** | ✅ Excellent | ✅ Good | ⚠️ Moderate | ❌ Poor |
| **Learning curve** | ⚠️ Moderate | ⚠️ High | ✅ Low | ✅ Low |
| **Flutter team rec** | ✅ Recommended | ✅ Recommended | ⚠️ Legacy | ❌ Not recommended |
| **Async support** | ✅ Built-in | ✅ Stream-based | ⚠️ Manual | ⚠️ Manual |

**Decision: Riverpod** — Recommended by Flutter team. Excellent type safety. Good for complex state management in a chat application. Built-in async support for WebSocket streams.

---

## 10. Implementation Plan

### 10.1 Phase Overview

```
Phase 1: Foundation     ████████████████████  (Weeks 1-2)
Phase 2: Backend Core   ████████████████████  (Weeks 3-4)
Phase 3: Chrome Integration ██████████████    (Weeks 5-6)
Phase 4: Flutter UI     ████████████████████  (Weeks 7-9)
Phase 5: Orchestration  ██████████            (Weeks 10-11)
Phase 6: Polish & Build ████████              (Weeks 12-13)
Phase 7: Testing & Fix  ████                  (Week 14)
```

### 10.2 Phase 1: Foundation (Weeks 1-2)

**Goal**: Set up the project structure, development environment, and basic infrastructure.

| Task | Deliverable | Effort |
|------|-------------|--------|
| Initialize project structure | `story-app/` directory with subdirs | 1 day |
| Set up Python/FastAPI backend | `requirements.txt`, `main.py`, `config.py` | 2 days |
| Set up SQLite database | `database/models.py`, `database/__init__.py` | 1 day |
| Set up Flutter desktop project | `flutter create`, Linux build config | 1 day |
| Configure Playwright | `playwright.config.ts`, install deps | 1 day |
| Set up WebSocket infrastructure | Basic WebSocket server in FastAPI | 2 days |
| Create CI/CD pipeline | GitHub Actions for build/test | 1 day |
| Create AppImage build scripts | `tools/build_appimage.sh` | 1 day |

**Milestone**: `make setup` works, both backend and Flutter start, WebSocket connection established.

### 10.3 Phase 2: Backend Core (Weeks 3-4)

**Goal**: Complete the REST API and database layer.

| Task | Deliverable | Effort |
|------|-------------|--------|
| Session CRUD endpoints | `api/sessions.py` — full CRUD | 3 days |
| Agent management endpoints | `api/agents.py` — register, configure, remove | 2 days |
| Message CRUD endpoints | `api/messages.py` — store and retrieve | 2 days |
| Pydantic models | `models/session.py`, `models/agent.py`, `models/message.py` | 2 days |
| Database repository layer | `database/repository.py` — all queries | 2 days |
| Alembic migrations | Initial migration script | 1 day |
| Session state machine | `services/session_manager.py` | 2 days |
| WebSocket handlers | `api/websocket.py` — connection management | 2 days |
| API testing | `tests/test_api.py` — full test coverage | 3 days |

**Milestone**: All CRUD endpoints working, SQLite database operational, WebSocket connections functional.

### 10.4 Phase 3: Chrome Integration (Weeks 5-6)

**Goal**: Implement Playwright-based Chrome control for interacting with AI web interfaces.

| Task | Deliverable | Effort |
|------|-------------|--------|
| Chrome profile detection | `services/chrome_controller.py` — profile discovery | 2 days |
| Browser launch/connect | `services/chrome_controller.py` — launch/connect | 2 days |
| ChatGPT page interaction | `services/controllers/chatgpt_controller.py` | 2 days |
| Gemini page interaction | `services/controllers/gemini_controller.py` | 2 days |
| DeepSeek page interaction | `services/controllers/deepseek_controller.py` | 2 days |
| Multi-tab management | `services/tab_manager.py` | 1 day |
| Authentication handling | `services/auth_manager.py` | 2 days |
| Error handling & recovery | `services/error_handler.py` | 1 day |
| Chrome integration testing | `tests/test_chrome.py` | 2 days |
| Chrome status API | `api/chrome.py` — `/chrome/status`, `/chrome/launch` | 1 day |

**Milestone**: Chrome launches with user profile, agents can be connected, messages can be sent and received from web interfaces.

### 10.5 Phase 4: Flutter UI (Weeks 7-9)

**Goal**: Build the complete Flutter desktop interface.

| Task | Deliverable | Effort |
|------|-------------|--------|
| Project setup with Riverpod | `pubspec.yaml`, `main.dart`, `app.dart` | 2 days |
| Session list screen | `screens/session_list_screen.dart` | 2 days |
| Create/edit session dialog | `widgets/session_dialog.dart` | 1 day |
| Chat interface | `screens/chat_screen.dart` | 3 days |
| Message bubbles | `widgets/message_bubble.dart` | 2 days |
| Multi-agent chat view | `widgets/agent_chat_view.dart` | 2 days |
| Agent configuration panel | `screens/agent_config_screen.dart` | 3 days |
| WebSocket service | `services/websocket_service.dart` | 2 days |
| API client service | `services/api_client.dart` | 1 day |
| Chrome manager widget | `services/chrome_manager.dart` | 1 day |
| App theming | `theme/app_theme.dart` | 1 day |
| System tray integration | `services/system_tray.dart` | 1 day |
| Flutter testing | `tests/test_*.dart` | 2 days |

**Milestone**: Full desktop UI working — sessions can be created, chats display, agents can be configured.

### 10.6 Phase 5: Orchestration Engine (Weeks 10-11)

**Goal**: Implement the core agent communication loop and coordination logic.

| Task | Deliverable | Effort |
|------|-------------|--------|
| Orchestration engine | `services/orchestration_engine.py` | 3 days |
| Leader election manager | `services/leader_election.py` | 2 days |
| Message router | `services/message_router.py` | 2 days |
| Termination checker | `services/termination_checker.py` | 2 days |
| Communication loop worker | `workers/agent_loop_worker.py` | 2 days |
| Context propagation logic | `services/context_builder.py` | 1 day |
| Loop state machine | `services/loop_state_machine.py` | 1 day |
| WebSocket event broadcasting | `api/websocket.py` — event types | 1 day |
| Integration testing | `tests/test_orchestration.py` | 2 days |
| Performance optimization | Connection pooling, message batching | 1 day |

**Milestone**: Agents communicate autonomously through Chrome, with leader coordinating the conversation loop.

### 10.7 Phase 6: Polish & Build (Weeks 12-13)

**Goal**: Prepare for production AppImage build.

| Task | Deliverable | Effort |
|------|-------------|--------|
| AppImage build configuration | `tools/build_appimage.sh` | 2 days |
| Linux desktop entry | `story-app.desktop` | 1 day |
| App icon and branding | `assets/icon.png`, splash screen | 1 day |
| Auto-update configuration | `tools/auto_update.sh` | 1 day |
| Error logging | `services/logger.py` | 1 day |
| Configuration management | `config/app_config.py` | 1 day |
| Performance profiling | Identify bottlenecks, optimize | 2 days |
| Documentation update | README, setup guides | 1 day |
| AppImage packaging | Final AppImage build | 1 day |
| Linux-specific testing | Test on clean Ubuntu environment | 1 day |

**Milestone**: Working AppImage that can be installed and run on Ubuntu Linux.

### 10.8 Phase 7: Testing & Fix (Week 14)

**Goal**: Comprehensive testing and bug fixes.

| Task | Deliverable | Effort |
|------|-------------|--------|
| End-to-end testing | Full workflow from start to finish | 2 days |
| Edge case testing | Network failures, agent errors, timeouts | 1 day |
| Performance testing | Multiple agents, long conversations | 1 day |
| Security review | Input validation, XSS prevention | 1 day |
| User acceptance testing | Real users test the application | 1 day |
| Bug fixes | Address all reported issues | 1 day |
| Final AppImage build | Production-ready build | 1 day |

**Milestone**: Production-ready AppImage delivered.

### 10.9 Detailed Sprint Schedule

```
Week  1  2  3  4  5  6  7  8  9  10 11 12 13 14
      ╠══╣                                            Phase 1: Foundation
              ╠══╣                                      Phase 2: Backend Core
                    ╠══╣                                Phase 3: Chrome Integration
                          ╠══╣                          Phase 4: Flutter UI
                                ╠══╣                    Phase 5: Orchestration
                                      ╠══╣              Phase 6: Polish & Build
                                            ╠══╣        Phase 7: Testing & Fix
```

### 10.10 Key Metrics and Success Criteria

| Metric | Target |
|--------|--------|
| Backend API response time | < 100ms |
| WebSocket latency | < 50ms |
| Chrome launch time | < 5 seconds |
| Agent message round-trip | < 10 seconds |
| AppImage size | < 200MB |
| Session creation time | < 1 second |
| Memory usage (idle) | < 200MB |
| Memory usage (active) | < 500MB |
| Test coverage | > 80% |
| Bug count (post-release) | < 5 critical |

---

## 11. Risks and Mitigations

### 11.1 Risk Matrix

| # | Risk | Probability | Impact | Mitigation |
|---|------|-------------|--------|------------|
| 1 | **Chrome website DOM changes** break selectors | 🔴 High | 🔴 Critical | Implement robust selectors with multiple fallbacks; monitor site changes; add retry logic; abstract controllers behind interfaces |
| 2 | **Authentication expiration** during sessions | 🟡 Medium | 🔴 High | Implement heartbeat checks; auto-reauthentication flow; notify user to re-login; save/restore cookies |
| 3 | **Playwright stability issues** with Chrome | 🟡 Medium | 🟡 Medium | Use stable Chrome versions; implement comprehensive error handling; maintain browser restart mechanism |
| 4 | **WebSocket connection drops** | 🟡 Medium | 🟡 Medium | Auto-reconnect logic; message queue for offline; session state persistence; conflict resolution on reconnect |
| 5 | **AppImage size too large** | 🟡 Medium | 🟡 Low | Tree-shaking; lazy loading; compress assets; split optional components |
| 6 | **Agent communication loop hangs** | 🟡 Medium | 🔴 High | Max iteration limits; timeout per message; user stop button; heartbeat monitoring; circuit breaker pattern |
| 7 | **Memory leaks** with long conversations | 🟡 Medium | 🟡 Medium | Message pagination; periodic cleanup; memory profiling; limit max messages per session |
| 8 | **Multiple Chrome profiles** conflict | 🔴 High | 🟡 Medium | Isolate browser contexts per session; use separate Chrome data dirs; validate profile paths |
| 9 | **Performance degradation** with many agents | 🟢 Low | 🟡 Medium | Connection pooling; async execution; message batching; load testing at scale |
| 10 | **Security vulnerability** in local server | 🟢 Low | 🔴 High | Bind to localhost only; API key authentication; input validation; CORS restrictions; HTTPS option |
| 11 | **AI API rate limits** exceeded | 🟡 Medium | 🟡 Medium | Implement rate limiting; queue management; user notification; configurable delays between messages |
| 12 | **Data loss** from crashes | 🟢 Low | 🔴 High | Write-ahead logging; atomic database operations; auto-save every message; backup on session end |

### 11.2 Detailed Risk Analysis

#### Risk 1: Chrome Website DOM Changes (Highest Priority)

**Description**: ChatGPT, Gemini, and DeepSeek frequently update their web interfaces. CSS selectors and DOM structures change, breaking the Playwright automation scripts.

**Mitigation Strategy**:
1. **Multi-selector fallback**: Always have 2-3 alternative selectors for each element
   ```python
   SELECTORS = {
       "chatgpt_input": [
           "[data-testid='chat-input']",
           "textarea[aria-label='Message ChatGPT']",
           "#prompt-textarea",
       ],
       "gemini_input": [
           "[aria-label='Ask something']",
           "textarea[placeholder='Ask anything']",
           ".gemini-input",
       ]
   }
   ```
2. **Visual regression testing**: Take screenshots and compare against baselines
3. **Controller abstraction**: If one agent's controller breaks, others should still work
4. **Monitoring**: Weekly automated tests against live sites
5. **User notification**: Alert users when a site update is detected

#### Risk 2: Authentication Expiration

**Description**: User login sessions to AI websites expire during long orchestration loops, requiring re-authentication.

**Mitigation Strategy**:
1. **Cookie persistence**: Save and restore cookies between sessions
2. **Heartbeat monitoring**: Periodically check if agents are still authenticated
3. **Graceful degradation**: If auth expires, pause the loop and notify user
4. **Persistent Chrome profile**: Use user's existing Chrome profile which maintains login state
5. **Re-auth flow**: Open Chrome window for user to manually re-authenticate

#### Risk 6: Communication Loop Hangs

**Description**: An agent might not respond, causing the entire orchestration loop to hang indefinitely.

**Mitigation Strategy**:
1. **Hard timeout**: Each message has a maximum wait time (default: 60 seconds)
2. **Max iterations**: Configurable limit (default: 50)
3. **User stop**: User can always stop the session
4. **Circuit breaker**: After N consecutive failures, stop the loop and alert user
5. **Dead man's switch**: If no progress for N iterations, terminate automatically

```python
class CommunicationLoopGuard:
    def __init__(self, max_message_time=60, max_consecutive_errors=5, max_iterations=50):
        self.max_message_time = max_message_time
        self.max_consecutive_errors = max_consecutive_errors
        self.max_iterations = max_iterations
        self.consecutive_errors = 0
        self.last_progress_time = time.time()
    
    def check_message_timeout(self, start_time: float) -> bool:
        """Check if a message is taking too long"""
        return (time.time() - start_time) > self.max_message_time
    
    def check_error_streak(self, error: Exception) -> bool:
        """Check if too many errors have occurred"""
        self.consecutive_errors += 1
        return self.consecutive_errors >= self.max_consecutive_errors
    
    def check_progress(self) -> bool:
        """Check if progress is being made"""
        return (time.time() - self.last_progress_time) < (self.max_iterations * 30)
```

#### Risk 8: Multiple Chrome Profile Conflicts

**Description**: Running Chrome with multiple sessions or profiles can cause cookie/tab conflicts.

**Mitigation Strategy**:
1. **Isolated browser contexts**: Each session gets its own Playwright browser context
2. **Separate Chrome data directories**: Use unique `--user-data-dir` for each session
3. **Profile validation**: Verify profile paths before launching
4. **Port management**: Ensure no port conflicts between Chrome instances
5. **Cleanup**: Always close browser contexts when sessions end

### 11.3 Contingency Plans

| Scenario | Contingency |
|----------|-------------|
| Chrome automation completely fails | Fall back to API-based agent communication if available |
| AppImage build fails | Distribute as tar.gz with embedded binaries |
| WebSocket issues | Fall back to REST polling with 5-second intervals |
| Database corruption | Auto-restore from last backup (stored alongside DB) |
| Performance too slow | Reduce default iteration count; add progress indicators |
| Security breach | Bind to 127.0.0.1 only; add encryption layer |

### 11.4 Security Considerations

```
Security Architecture:
═══════════════════

Layer 1: Network Security
  • Bind to localhost only (127.0.0.1)
  • No external network exposure
  • Optional: TLS encryption with self-signed certificates

Layer 2: Application Security
  • API key authentication for all endpoints
  • Input validation with Pydantic schemas
  • CORS restricted to localhost
  • No external URL fetching from user input

Layer 3: Data Security
  • SQLite database stored in ~/.config/ (not shared)
  • No sensitive data in logs
  • Optional: SQLite encryption (SQLCipher)
  • Session data isolated between users

Layer 4: Browser Security
  • Chrome runs with user's existing profile (already authenticated)
  • No additional permissions requested
  • Cookies are profile-scoped
  • Playwright runs in sandbox mode
```

---

## Appendix

### A. Environment Variables

```bash
# ~/.config/multi-ai-orchestrator/.env
MULTI_AI_PORT=8000
MULTI_AI_DB_PATH=~/.config/multi-ai-orchestrator/sessions.db
MULTI_AI_CHROME_PATH=/usr/bin/google-chrome
MULTI_AI_CHROME_PROFILE=~/.config/google-chrome
MULTI_AI_LOG_LEVEL=INFO
MULTI_AI_MAX_ITERATIONS=50
MULTI_AI_MESSAGE_TIMEOUT=60
MULTI_AI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx
```

### B. Directory Structure for AppImage

```
AppImage/
├── usr/
│   ├── bin/
│   │   ├── multi-ai-orchestrator    # Main launcher script
│   │   └── backend-server            # FastAPI server
│   ├── lib/
│   │   └── python3/                  # Embedded Python
│   ├── share/
│   │   ├── multi-ai-orchestrator/
│   │   │   ├── frontend/             # Flutter build output
│   │   │   └── backend/              # Backend build output
│   │   └── icons/
│   │       └── multi-ai-orchestrator.svg
│   └── share/applications/
│       └── multi-ai-orchestrator.desktop
├── AppRun                            # AppImage entry point
├── multi-ai-orchestrator.AppImage    # Final output
└── sandbox/                          # Sandboxed resources
```

### C. Build Commands Reference

```bash
# Build the AppImage
cd projects/story-app
make appimage

# Build Linux tar.gz
make linux

# Run in development mode
make dev

# Clean all build artifacts
make clean

# Run tests
make test

# Build backend only
cd backend && ./.venv/bin/python run.py

# Build frontend only
cd frontend && flutter build linux --release
```

### D. Makefile for story-app

```makefile
.PHONY: help dev appimage linux clean test setup

help:
	@echo "Multi-AI Agent Orchestrator Commands:"
	@echo "  make dev       - Start development mode"
	@echo "  make appimage  - Build AppImage"
	@echo "  make linux     - Build Linux tar.gz"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make test      - Run all tests"
	@echo "  make setup     - Setup project"

setup:
	cd backend && pip install -r requirements.txt
	cd frontend && flutter pub get
	npx playwright install chromium

dev:
	# Start backend and frontend concurrently
	cd backend && ./.venv/bin/python run.py &
	cd frontend && flutter run -d linux --release &

appimage:
	./tools/build_appimage.sh

linux:
	cd frontend && flutter build linux --release
	./tools/build_linux.sh

clean:
	cd backend && rm -rf __pycache__ *.db *.egg-info
	cd frontend && rm -rf build/ linux/ .flutter-plugins
	rm -f *.AppImage *.tar.gz

test:
	cd backend && pytest tests/ -v --cov=.
	cd frontend && flutter test --coverage
```

---

## Document Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-28 | Architecture Design | Initial version |

---

*End of Architecture Design Document*
