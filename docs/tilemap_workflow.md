# TileMap Workflow Prototype

This is the test workflow for painting maps directly in Godot.

Open `res://scenes/world/tilemap_paint_test.tscn` and paint on these layers:

- `Ground`: base grass, path, stone, and other walkable ground.
- `Decorations`: visual-only details that sit above ground, like extra grass or small accents.
- `Collision`: red-tinted planning layer for blocked tiles. Later, Codex can convert this into real collision or use it as a guide.
- `Markers`: yellow-tinted planning layer for gameplay markers like doors, NPCs, chests, enemy spawns, quest targets, and pickup points.

Keep the layer positions aligned. If one layer moves, the painted cells will no longer match the others.
