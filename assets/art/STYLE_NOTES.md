# Oakcross Prototype Art Direction

We are returning to the custom prototype style and improving it one item at a time.

## Current Goal

Keep the world readable, light, and game-first while we slowly improve individual objects. Avoid replacing the whole map with a big imported tileset until the gameplay and art direction are stronger.

## Iteration Rule

Only redesign one visual object or tile family at a time, then test it in-game before moving on.

Good single-item targets:

- House exterior
- Tree or bush
- Chest
- Signpost
- Path tile
- Grass tile
- Fountain
- NPC marker or quest marker
- Pickup flower/herb
- Slime enemy

## Ground Tile Pass 1

The current custom ground atlas is `assets/art/tilesets/oakcross_ground_32.png`.
It contains 12 hand-tuned/procedural 32x32 tiles:

- 0-3: grass variants
- 4-7: dirt/path variants
- 8-9: stone path variants
- 10-11: grass/path transition support

## Style Targets

- 2.5D top-down readability.
- Simple shapes first, then add small details.
- Slightly muted colors, not overly saturated.
- Clear silhouettes for interactables.
- Mobile readability at small screen size.
- Keep collision/gameplay shapes separate from visuals.

## Workflow

1. Choose one item to improve.
2. Build it in a small dedicated script/scene if possible.
3. Test it in the real map.
4. Keep it only if it improves readability and mood.
