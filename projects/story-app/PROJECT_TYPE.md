# 🔧 Project Type & Framework Options

This project is **framework-agnostic** at the scaffolding level. Choose your preferred framework below to get started.

---

## Option 1: 🎨 Flutter (Recommended for Desktop GUI)

**Why Flutter:**
- Single codebase for Ubuntu Linux desktop
- Rich widget library for narrative-driven UIs
- Excellent tooling and hot reload
- Strong community for interactive apps

### Setup

```bash
# Install Flutter SDK
sudo snap install flutter --classic

# Or use apt
sudo apt install flutter

# Initialize project (replace this scaffold)
cd /home/vajith-husan/Documents/WORKSHOP/projects/story-app
flutter create --platforms=linux .

# Copy your source files into src/lib/, src/screens/, etc.
# Update pubspec.yaml to match your dependencies
```

### Key Dependencies to Add (in pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  # Story engine
  yaml: ^3.1.2
  path_provider: ^2.1.1
  # UI helpers
  go_router: ^13.0.0
  riverpod: ^2.4.9
  # Audio
  audioplayers: ^4.2.1
  # Assets
  flutter_svg: ^2.0.9
```

### File Mapping

| Scaffold Path | Flutter Equivalent |
|---------------|-------------------|
| `src/lib/` | `lib/` |
| `src/screens/` | `lib/screens/` |
| `src/widgets/` | `lib/widgets/` |
| `src/models/` | `lib/models/` |
| `src/services/` | `lib/services/` |
| `assets/images/` | `assets/images/` |
| `assets/sounds/` | `assets/sounds/` |
| `story/scenes/` | `assets/story/scenes/` |
| `tests/` | `test/` |

---

## Option 2: 🐍 GTK/Python (PyGObject)

**Why Python/GTK:**
- Native Linux desktop experience
- Rapid prototyping for narrative logic
- Extensive Python ecosystem for NLP/AI integration
- Lightweight, no heavy runtime

### Setup

```bash
# Install Python and GTK dependencies
sudo apt update
sudo apt install python3 python3-pip python3-gi gir1.2-gtk-3.0

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Key Dependencies to Add (in requirements.txt)

```
# Core GUI
pygobject>=3.42

# Story engine
pyyaml>=6.0
jinja2>=3.1

# Audio
pygame>=2.5

# Data
sqlalchemy>=2.0
```

### File Mapping

| Scaffold Path | Python Equivalent |
|---------------|-------------------|
| `src/lib/` | `src/lib/` (python modules) |
| `src/screens/` | `src/screens/` (Gtk widgets) |
| `src/services/` | `src/services/` (business logic) |
| `story/scenes/` | `story/scenes/` (YAML/JSON) |
| `tests/` | `tests/` (pytest) |

### Entry Point

```python
# src/main.py
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk
# ... your application code
```

---

## Option 3: 💻 Electron

**Why Electron:**
- Web technologies (HTML/CSS/JS) for rich UI
- Cross-platform (Linux, Windows, macOS)
- Large ecosystem of packages
- Good for text-heavy narrative apps

### Setup

```bash
# Install Node.js
sudo apt install nodejs npm

# Initialize Electron project
npm init electron@latest

# Install dependencies
npm install
```

### Key Dependencies to Add (in package.json)

```json
{
  "dependencies": {
    "electron": "^30.0.0",
    "yaml": "^2.4.5",
    "express": "^4.18.2",
    "fs-extra": "^11.2.0"
  }
}
```

### File Mapping

| Scaffold Path | Electron Equivalent |
|---------------|-------------------|
| `src/lib/` | `src/renderer/` or `src/renderer/js/` |
| `src/screens/` | `src/renderer/screens/` |
| `assets/` | `assets/` |
| `story/` | `story/` (JSON/YAML) |
| `tests/` | `tests/` (jest/mocha) |

---

## 📊 Comparison Matrix

| Criteria | Flutter | GTK/Python | Electron |
|----------|---------|------------|----------|
| **Performance** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Native Feel** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **Dev Speed** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Desktop Linux** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Narrative Logic** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Community** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Package Size** | ~50MB | ~15MB | ~150MB |
| **AI/NLP Integration** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## 🚀 To Switch Frameworks

1. Choose your framework in the table above
2. Update `PROJECT_TYPE.md` to mark your choice
3. Create the appropriate config file (`pubspec.yaml`, `requirements.txt`, or `package.json`)
4. Move `src/` contents into framework-standard layout
5. Update `Makefile` targets accordingly
6. The `story/` directory is **framework-agnostic** — all content works with any engine

---

## 📝 Story Format

Regardless of framework, all story content follows this convention:

- **Format:** YAML (primary), JSON (alternative), Markdown (documentation)
- **Location:** `story/scenes/`, `story/characters/`, `story/world/`
- **Schema:** Defined per content type, validated on load
- **Branching:** DAG-based narrative graph in `story/nodes/`

See `story/` directory for sample files and conventions.
