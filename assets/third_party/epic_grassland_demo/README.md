# EPIC RPG World Grass Land Demo

This folder keeps the original Tiled-ready outdoor tileset files together:

- `TiledMap Editor/sample map demo.tmx`
- `TiledMap Editor/Tilesets/Tilesets and props Demo.tsx`
- `Tilesets and props/Tilesets and props Demo.png`

The source tileset is `32x32`, with `26` columns and `546` tiles. The `.tsx` file includes Tiled Wang/terrain rules, so the best workflow is:

1. Open `TiledMap Editor/sample map demo.tmx` in Tiled.
2. Save a copy as the Oakcross overworld map.
3. Add object layers for gameplay markers such as `player_spawn`, `door`, `chest`, `npc`, `pickup`, and `collision`.
4. Let Godot/Codex wire those object-layer markers to gameplay scenes and scripts.

Avoid editing generated preview sheets or AI atlases directly. Real map work should happen in Tiled using this `.tsx` tileset.
