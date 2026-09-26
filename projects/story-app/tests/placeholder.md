# 🧪 Tests

> **Status:** Placeholder — Tests will be created when the framework is chosen.

## Test Structure

```
tests/
├── unit/               # Unit tests for individual components
│   ├── models/         # Data model tests
│   ├── services/       # Business logic tests
│   └── utils/          # Utility function tests
├── integration/        # Integration tests
│   └── engine/         # Story engine integration tests
├── story/              # Story content validation
│   ├── scenes/         # Scene format validation
│   ├── characters/     # Character schema validation
│   └── world/          # World data validation
└── e2e/               # End-to-end tests
    └── narrative/      # Full narrative flow tests
```

## Framework-Specific Test Setup

### Flutter
```bash
flutter test test/
```

### Python
```bash
python3 -m pytest tests/
```

### Electron
```bash
npm test
```

## Story Content Tests
- Validate YAML schema for all story files
- Verify branching graph connectivity (no orphan nodes)
- Check for narrative consistency (no contradictions)
- Verify character flags and state transitions
