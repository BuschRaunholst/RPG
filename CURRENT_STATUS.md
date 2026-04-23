# Current Status

## Project state

The project is currently in a good playable prototype state for the dungeon-crawler direction.

The major recent success is the move to a logical dungeon generator. That solved a large class of bad wall-layout issues that were difficult to patch visually.

## What is working well

- logical dungeon generation is stable enough to iterate on
- player movement, combat, and dungeon descent loop are working
- inventory / equipment / stat progression loop is in place
- modular player visuals exist
- weapon profiles now support multiple melee styles plus basic ranged targeting
- player weapon posing now has per-facing grip, arm visibility, and layer rules for cleaner front/side/back reads
- weapon visual profiles now support data-driven offsets and projectile spawn points, reducing the need for item-name exceptions in the player script
- room archetypes exist and are beginning to shape dungeon identity
- mobile controls are supported
- dungeon exploration now has a working minimap / navigator map pass
- unexplored dungeon space is now darkened until discovered

## What is currently being improved

- room archetypes should be easier to identify at a glance
- chest rooms should feel deliberate and rewarding
- rat nests should feel inhabited and dangerous
- props should visually match their gameplay role
- dungeon wall visuals still need polish, but should not break the logical generator foundation
- exploration reveal radius, fog feel, and map readability still need tuning

## Recent important architecture decisions

- dungeon generation uses a logical room graph, not direct tile carving
- repo-root context files are now the intended source of truth for future chats
- important project/system changes should update these files
- GitHub Desktop is the preferred git workflow

## Known active issues / polish targets

- dungeon wall visuals are acceptable but not final
- archetype-specific decoration still needs stronger identity
- some enemy/loot placement still needs feel tuning
- dungeon pacing can still improve through room variety and encounter composition

## Recommended next-step pattern

- use a fresh focused thread per subsystem
- start new chats by reading `AGENTS.md`
- keep architectural decisions documented here when they change
