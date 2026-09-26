# 📖 Story App — Interactive Narrative Desktop Application

[![Platform](https://img.shields.io/badge/Platform-Ubuntu%20Linux-blue?logo=linux)](https://ubuntu.com)
[![OpenCode](https://img.shields.io/badge/OpenCode-Active-brightgreen?logo=opencode)](http://127.0.0.1:49374)
[![Framework](https://img.shields.io/badge/Framework-TBD-yellow?logo=question)](PROJECT_TYPE.md)

A **story-based desktop GUI application** for Ubuntu Linux — an interactive fiction experience with branching narratives, rich characters, and an immersive world. Think *choose-your-own-adventure* meets modern graphical storytelling.

> **Framework is TBD.** See [PROJECT_TYPE.md](./PROJECT_TYPE.md) for options and setup instructions.

---

## 📖 Story Concept

**Working Title:** *Echoes of the Shattered Realm*

In a world fractured by an ancient cataclysm, the last **Memory Keepers** must navigate branching paths through shattered kingdoms, each choice reshaping the narrative landscape. Players uncover lost histories, forge alliances with complex characters, and decide the fate of the realm — with every decision echoing forward through the story.

> **Status:** Concept phase — story outline, characters, and world data will be fleshed out in `story/`.

---

## 📁 Project Structure

```
story-app/
├── 📄 opencode.jsonc      → OpenCode project configuration
├── 📄 PROJECT_TYPE.md     → Framework options & setup guides
├── 📄 Makefile            → Quick commands (make setup, make dev, etc.)
├── 📄 README.md           → This file
├── 📄 .gitignore          → Git exclusions
├── 📁 .opencode/          → OpenCode agents and commands
│   ├── agents/            → story-designer, narrative-agent, etc.
│   └── commands/          → Project-specific commands
├── 📁 story/              → All narrative content
│   ├── scenes/            → Individual scene files
│   ├── characters/        → Character definitions
│   ├── world/             → World data & lore
│   ├── items/             → Item/artifact definitions
│   └── nodes/             → Story graph / branching nodes
├── 📁 src/                → Application source code
│   ├── lib/               → Core library code
│   ├── widgets/           → Reusable UI widgets
│   ├── screens/           → Screen/view controllers
│   ├── services/          → Business logic & engine
│   ├── models/            → Data models
│   └── utils/             → Utility functions
├── 📁 assets/             → Static assets
│   ├── images/            → Sprites, backgrounds, UI art
│   ├── sounds/            → Music, SFX, voiceovers
│   └── fonts/             → Custom typography
├── 📁 docs/               → Documentation & concept notes
├── 📁 tests/              → Test suites
└── 📁 scripts/            → Build & utility scripts
```

---

## 🚀 Quick Start

```bash
# Navigate to project
cd /home/vajith-husan/Documents/WORKSHOP/projects/story-app

# Setup the project
make setup

# Start development
make dev

# Build for release
make build

# Run the story engine
make story

# Clean build artifacts
make clean
```

---

## 🛠️ Tech Stack (TBD)

| Component | Options | Status |
|-----------|---------|--------|
| **Framework** | Flutter, GTK/Python (PyGObject), Electron | ❓ TBD |
| **Language** | Dart, Python, JavaScript/TypeScript | ❓ TBD |
| **Story Format** | YAML, JSON, Markdown | ✅ YAML (preferred) |
| **Build System** | Make, CMake, pubspec | ✅ Makefile |
| **Package Mgmt** | pub, pip, npm | ❓ TBD |

See [PROJECT_TYPE.md](./PROJECT_TYPE.md) for detailed framework comparison and setup.

---

## 📝 Story Outline

### Act I — The Awakening
> *The player wakes in the ruins of the First Kingdom with no memory.*

- **Core Hook:** A mysterious voice guides the player through the opening scenes
- **Key Choice:** Trust the voice or seek answers independently
- **Introduction to World:** The Shattered Realm — a land fractured by the Great Breaking

### Act II — The Gathering
> *Allies are found, alliances are forged, secrets are uncovered.*

- **Character Arcs:** Each companion has a personal story that intersects the main plot
- **Branching Paths:** Player choices affect which characters join and which are lost
- **World Exploration:** Travel between shattered kingdoms, each with unique culture and challenges

### Act III — The Reckoning
> *The truth behind the cataclysm is revealed. The final choice looms.*

- **Climax:** Confront the source of the Breaking
- **Multiple Endings:** Based on accumulated choices, relationships, and discoveries
- **Legacy System:** Decisions echo across playthroughs in New Game+

---

## 🧪 Testing

```bash
# Run all tests
make test

# Run story engine tests
make story-test

# Run unit tests
make unit-test
```

---

## 📚 Documentation

- [PROJECT_TYPE.md](./PROJECT_TYPE.md) — Framework options & detailed setup
- [docs/](./docs/) — Concept notes, design docs, and planning
- [story/](./story/) — All narrative content files

---

## 🔗 WORKSHOP Conventions

This project follows the WORKSHOP workspace standards:
- **OpenCode integration** with project-specific agents and MCP servers
- **Makefile-based workflow** consistent with other WORKSHOP projects
- **Git version control** with `.gitignore` for all build artifacts
- **Agent-driven development** with `story-designer` and `narrative-agent`

---

## 👥 Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-story`)
3. Commit your changes (`git commit -m 'feat: add amazing branching scene')`
4. Push to the branch
5. Open a Pull Request

---

## 📧 Contact

- **GitHub:** [vajithhusan-eng](https://github.com/vajithhusan-eng)
- **Email:** vajithhusan2510@gmail.com
