# 📝 Concept Notes — Echoes of the Shattered Realm

> **Status:** Draft — Working concept for "Story App" project.
> These notes are living documents — update as the project evolves.

---

## 🎯 Core Concept

**Elevator Pitch:**
> In a world shattered by a cataclysm that destroyed not just land but memory itself, you play as the last Memory Keeper — waking with no identity, guided by a mysterious voice, navigating branching paths through ruined kingdoms. Every choice reshapes the narrative. Every discovery restores a piece of yourself.

**One-liner:** *Choose your own adventure meets narrative mystery — where your choices don't just change the story, they change who you are.*

---

## 🌍 World Vision

### The Shattered Realm
- A once-unified land torn apart by the **Great Breaking**
- Reality exists as floating fragments connected by fragile bridges
- Memory is the fundamental substance of the world — lose it, and reality crumbles
- The **Memory Keepers** were the guardians of collective memory, now nearly extinct

### Tone & Atmosphere
- **Primary:** Melancholic wonder — beauty in decay
- **Secondary:** Quiet hope — things can be restored
- **Tertiary:** Underlying dread — what caused the Breaking?
- **Visual Style:** Crystal, light, ruins, ethereal glow
- **Sound Design:** Hums, echoes, distant winds, crystalline tones

### Key Themes
1. **Identity** — Who are you when you've lost your memory?
2. **Consequence** — Every choice echoes forward
3. **Restoration** — Can broken things be made whole again?
4. **Trust** — Who do you trust when you can't even trust yourself?

---

## 🎭 Story Structure

### Act Overview

| Act | Title | Core Theme | Key Development |
|-----|-------|-----------|-----------------|
| I | The Awakening | Identity loss | Wake up, meet the Voice, choose your path |
| II | The Gathering | Connection | Find allies, explore kingdoms, uncover secrets |
| III | The Reckoning | Truth | Discover the cause of the Breaking, make the final choice |

### Branching Philosophy
- **Meaningful Choices:** Every branch must lead to a different experience
- **Hidden Paths:** Some choices are only visible to observant players
- **Compounding Consequences:** Early choices affect Act II and III
- **Multiple Endings:** At least 5 distinct endings based on accumulated choices
- **New Game+:** Decisions echo across playthroughs

---

## 👥 Character Concepts

### Protagonist: Elyra
- **Role:** Last Memory Keeper
- **Core Conflict:** Lost identity, seeking restoration
- **Personality:** Resilient, introspective, compassionate, cautious
- **Voice:** Soft but firm, literary, thoughtful

### Supporting Characters (Concept)
- **The Voice** — Mysterious guide, possibly a fragment of Elyra's own memory
- **Commander Kael** — Pragmatic ally, questions Elyra's mental state
- **The Librarian** — Keeper of preserved knowledge in the Library of Lights
- **Shadow Weaver** — Antagonist figure within the Kingdom of Shadows

---

## 🎮 Gameplay Mechanics (Concept)

### Core Loop
1. **Read** — Experience narrative scenes
2. **Choose** — Make meaningful decisions
3. **Discover** — Uncover story elements, items, memories
4. **Reflect** — Consequences manifest and ripple forward
5. **Replay** — New Game+ with accumulated knowledge

### Key Systems
- **Memory System:** Collect memory fragments to restore identity
- **Relationship System:** Build trust with characters through choices
- **Knowledge System:** Discover world lore that unlocks hidden content
- **Artifact System:** Collect items with unique powers and lore

---

## 📐 Technical Considerations

### Story Format
- **Primary:** YAML (human-readable, structured, version-control friendly)
- **Schema:** Consistent fields per content type (scene, character, item, world)
- **Validation:** Story files should be validated on load
- **Branching:** DAG-based graph structure for narrative navigation

### Engine Requirements
- YAML/JSON parser for story content
- Branching narrative engine with state tracking
- Asset management for images, sounds, fonts
- Save/load system for story progress
- Localization-ready text system

---

## 📊 Development Roadmap

### Phase 1: Foundation
- [ ] Set up project scaffold (framework TBD)
- [ ] Define story schema and validation
- [ ] Create Act I scenes (minimum 10 scenes)
- [ ] Design core characters (5+ characters)
- [ ] Build world map and faction system

### Phase 2: Core Engine
- [ ] Story engine implementation
- [ ] Branching logic and choice system
- [ ] State management and save/load
- [ ] Asset pipeline (images, sounds, fonts)
- [ ] UI framework for narrative presentation

### Phase 3: Content Expansion
- [ ] Act II scenes (minimum 15 scenes)
- [ ] Act III scenes (minimum 10 scenes)
- [ ] Multiple ending paths
- [ ] New Game+ mechanics
- [ ] Achievements and discovery system

### Phase 4: Polish
- [ ] Audio implementation (SFX, ambient, music)
- [ ] Visual polish (sprites, backgrounds, effects)
- [ ] Localization support
- [ ] Performance optimization
- [ ] Testing and QA

---

## 🔗 References & Inspiration

- **Games:** Disco Elysium, Divinity: Original Sin, Life is Strange
- **Books:** Choose Your Own Adventure, Hyperion, The Name of the Wind
- **Formats:** Twine, Ink, Choice of Games

---

## 📌 Open Questions

1. **Framework:** Flutter, GTK/Python, or Electron?
2. **Voice acting:** Will characters have voice acting?
3. **Music:** Original compositions or licensed?
4. **Save system:** Cloud saves or local only?
5. **Multi-platform:** Ubuntu only, or also other Linux distros?

---

*Last updated: September 2026 — Story App Project*
