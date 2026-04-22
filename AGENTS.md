# RPG Project Agent Guide

If you are working in this repository, read these files before making changes:

1. `C:\Users\Jakob\Documents\RPG\PROJECT_CONTEXT.md`
2. `C:\Users\Jakob\Documents\RPG\ART_DIRECTION.md`
3. `C:\Users\Jakob\Documents\RPG\SYSTEMS_OVERVIEW.md`
4. `C:\Users\Jakob\Documents\RPG\CURRENT_STATUS.md`
5. `C:\Users\Jakob\Documents\RPG\TODO.md`

Use `C:\Users\Jakob\Documents\RPG\CHAT_HANDOFF_TEMPLATE.md` when starting a new focused thread.

## Working rules

- This is a Godot action RPG project for mobile-first play.
- Prefer small, focused changes to one subsystem at a time.
- Do not revert user work unless explicitly asked.
- Keep the game readable and maintainable over clever shortcuts.
- When changing game logic, prefer fixing the underlying system rather than stacking visual patches.
- Git workflow is handled primarily through GitHub Desktop.

## Current priorities

- Keep dungeon generation stable and readable.
- Improve dungeon room identity and progression.
- Continue polishing combat, loot, props, and encounter feel.
- Preserve the current darker dungeon-crawler direction.

## Do / Don't

### Do

- Read the repo context files before making architectural changes.
- Prefer fixing systems at the source rather than layering visual exceptions.
- Keep mobile controls, inventory flow, and dungeon descent flow working.
- Update the repo context files when important systems or project direction changes.
- Keep new chats focused on one subsystem when possible.

### Don't

- Do not revert the dungeon back to direct final-tile carving.
- Do not assume old chat history is the source of truth.
- Do not scatter treasure, props, or enemies randomly if archetype logic should control them.
- Do not remove mobile-first considerations when changing UI or interaction logic.
- Do not silently make major design-direction changes without reflecting them in the docs.

## Important implementation note

This project has grown enough that long chat history is no longer a reliable source of truth.
The files listed above are the intended source of truth for new work.

## Documentation maintenance rule

If an important system, workflow, direction, or architectural decision changes, update the relevant repo-root context files in the same work session.
