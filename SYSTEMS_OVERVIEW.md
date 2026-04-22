# Systems Overview

## Core runtime areas

### Dungeon generation

Main file:

- `C:\Users\Jakob\Documents\RPG\scripts\world\dungeon_run.gd`

Important current state:

- The dungeon now uses a logical room-graph generator rather than direct final-tile carving.
- This was introduced to avoid bad one-tile wall situations, impossible joins, and overly fragile corner logic.
- The logical generator is the current foundation and should be preserved unless there is a very strong reason to change it.
- Dungeon exploration now includes a navigator map/minimap plus unexplored darkness that reveals as the player moves.
- Exploration state is tracked per generated depth so revisiting a floor keeps the discovered layout during the current run.

Key files:

- `C:\Users\Jakob\Documents\RPG\scripts\world\dungeon_run.gd`
- `C:\Users\Jakob\Documents\RPG\scripts\ui\dungeon_map_widget.gd`
- `C:\Users\Jakob\Documents\RPG\scenes\world\` (supporting world scenes, if added later)

### Player / combat

Relevant areas:

- `C:\Users\Jakob\Documents\RPG\scripts\actors\player.gd`
- `C:\Users\Jakob\Documents\RPG\scenes\actors\player.tscn`
- player visuals and modular equipment layering are already in place

Current direction:

- player is modular and equipment-aware
- combat is ARPG-style and feel-driven
- attack/use/talk/context action behavior matters for mobile usability

### Enemies

Relevant areas:

- `C:\Users\Jakob\Documents\RPG\scripts\actors\rat.gd`
- `C:\Users\Jakob\Documents\RPG\scenes\actors\rat.tscn`

Current direction:

- enemies should be readable and category-driven
- current dungeon enemy baseline is rats
- future enemy categories include beasts, humanoids, and bosses
- enemy rarity exists and should remain meaningful

### Interactables / loot / props

Relevant areas:

- `C:\Users\Jakob\Documents\RPG\scenes\interactables\chest.tscn`
- `C:\Users\Jakob\Documents\RPG\scenes\interactables\dropped_loot.tscn`
- `C:\Users\Jakob\Documents\RPG\scenes\interactables\dungeon_stairs.tscn`
- `C:\Users\Jakob\Documents\RPG\scripts\world\dungeon_run.gd`

Current direction:

- stairs, loot, props, and decor are strongly tied to dungeon generation
- props that look solid should generally block movement
- treasure should feel authored and rewarding, not randomly sprinkled

### Inventory / progression

Relevant areas:

- inventory and progression scripts under `C:\Users\Jakob\Documents\RPG\scripts\world\`
- overlay and UI scenes under `C:\Users\Jakob\Documents\RPG\scenes\ui\`

Current direction:

- drag/drop inventory exists
- player stats exist
- gear affects power
- gold, loot, consumables, and quick item behavior already exist

### NPCs / quests / hub flow

Relevant areas:

- NPC scenes/scripts under `C:\Users\Jakob\Documents\RPG\scenes\actors\` and `C:\Users\Jakob\Documents\RPG\scripts\actors\`
- quest/state scripts under `C:\Users\Jakob\Documents\RPG\scripts\world\`

Current direction:

- village hub supports NPC interactions and quest onboarding
- tracked quest flow exists and should remain readable on mobile
- dungeon descent should tie back into quest and progression loops

### Room archetypes

Current archetype work has started in the dungeon:

- storage room
- bone room
- chest room
- rat nest room
- torch hall
- dead-end loot nook

These need continued tuning so rooms are recognizable and purposeful.

### Exploration / navigator map

Relevant areas:

- `C:\Users\Jakob\Documents\RPG\scripts\world\dungeon_run.gd`
- `C:\Users\Jakob\Documents\RPG\scripts\ui\game_overlay.gd`
- `C:\Users\Jakob\Documents\RPG\scripts\ui\dungeon_map_widget.gd`
- `C:\Users\Jakob\Documents\RPG\scripts\world\game_session.gd`

Current direction:

- dungeon floors start hidden and reveal around the player
- explored space should remain readable without fully removing tension
- the map should support orientation and descent, not replace room readability
- map state should reset cleanly outside the dungeon UI flow

## Current known technical lessons

- Long chains of visual exceptions for dungeon walls become brittle quickly.
- Logical generation solves more problems than trying to render around bad shapes.
- Reserve important cells for gameplay objects like stairs, player spawn, and treasure.
- Props that look solid should usually have collision.

## Known traps / things not to break

- Do not revert dungeon generation back to direct final-tile carving.
- Do not place treasure or props on reserved gameplay cells such as stairs or player spawn.
- Do not assume visual fixes should solve layout problems when generation rules can solve them upstream.
- Do not break mobile interaction flow when changing UI or gameplay context actions.
- Do not treat long old chats as more reliable than these project files.

## Current stable vs experimental areas

### Stable enough to build on

- logical dungeon generation
- basic dungeon descent and stair transitions
- player modular visuals
- inventory / equipment / progression base loop
- mobile controls base support

### Still being tuned

- room archetype readability
- dungeon wall visual polish
- encounter composition by room type
- treasure placement feel
- advanced enemy variety

## Validation

Useful headless launch check:

`C:\Users\Jakob\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe --path C:\Users\Jakob\Documents\RPG --headless --quit-after 1`

Use this when making code changes to catch parser/startup issues quickly.
