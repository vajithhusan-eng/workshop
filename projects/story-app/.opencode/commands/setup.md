---
name: setup
description: Set up the Story App project environment
---

# 📖 Story App — Setup

## Prerequisites

- Ubuntu Linux 22.04+
- Git
- OpenCode CLI
- Framework of choice (see PROJECT_TYPE.md)

## Steps

1. **Navigate to project**
   ```bash
   cd /home/vajith-husan/Documents/WORKSHOP/projects/story-app
   ```

2. **Review framework options**
   ```bash
   cat PROJECT_TYPE.md
   ```

3. **Setup dependencies**
   ```bash
   make setup
   ```

4. **Validate story content**
   ```bash
   make story-validate
   ```

5. **Run story engine**
   ```bash
   make story
   ```

6. **Open in OpenCode**
   ```bash
   cd /home/vajith-husan/Documents/WORKSHOP
   opencode projects/story-app
   ```

## Available Agents

- **story-designer** — Scene architecture, branching logic, world building
- **narrative-agent** — Dialogue, voice, consistency, editing
- **coder** — Implementation and bug fixes
- **reviewer** — Code and content review

## Next Steps

1. Choose your framework (see PROJECT_TYPE.md)
2. Define your story concept in docs/concept-notes.md
3. Create your first scene in story/scenes/
4. Design your characters in story/characters/
5. Build out the world in story/world/
