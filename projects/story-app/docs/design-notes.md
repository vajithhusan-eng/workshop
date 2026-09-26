# 🎨 Design Notes

> **Status:** Draft — Design decisions and patterns for the Story App.

---

## UI/UX Design Philosophy

### Core Principle: Narrative-First Interface
The interface should never distract from the story. Every UI element must serve the narrative experience.

### Design Guidelines

1. **Readability First**
   - Large, clear typography for narrative text
   - High contrast for readability
   - Appropriate line spacing and margins

2. **Minimalist Choice Presentation**
   - Choices should feel organic, not like a menu
   - Each choice should be styled to reflect its emotional tone
   - Limited choices per scene (3 maximum)

3. **Atmospheric Consistency**
   - Color palette reflects the world (crystalline, ethereal)
   - Sound design reinforces mood
   - Transitions should feel like part of the story

4. **Accessibility**
   - Support for screen readers
   - Adjustable text size and contrast
   - Keyboard and gamepad navigation

---

## Color Palette

### Primary Palette
| Name | Hex | Usage |
|------|-----|-------|
| Crystal Blue | #6BAED6 | Primary accent, links |
| Shadow Dark | #1A1A2E | Background, deep space |
| Echo Light | #E8D5B7 | Text, warm highlights |
| Memory White | #F5F0E8 | Background, cards |
| Fracture Red | #C1440E | Danger, warnings, choices with risk |

### Mood Variations
| Mood | Background | Text | Accent |
|------|-----------|------|--------|
| Calm | Shadow Dark | Memory White | Crystal Blue |
| Tense | Fracture Red | Memory White | Shadow Dark |
| Mysterious | Memory White | Shadow Dark | Crystal Blue |
| Hopeful | Crystal Blue | Shadow Dark | Echo Light |

---

## Typography

- **Headings:** "Cinzel" (medieval, mystical feel)
- **Body Text:** "Source Sans Pro" (readable, clean)
- **Code/Data:** "JetBrains Mono" (for debug/design tools)
- **Minimum Size:** 16px for body text
- **Line Height:** 1.6 for readability

---

## Sound Design

### Categories
- **Ambient:** Background atmosphere for each location
- **SFX:** Choice selections, transitions, notifications
- **Music:** Emotional score that adapts to story state
- **Voice:** Character dialogue (future feature)

### Audio Principles
- Looped ambient sounds for immersion
- Non-intrusive SFX that complement narrative
- Dynamic music that responds to player choices
- Volume ducking during dialogue

---

## Save System Design

### Save Slots
- 3 save slots (configurable in settings)
- Each slot contains:
  - Full narrative state
  - All flags and choices
  - Inventory and collected items
  - Current scene and location
  - Timestamp and playtime

### Save Format
```yaml
save_slot: 1
timestamp: "2026-09-26T00:00:00Z"
playtime_minutes: 145
state:
  current_scene: scene_02_voice_reveals
  flags:
    trust_voice: true
    met_voice: true
  inventory: [shattered_compass]
  memory_fragments: [fragment_01]
  relationships:
    the_voice: 5
```

---

## Localization Plan

### Target Languages
1. English (primary)
2. Spanish
3. French
4. German
5. Japanese

### Implementation
- All text stored in locale files (`assets/locales/`)
- YAML-based translation format
- Character limit awareness for UI text
- Right-to-left support for future languages

---

## Performance Targets

- **Load Time:** < 3 seconds for initial scene
- **Choice Response:** < 100ms
- **Save Time:** < 2 seconds
- **Memory Usage:** < 200MB
- **Frame Rate:** 60fps for UI animations

---

## Accessibility Checklist

- [ ] WCAG 2.1 AA compliance
- [ ] Screen reader support (NVDA, Orca)
- [ ] Keyboard-only navigation
- [ ] Gamepad support
- [ ] Adjustable text size
- [ ] High contrast mode
- [ ] Reduced motion option
- [ ] Colorblind-friendly palette
