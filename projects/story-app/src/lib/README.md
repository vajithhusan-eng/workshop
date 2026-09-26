# 📦 Core Library

> **Status:** Placeholder — Framework-dependent implementation.

This directory contains the core library code for the Story App.

## Purpose

The `src/lib/` directory holds shared, framework-independent logic:
- Story engine core logic (parsing, branching, state management)
- Data models (Scene, Character, Item, WorldNode)
- Utility functions (validation, formatting, serialization)
- Configuration management

## Framework Mapping

| Concept | Flutter | Python | Electron |
|---------|---------|--------|----------|
| Core lib | `lib/src/` | `src/lib/` | `src/lib/` |
| Models | `lib/models/` | `src/models/` | `src/models/` |
| Services | `lib/services/` | `src/services/` | `src/services/` |
| Utils | `lib/utils/` | `src/utils/` | `src/utils/` |

See [PROJECT_TYPE.md](../PROJECT_TYPE.md) for framework-specific instructions.
