extends Node2D

const InventoryStateScript = preload("res://scripts/world/inventory_state.gd")
const ProgressionScript = preload("res://scripts/world/progression.gd")
const LootTablesScript = preload("res://scripts/world/loot_tables.gd")
const PlayerScene = preload("res://scenes/actors/player.tscn")
const RatScene = preload("res://scenes/actors/rat.tscn")
const ChestScene = preload("res://scenes/interactables/chest.tscn")
const StairsScene = preload("res://scenes/interactables/dungeon_stairs.tscn")
const DroppedLootScene = preload("res://scenes/interactables/dropped_loot.tscn")
const MobileControlsScene = preload("res://scenes/ui/mobile_controls.tscn")

const TILE_SIZE: int = 32
const GRID_WIDTH: int = 72
const GRID_HEIGHT: int = 54
const WALL_TILE: int = 0
const FLOOR_TILE: int = 1
const WALL_RENDER_RADIUS: int = 2
const MAX_TRACKED_QUESTS: int = 5
const BASE_PLAYER_HEALTH: int = 80
const SPAWN_ENTRANCE: String = "entrance"
const SPAWN_UP_STAIRS: String = "up_stairs"
const SPAWN_DOWN_STAIRS: String = "down_stairs"
const ORTHOGONAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP
]

var depth: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var grid: Array[Array] = []
var rooms: Array[Rect2i] = []
var player: Node2D
var mobile_controls: Control
var mobile_controls_layer: CanvasLayer
var floor_root: Node2D
var wall_root: Node2D
var collision_body: StaticBody2D
var gameplay_root: Node2D
var decor_root: Node2D
var dungeon_size: Vector2 = Vector2.ZERO
var pending_spawn_mode: String = SPAWN_ENTRANCE
var decor_cells: Array[Vector2i] = []
var level_cache: Dictionary = {}

var player_health: int = BASE_PLAYER_HEALTH
var player_max_health: int = BASE_PLAYER_HEALTH
var player_xp: int = 0
var player_gold: int = 0
var stat_allocations: Dictionary = {"strength": 1, "stamina": 1, "dexterity": 1}
var bag_slots: Array[Dictionary] = []
var equipment_slots: Dictionary = {}
var quick_item_name: String = ""
var combat_message: String = ""
var tracked_quest_ids: Array[String] = []
var context_update_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_setup_state_from_transition()
	GameSession.show_game_overlay()
	GameSession.set_overlay_menu_locked(false)
	GameSession.bind_overlay_menu_toggled(Callable(self, "_on_overlay_menu_toggled"))
	GameSession.bind_overlay_inventory_changed(Callable(self, "_on_inventory_changed"))
	GameSession.bind_overlay_item_use_requested(Callable(self, "_on_item_use_requested"))
	GameSession.bind_overlay_quick_item_assigned(Callable(self, "_on_quick_item_assigned"))
	GameSession.bind_overlay_stat_increase_requested(Callable(self, "_on_stat_increase_requested"))
	_build_dungeon(depth)


func _setup_state_from_transition() -> void:
	var transition_state: Dictionary = GameSession.consume_transition_state()
	if transition_state.is_empty():
		bag_slots = InventoryStateScript.create_empty_bag()
		equipment_slots = InventoryStateScript.normalize_equipment(null)
		InventoryStateScript.add_item(bag_slots, "Trail Ration", "consumable", 2)
		InventoryStateScript.add_item(bag_slots, "Oak Buckler", "equipment", 1)
		return

	bag_slots = InventoryStateScript.normalize_bag(transition_state.get("bag_slots", []))
	equipment_slots = InventoryStateScript.normalize_equipment(transition_state.get("equipment_slots", {}))
	stat_allocations = ProgressionScript.normalize_allocations(transition_state.get("stat_allocations", {}))
	player_xp = int(transition_state.get("player_xp", 0))
	player_gold = int(transition_state.get("player_gold", 0))
	player_max_health = int(transition_state.get("player_max_health", BASE_PLAYER_HEALTH))
	player_health = clampi(int(transition_state.get("player_health", player_max_health)), 1, player_max_health)
	quick_item_name = str(transition_state.get("quick_item_name", ""))


func _process(delta: float) -> void:
	context_update_timer += delta
	if context_update_timer < 0.15:
		return
	context_update_timer = 0.0
	_update_context_button()


func _build_dungeon(next_depth: int, spawn_mode: String = SPAWN_ENTRANCE) -> void:
	depth = next_depth
	pending_spawn_mode = spawn_mode
	decor_cells.clear()
	_clear_dungeon()
	_create_roots()
	_load_or_generate_layout()
	_draw_dungeon()
	_build_wall_collision()
	_spawn_gameplay()
	_update_overlay("Depth %d" % depth)


func _load_or_generate_layout() -> void:
	if level_cache.has(depth):
		var cached_level: Dictionary = level_cache[depth]
		grid = _duplicate_grid(cached_level.get("grid", []))
		rooms = _duplicate_rooms(cached_level.get("rooms", []))
		dungeon_size = cached_level.get("dungeon_size", Vector2(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE))
		rng.seed = int(cached_level.get("seed", 9001 + depth * 7919))
		return

	rng.seed = 9001 + depth * 7919
	_generate_layout()
	level_cache[depth] = {
		"seed": rng.seed,
		"grid": _duplicate_grid(grid),
		"rooms": _duplicate_rooms(rooms),
		"dungeon_size": dungeon_size
	}


func _duplicate_grid(source_grid: Array) -> Array[Array]:
	var next_grid: Array[Array] = []
	for row_variant in source_grid:
		var next_row: Array[int] = []
		for value in row_variant:
			next_row.append(int(value))
		next_grid.append(next_row)
	return next_grid


func _duplicate_rooms(source_rooms: Array) -> Array[Rect2i]:
	var next_rooms: Array[Rect2i] = []
	for room_variant in source_rooms:
		next_rooms.append(room_variant)
	return next_rooms


func _clear_dungeon() -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame


func _create_roots() -> void:
	floor_root = Node2D.new()
	floor_root.name = "Floor"
	add_child(floor_root)

	wall_root = Node2D.new()
	wall_root.name = "Walls"
	add_child(wall_root)

	collision_body = StaticBody2D.new()
	collision_body.name = "WallCollision"
	add_child(collision_body)

	decor_root = Node2D.new()
	decor_root.name = "Decor"
	add_child(decor_root)

	gameplay_root = Node2D.new()
	gameplay_root.name = "Gameplay"
	gameplay_root.y_sort_enabled = true
	add_child(gameplay_root)


func _generate_layout() -> void:
	grid.clear()
	rooms.clear()

	for y in range(GRID_HEIGHT):
		var row: Array[int] = []
		for _x in range(GRID_WIDTH):
			row.append(WALL_TILE)
		grid.append(row)

	var entrance_room: Rect2i = Rect2i(4, GRID_HEIGHT / 2 - 3, 8, 6)
	rooms.append(entrance_room)
	_carve_room_feature(entrance_room, "rect")

	var main_room: Rect2i = entrance_room
	var main_direction: Vector2i = Vector2i.RIGHT
	var main_steps: int = 11 + mini(depth, 5)
	for _step_index in range(main_steps):
		var result: Dictionary = _try_attach_feature_from_room(main_room, _get_main_path_directions(main_direction), false)
		if result.is_empty():
			break
		main_room = result.get("room", main_room)
		main_direction = result.get("direction", main_direction)

	var side_branch_count: int = 5 + mini(depth, 3)
	for _branch_index in range(side_branch_count):
		if rooms.size() <= 2:
			break
		var branch_room_index: int = rng.randi_range(1, rooms.size() - 2)
		var branch_room: Rect2i = rooms[branch_room_index]
		_try_attach_feature_from_room(branch_room, _get_side_branch_directions(), true)

	_carve_loop_connections(1 + int(depth > 3))

	dungeon_size = Vector2(GRID_WIDTH * TILE_SIZE, GRID_HEIGHT * TILE_SIZE)


func _room_overlaps(candidate: Rect2i) -> bool:
	var padded_candidate: Rect2i = candidate.grow(2)
	for room in rooms:
		if padded_candidate.intersects(room):
			return true
	return false


func _sort_rooms_left_to_right(a: Rect2i, b: Rect2i) -> bool:
	return a.position.x < b.position.x


func _room_center(room: Rect2i) -> Vector2i:
	return Vector2i(room.position.x + room.size.x / 2, room.position.y + room.size.y / 2)


func _carve_room(room: Rect2i) -> void:
	_carve_room_feature(room, "rect")


func _try_attach_feature() -> bool:
	var frontier: Dictionary = _pick_frontier()
	if frontier.is_empty():
		return false

	var floor_cell: Vector2i = frontier.get("floor_cell", Vector2i.ZERO)
	var direction: Vector2i = frontier.get("direction", Vector2i.ZERO)
	var corridor_length: int = rng.randi_range(2, 7)
	var corridor_width: int = 2 + int(rng.randf() > 0.45)
	var corridor: Rect2i = _make_corridor_rect(floor_cell + direction, direction, corridor_length, corridor_width)
	if not _can_carve_rect(corridor, false):
		return false

	var corridor_end: Vector2i = _corridor_end_cell(corridor, direction)
	var feature_roll: float = rng.randf()
	if feature_roll < 0.25:
		_carve_rect(corridor)
		return true

	var room_size: Vector2i = _roll_room_size()
	var room: Rect2i = _make_room_beyond(corridor_end + direction, direction, room_size)
	if not _can_carve_rect(room, true):
		return false

	_carve_rect(corridor)
	var shape: String = _roll_room_shape()
	_carve_room_feature(room, shape)
	var room_door: Vector2i = corridor_end + direction
	_set_floor(room_door.x, room_door.y)
	rooms.append(room)
	return true


func _try_attach_feature_from_room(source_room: Rect2i, directions: Array[Vector2i], allow_corridor_only: bool) -> Dictionary:
	for direction in directions:
		for _attempt_index in range(8):
			var floor_cell: Vector2i = _pick_room_edge_cell(source_room, direction)
			var corridor_length: int = rng.randi_range(3, 6)
			var corridor_width: int = 2 + int(rng.randf() > 0.75)
			var corridor: Rect2i = _make_corridor_rect(floor_cell + direction, direction, corridor_length, corridor_width)
			if not _can_carve_rect(corridor, false):
				continue

			var corridor_end: Vector2i = _corridor_end_cell(corridor, direction)
			if allow_corridor_only and rng.randf() < 0.06:
				_carve_rect(corridor)
				return {
					"room": source_room,
					"direction": direction
				}

			var room_size: Vector2i = _roll_room_size()
			var room: Rect2i = _make_room_beyond(corridor_end + direction, direction, room_size)
			if not _can_carve_rect(room, true):
				continue

			_carve_rect(corridor)
			_carve_room_feature(room, _roll_room_shape())
			var room_door: Vector2i = corridor_end + direction
			_set_floor(room_door.x, room_door.y)
			rooms.append(room)
			return {
				"room": room,
				"direction": direction
			}

	return {}


func _pick_room_edge_cell(room: Rect2i, direction: Vector2i) -> Vector2i:
	if direction.x > 0:
		return Vector2i(room.position.x + room.size.x - 1, rng.randi_range(room.position.y + 1, room.position.y + room.size.y - 2))
	if direction.x < 0:
		return Vector2i(room.position.x, rng.randi_range(room.position.y + 1, room.position.y + room.size.y - 2))
	if direction.y > 0:
		return Vector2i(rng.randi_range(room.position.x + 1, room.position.x + room.size.x - 2), room.position.y + room.size.y - 1)
	return Vector2i(rng.randi_range(room.position.x + 1, room.position.x + room.size.x - 2), room.position.y)


func _get_main_path_directions(last_direction: Vector2i) -> Array[Vector2i]:
	var vertical_turn: Vector2i = Vector2i.DOWN if rng.randf() > 0.5 else Vector2i.UP
	var other_vertical_turn: Vector2i = Vector2i.UP if vertical_turn == Vector2i.DOWN else Vector2i.DOWN
	var directions: Array[Vector2i] = [last_direction, Vector2i.RIGHT, vertical_turn, other_vertical_turn]
	if last_direction != Vector2i.LEFT:
		directions.append(Vector2i.LEFT)
	return _deduplicate_directions(directions)


func _get_side_branch_directions() -> Array[Vector2i]:
	var directions: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.LEFT,
		Vector2i.DOWN,
		Vector2i.UP
	]
	directions.shuffle()
	return directions


func _deduplicate_directions(directions: Array[Vector2i]) -> Array[Vector2i]:
	var unique_directions: Array[Vector2i] = []
	for direction in directions:
		if not unique_directions.has(direction):
			unique_directions.append(direction)
	return unique_directions


func _pick_frontier() -> Dictionary:
	var candidates: Array[Dictionary] = []
	var directions: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.LEFT,
		Vector2i.DOWN,
		Vector2i.UP
	]

	for y in range(2, GRID_HEIGHT - 2):
		for x in range(2, GRID_WIDTH - 2):
			if int(grid[y][x]) != FLOOR_TILE:
				continue

			for direction in directions:
				var neighbor: Vector2i = Vector2i(x, y) + direction
				if _is_wall_cell(neighbor.x, neighbor.y):
					candidates.append({
						"floor_cell": Vector2i(x, y),
						"direction": direction
					})

	if candidates.is_empty():
		return {}

	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _make_corridor_rect(start_cell: Vector2i, direction: Vector2i, length: int, width: int) -> Rect2i:
	var half_width: int = width / 2
	if direction.x != 0:
		return Rect2i(
			start_cell.x if direction.x > 0 else start_cell.x - length + 1,
			start_cell.y - half_width,
			length,
			width
		)

	return Rect2i(
		start_cell.x - half_width,
		start_cell.y if direction.y > 0 else start_cell.y - length + 1,
		width,
		length
	)


func _corridor_end_cell(corridor: Rect2i, direction: Vector2i) -> Vector2i:
	if direction.x > 0:
		return Vector2i(corridor.position.x + corridor.size.x - 1, corridor.position.y + corridor.size.y / 2)
	if direction.x < 0:
		return Vector2i(corridor.position.x, corridor.position.y + corridor.size.y / 2)
	if direction.y > 0:
		return Vector2i(corridor.position.x + corridor.size.x / 2, corridor.position.y + corridor.size.y - 1)
	return Vector2i(corridor.position.x + corridor.size.x / 2, corridor.position.y)


func _roll_room_size() -> Vector2i:
	if rng.randf() < 0.18:
		return Vector2i(rng.randi_range(9, 14), rng.randi_range(6, 10))
	return Vector2i(rng.randi_range(5, 11), rng.randi_range(4, 9))


func _make_room_beyond(anchor_cell: Vector2i, direction: Vector2i, size: Vector2i) -> Rect2i:
	if direction.x > 0:
		return Rect2i(anchor_cell.x, anchor_cell.y - size.y / 2, size.x, size.y)
	if direction.x < 0:
		return Rect2i(anchor_cell.x - size.x + 1, anchor_cell.y - size.y / 2, size.x, size.y)
	if direction.y > 0:
		return Rect2i(anchor_cell.x - size.x / 2, anchor_cell.y, size.x, size.y)
	return Rect2i(anchor_cell.x - size.x / 2, anchor_cell.y - size.y + 1, size.x, size.y)


func _roll_room_shape() -> String:
	var roll: float = rng.randf()
	if roll < 0.08:
		return "l_room"
	if roll < 0.14:
		return "broken"
	if roll < 0.34:
		return "pillars"
	if roll < 0.56:
		return "rounded"
	return "rect"


func _can_carve_rect(rect: Rect2i, require_padding: bool = true) -> bool:
	if rect.position.x <= 1 or rect.position.y <= 1:
		return false
	if rect.position.x + rect.size.x >= GRID_WIDTH - 1:
		return false
	if rect.position.y + rect.size.y >= GRID_HEIGHT - 1:
		return false

	var padding: int = 1 if require_padding else 0
	for y in range(rect.position.y - padding, rect.position.y + rect.size.y + padding):
		for x in range(rect.position.x - padding, rect.position.x + rect.size.x + padding):
			if int(grid[y][x]) == FLOOR_TILE:
				return false

	return true


func _carve_rect(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			_set_floor(x, y)


func _carve_room_feature(room: Rect2i, shape: String) -> void:
	match shape:
		"l_room":
			_carve_l_room(room)
		"broken":
			_carve_broken_room(room)
		"pillars":
			_carve_rect(room)
			_add_room_pillars(room)
		"rounded":
			_carve_rounded_room(room)
		_:
			_carve_rect(room)


func _carve_l_room(room: Rect2i) -> void:
	_carve_rect(room)
	var cut_width: int = maxi(1, room.size.x / 4)
	var cut_height: int = maxi(1, room.size.y / 4)
	var cut_x: int = room.position.x if rng.randf() < 0.5 else room.position.x + room.size.x - cut_width
	var cut_y: int = room.position.y if rng.randf() < 0.5 else room.position.y + room.size.y - cut_height
	_fill_wall_rect(Rect2i(cut_x, cut_y, cut_width, cut_height))


func _carve_broken_room(room: Rect2i) -> void:
	_carve_rect(room)
	var bite_count: int = rng.randi_range(1, 2)
	for _bite_index in range(bite_count):
		var bite_width: int = rng.randi_range(1, maxi(1, room.size.x / 5))
		var bite_height: int = rng.randi_range(1, maxi(1, room.size.y / 5))
		var bite_position: Vector2i
		match rng.randi_range(0, 3):
			0:
				bite_position = Vector2i(rng.randi_range(room.position.x, room.position.x + room.size.x - bite_width), room.position.y)
			1:
				bite_position = Vector2i(rng.randi_range(room.position.x, room.position.x + room.size.x - bite_width), room.position.y + room.size.y - bite_height)
			2:
				bite_position = Vector2i(room.position.x, rng.randi_range(room.position.y, room.position.y + room.size.y - bite_height))
			_:
				bite_position = Vector2i(room.position.x + room.size.x - bite_width, rng.randi_range(room.position.y, room.position.y + room.size.y - bite_height))
		_fill_wall_rect(Rect2i(bite_position, Vector2i(bite_width, bite_height)))


func _carve_rounded_room(room: Rect2i) -> void:
	_carve_rect(room)
	_set_wall(room.position.x, room.position.y)
	_set_wall(room.position.x + room.size.x - 1, room.position.y)
	_set_wall(room.position.x, room.position.y + room.size.y - 1)
	_set_wall(room.position.x + room.size.x - 1, room.position.y + room.size.y - 1)


func _add_room_pillars(room: Rect2i) -> void:
	if room.size.x < 8 or room.size.y < 7:
		return

	var pillar_positions: Array[Vector2i] = [
		Vector2i(room.position.x + 2, room.position.y + 2),
		Vector2i(room.position.x + room.size.x - 3, room.position.y + 2),
		Vector2i(room.position.x + 2, room.position.y + room.size.y - 3),
		Vector2i(room.position.x + room.size.x - 3, room.position.y + room.size.y - 3)
	]
	for pillar in pillar_positions:
		if rng.randf() < 0.75:
			_set_wall(pillar.x, pillar.y)


func _fill_wall_rect(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			_set_wall(x, y)


func _set_wall(x: int, y: int) -> void:
	if x <= 0 or y <= 0 or x >= GRID_WIDTH - 1 or y >= GRID_HEIGHT - 1:
		return
	grid[y][x] = WALL_TILE


func _is_wall_cell(x: int, y: int) -> bool:
	if x <= 0 or y <= 0 or x >= GRID_WIDTH - 1 or y >= GRID_HEIGHT - 1:
		return false
	return int(grid[y][x]) == WALL_TILE


func _carve_loop_connections(loop_count: int) -> void:
	var candidates: Array[Vector2i] = []
	for y in range(2, GRID_HEIGHT - 2):
		for x in range(2, GRID_WIDTH - 2):
			if int(grid[y][x]) == FLOOR_TILE:
				continue

			var horizontal_loop: bool = int(grid[y][x - 1]) == FLOOR_TILE and int(grid[y][x + 1]) == FLOOR_TILE
			var vertical_loop: bool = int(grid[y - 1][x]) == FLOOR_TILE and int(grid[y + 1][x]) == FLOOR_TILE
			if horizontal_loop or vertical_loop:
				candidates.append(Vector2i(x, y))

	var carved: int = 0
	while carved < loop_count and not candidates.is_empty():
		var candidate_index: int = rng.randi_range(0, candidates.size() - 1)
		var cell: Vector2i = candidates[candidate_index]
		candidates.remove_at(candidate_index)
		_set_floor(cell.x, cell.y)
		carved += 1


func _carve_corridor(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var horizontal_first: bool = rng.randf() > 0.5
	if horizontal_first:
		_carve_horizontal(from_cell.x, to_cell.x, from_cell.y)
		_carve_vertical(from_cell.y, to_cell.y, to_cell.x)
	else:
		_carve_vertical(from_cell.y, to_cell.y, from_cell.x)
		_carve_horizontal(from_cell.x, to_cell.x, to_cell.y)


func _carve_horizontal(start_x: int, end_x: int, y: int) -> void:
	var left_x: int = mini(start_x, end_x)
	var right_x: int = maxi(start_x, end_x)
	for x in range(left_x, right_x + 1):
		for offset_y in range(-1, 2):
			_set_floor(x, y + offset_y)


func _carve_vertical(start_y: int, end_y: int, x: int) -> void:
	var top_y: int = mini(start_y, end_y)
	var bottom_y: int = maxi(start_y, end_y)
	for y in range(top_y, bottom_y + 1):
		for offset_x in range(-1, 2):
			_set_floor(x + offset_x, y)


func _set_floor(x: int, y: int) -> void:
	if x <= 0 or y <= 0 or x >= GRID_WIDTH - 1 or y >= GRID_HEIGHT - 1:
		return
	grid[y][x] = FLOOR_TILE


func _draw_dungeon() -> void:
	var background: Polygon2D = _make_rect_polygon(Rect2(Vector2.ZERO, dungeon_size), Color(0.045, 0.047, 0.052, 1.0))
	background.name = "DungeonVoid"
	floor_root.add_child(background)

	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var tile_position: Vector2 = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			if int(grid[y][x]) == FLOOR_TILE:
				_draw_floor_tile(tile_position, x, y)
			elif _is_near_floor(x, y):
				if _is_near_floor(x, y, 1):
					_draw_wall_tile(tile_position, x, y)
				else:
					_draw_outer_void_tile(tile_position)

	_draw_dungeon_decor()


func _draw_floor_tile(tile_position: Vector2, x: int, y: int) -> void:
	var shade: float = _cell_noise(x, y, 11) * 0.07 - 0.035
	var wall_neighbor_count: int = _count_wall_neighbors(x, y)
	var edge_darkness: float = float(wall_neighbor_count) * 0.018
	var base_color: Color = Color(0.33 + shade - edge_darkness, 0.32 + shade - edge_darkness, 0.29 + shade - edge_darkness, 1.0)
	var tile: Polygon2D = _make_rect_polygon(Rect2(tile_position, Vector2(TILE_SIZE, TILE_SIZE)), base_color)
	floor_root.add_child(tile)
	_draw_floor_tile_detail(tile_position, x, y)

	if wall_neighbor_count > 0:
		var edge_shadow: Polygon2D = _make_rect_polygon(Rect2(tile_position, Vector2(TILE_SIZE, TILE_SIZE)), Color(0.03, 0.032, 0.035, 0.055 * float(wall_neighbor_count)))
		floor_root.add_child(edge_shadow)


func _draw_outer_void_tile(tile_position: Vector2) -> void:
	var tile: Polygon2D = _make_rect_polygon(
		Rect2(tile_position, Vector2(TILE_SIZE, TILE_SIZE)),
		Color(0.045, 0.047, 0.052, 1.0)
	)
	floor_root.add_child(tile)


func _draw_wall_tile(tile_position: Vector2, x: int, y: int) -> void:
	var has_floor_below: bool = _has_floor_neighbor(x, y + 1)
	var has_floor_above: bool = _has_floor_neighbor(x, y - 1)
	var has_floor_left: bool = _has_floor_neighbor(x - 1, y)
	var has_floor_right: bool = _has_floor_neighbor(x + 1, y)
	var wall_above: bool = _is_wall_cell(x, y - 1)
	var wall_below: bool = _is_wall_cell(x, y + 1)
	var wall_left: bool = _is_wall_cell(x - 1, y)
	var wall_right: bool = _is_wall_cell(x + 1, y)

	if wall_right and wall_below and _has_floor_neighbor(x + 1, y + 1):
		_draw_outer_corner_wall_tile(tile_position, "top_left")
	elif wall_left and wall_below and _has_floor_neighbor(x - 1, y + 1):
		_draw_outer_corner_wall_tile(tile_position, "top_right")
	elif wall_right and wall_above and _has_floor_neighbor(x + 1, y - 1):
		_draw_outer_corner_wall_tile(tile_position, "bottom_left")
	elif wall_left and wall_above and _has_floor_neighbor(x - 1, y - 1):
		_draw_outer_corner_wall_tile(tile_position, "bottom_right")
	elif has_floor_below and (has_floor_left or has_floor_right):
		if has_floor_right:
			_draw_corner_wall_tile(tile_position, x, y, "top_left")
		else:
			_draw_corner_wall_tile(tile_position, x, y, "top_right")
	elif has_floor_above and (has_floor_left or has_floor_right):
		if has_floor_right:
			_draw_corner_wall_tile(tile_position, x, y, "bottom_left")
		else:
			_draw_corner_wall_tile(tile_position, x, y, "bottom_right")
	elif has_floor_below:
		_draw_front_wall_tile(tile_position, x, y)
	elif has_floor_above:
		_draw_back_wall_cap(tile_position, x, y)
	elif has_floor_left or has_floor_right:
		_draw_side_wall_tile(tile_position, x, y, has_floor_left, has_floor_right, false)
	else:
		var shade: float = _cell_noise(x, y, 53) * 0.04 - 0.02
		var wall: Polygon2D = _make_rect_polygon(Rect2(tile_position, Vector2(TILE_SIZE, TILE_SIZE)), Color(0.15 + shade, 0.145 + shade, 0.135 + shade, 1.0))
		wall_root.add_child(wall)


func _draw_floor_tile_detail(tile_position: Vector2, x: int, y: int) -> void:
	_draw_outer_wall_corner_trim(tile_position, x, y)
	var seam_alpha: float = 0.10
	var top_seam: Polygon2D = _make_rect_polygon(Rect2(tile_position, Vector2(TILE_SIZE, 1)), Color(0.11, 0.105, 0.095, seam_alpha))
	var left_seam: Polygon2D = _make_rect_polygon(Rect2(tile_position, Vector2(1, TILE_SIZE)), Color(0.11, 0.105, 0.095, seam_alpha))
	floor_root.add_child(top_seam)
	floor_root.add_child(left_seam)

	if _cell_chance(x, y, 71, 0.34):
		var crack: Polygon2D = Polygon2D.new()
		crack.position = tile_position
		crack.polygon = PackedVector2Array([
			Vector2(6 + int(_cell_noise(x, y, 72) * 4.0), 18),
			Vector2(15, 15 + int(_cell_noise(x, y, 73) * 3.0)),
			Vector2(25, 18),
			Vector2(24, 20),
			Vector2(16, 18),
			Vector2(8, 21)
		])
		crack.color = Color(0.12, 0.11, 0.10, 0.22)
		floor_root.add_child(crack)

	if _cell_chance(x, y, 81, 0.22):
		var moss_position: Vector2 = tile_position + Vector2(3 + int(_cell_noise(x, y, 82) * 20.0), 4 + int(_cell_noise(x, y, 83) * 18.0))
		var moss: Polygon2D = _make_ellipse_polygon(moss_position, Vector2(7, 3), Color(0.19, 0.27, 0.17, 0.30), 10)
		floor_root.add_child(moss)

	if _cell_chance(x, y, 91, 0.18):
		var worn_path: Polygon2D = _make_rect_polygon(
			Rect2(tile_position + Vector2(2, 13 + int(_cell_noise(x, y, 92) * 4.0)), Vector2(28, 5)),
			Color(0.42, 0.39, 0.32, 0.11)
		)
		floor_root.add_child(worn_path)

	for speck_index in range(2):
		if not _cell_chance(x, y, 100 + speck_index, 0.55):
			continue
		var speck_position: Vector2 = tile_position + Vector2(
			int(_cell_noise(x, y, 110 + speck_index) * 28.0) + 2,
			int(_cell_noise(x, y, 120 + speck_index) * 26.0) + 3
		)
		var speck: Polygon2D = _make_rect_polygon(Rect2(speck_position, Vector2(2, 1)), Color(0.50, 0.48, 0.40, 0.18))
		floor_root.add_child(speck)


func _draw_floor_corner_rounding(tile_position: Vector2, x: int, y: int) -> void:
	var void_color: Color = Color(0.045, 0.047, 0.052, 0.78)
	if not _has_floor_neighbor(x - 1, y) and not _has_floor_neighbor(x, y - 1):
		floor_root.add_child(_make_corner_rounding_polygon(tile_position, "top_left", void_color))
	if not _has_floor_neighbor(x + 1, y) and not _has_floor_neighbor(x, y - 1):
		floor_root.add_child(_make_corner_rounding_polygon(tile_position, "top_right", void_color))
	if not _has_floor_neighbor(x - 1, y) and not _has_floor_neighbor(x, y + 1):
		floor_root.add_child(_make_corner_rounding_polygon(tile_position, "bottom_left", void_color))
	if not _has_floor_neighbor(x + 1, y) and not _has_floor_neighbor(x, y + 1):
		floor_root.add_child(_make_corner_rounding_polygon(tile_position, "bottom_right", void_color))


func _draw_outer_wall_corner_trim(tile_position: Vector2, x: int, y: int) -> void:
	var top_wall: bool = _is_wall_cell(x, y - 1)
	var bottom_wall: bool = _is_wall_cell(x, y + 1)
	var left_wall: bool = _is_wall_cell(x - 1, y)
	var right_wall: bool = _is_wall_cell(x + 1, y)

	if top_wall and left_wall and not _is_wall_cell(x - 1, y - 1):
		_draw_outer_corner_trim_piece(tile_position, "top_left")
	if top_wall and right_wall and not _is_wall_cell(x + 1, y - 1):
		_draw_outer_corner_trim_piece(tile_position, "top_right")
	if bottom_wall and left_wall and not _is_wall_cell(x - 1, y + 1):
		_draw_outer_corner_trim_piece(tile_position, "bottom_left")
	if bottom_wall and right_wall and not _is_wall_cell(x + 1, y + 1):
		_draw_outer_corner_trim_piece(tile_position, "bottom_right")


func _draw_outer_corner_trim_piece(tile_position: Vector2, corner_kind: String) -> void:
	var cap_color: Color = Color(0.24, 0.235, 0.215, 0.95)
	var cap_edge_color: Color = Color(0.36, 0.33, 0.28, 0.40)
	var shadow_color: Color = Color(0.06, 0.055, 0.05, 0.42)
	var cap: Polygon2D = Polygon2D.new()
	cap.position = tile_position
	var edge: Polygon2D = Polygon2D.new()
	edge.position = tile_position
	var shadow: Polygon2D = Polygon2D.new()
	shadow.position = tile_position

	match corner_kind:
		"top_left":
			cap.polygon = PackedVector2Array([Vector2(0, 14), Vector2(0, 0), Vector2(14, 0), Vector2(10, 4), Vector2(4, 10)])
			edge.polygon = PackedVector2Array([Vector2(0, 9), Vector2(0, 0), Vector2(9, 0), Vector2(7, 2), Vector2(2, 7)])
			shadow.polygon = PackedVector2Array([Vector2(0, 16), Vector2(5, 10), Vector2(10, 5), Vector2(16, 0), Vector2(16, 4), Vector2(12, 8), Vector2(8, 12), Vector2(4, 16)])
		"top_right":
			cap.polygon = PackedVector2Array([Vector2(18, 0), Vector2(32, 0), Vector2(32, 14), Vector2(28, 10), Vector2(22, 4)])
			edge.polygon = PackedVector2Array([Vector2(23, 0), Vector2(32, 0), Vector2(32, 9), Vector2(30, 7), Vector2(25, 2)])
			shadow.polygon = PackedVector2Array([Vector2(16, 4), Vector2(20, 8), Vector2(24, 12), Vector2(28, 16), Vector2(32, 16), Vector2(32, 0), Vector2(26, 5), Vector2(21, 10)])
		"bottom_left":
			cap.polygon = PackedVector2Array([Vector2(0, 18), Vector2(4, 22), Vector2(10, 28), Vector2(14, 32), Vector2(0, 32)])
			edge.polygon = PackedVector2Array([Vector2(0, 23), Vector2(2, 25), Vector2(7, 30), Vector2(9, 32), Vector2(0, 32)])
			shadow.polygon = PackedVector2Array([Vector2(0, 28), Vector2(4, 24), Vector2(8, 20), Vector2(12, 16), Vector2(16, 16), Vector2(10, 22), Vector2(5, 27), Vector2(0, 32)])
		_:
			cap.polygon = PackedVector2Array([Vector2(32, 18), Vector2(32, 32), Vector2(18, 32), Vector2(22, 28), Vector2(28, 22)])
			edge.polygon = PackedVector2Array([Vector2(32, 23), Vector2(32, 32), Vector2(23, 32), Vector2(25, 30), Vector2(30, 25)])
			shadow.polygon = PackedVector2Array([Vector2(16, 16), Vector2(20, 16), Vector2(24, 20), Vector2(28, 24), Vector2(32, 28), Vector2(32, 32), Vector2(27, 27), Vector2(22, 22)])

	cap.color = cap_color
	edge.color = cap_edge_color
	shadow.color = shadow_color
	floor_root.add_child(cap)
	floor_root.add_child(edge)
	floor_root.add_child(shadow)


func _draw_front_wall_tile(tile_position: Vector2, x: int, y: int) -> void:
	var shade: float = _cell_noise(x, y, 201) * 0.05 - 0.025
	var face: Polygon2D = _make_rect_polygon(Rect2(tile_position + Vector2(0, 4), Vector2(TILE_SIZE, 24)), Color(0.24 + shade, 0.235 + shade, 0.215 + shade, 1.0))
	wall_root.add_child(face)
	_draw_wall_bricks(tile_position + Vector2(0, 5), x, y, 3, true)
	if _cell_chance(x, y, 230, 0.16):
		_draw_missing_brick(tile_position + Vector2(4 + int(_cell_noise(x, y, 231) * 16.0), 10 + int(_cell_noise(x, y, 232) * 8.0)), Vector2(10, 5))
	var cap: Polygon2D = _make_rect_polygon(Rect2(tile_position, Vector2(TILE_SIZE, 7)), Color(0.33, 0.31, 0.265, 1.0))
	var cap_edge: Polygon2D = _make_rect_polygon(Rect2(tile_position + Vector2(0, 7), Vector2(TILE_SIZE, 2)), Color(0.12, 0.105, 0.085, 0.35))
	var lip: Polygon2D = _make_rect_polygon(Rect2(tile_position + Vector2(0, 24), Vector2(TILE_SIZE, 8)), Color(0.135, 0.125, 0.115, 0.40))
	wall_root.add_child(cap)
	wall_root.add_child(cap_edge)
	wall_root.add_child(lip)


func _draw_back_wall_cap(tile_position: Vector2, x: int, y: int) -> void:
	var shade: float = _cell_noise(x, y, 251) * 0.04 - 0.02
	var top: Polygon2D = _make_rect_polygon(Rect2(tile_position, Vector2(TILE_SIZE, 8)), Color(0.29 + shade, 0.275 + shade, 0.24 + shade, 1.0))
	var edge: Polygon2D = _make_rect_polygon(Rect2(tile_position + Vector2(0, 8), Vector2(TILE_SIZE, 2)), Color(0.08, 0.075, 0.065, 0.22))
	var underside: Polygon2D = _make_rect_polygon(Rect2(tile_position + Vector2(0, 10), Vector2(TILE_SIZE, 3)), Color(0.16, 0.155, 0.14, 0.14))
	wall_root.add_child(top)
	wall_root.add_child(edge)
	wall_root.add_child(underside)
	_draw_wall_bricks(tile_position + Vector2(0, 1), x, y, 1, false)


func _draw_outer_corner_wall_tile(tile_position: Vector2, corner_kind: String) -> void:
	match corner_kind:
		"top_left":
			_draw_sidewall_segment(tile_position, 0, 0, true, 7.0, 25.0, true)
			_draw_outer_corner_cap_block(tile_position, true, true)
		"top_right":
			_draw_sidewall_segment(tile_position, 0, 0, false, 7.0, 25.0, true)
			_draw_outer_corner_cap_block(tile_position, false, true)
		"bottom_left":
			_draw_outer_corner_cap_block(tile_position, true, false)
		_:
			_draw_outer_corner_cap_block(tile_position, false, false)


func _draw_outer_corner_cap_block(tile_position: Vector2, on_right: bool, top_corner: bool) -> void:
	var block_x: float = 24.0 if on_right else 0.0
	var block_y: float = 0.0
	var cap_height: float = 7.0 if top_corner else 8.0
	var cap_color: Color = Color(0.33, 0.31, 0.265, 1.0) if top_corner else Color(0.29, 0.275, 0.24, 1.0)
	var edge_color: Color = Color(0.12, 0.105, 0.085, 0.35) if top_corner else Color(0.08, 0.075, 0.065, 0.22)
	var block: Polygon2D = _make_rect_polygon(
		Rect2(tile_position + Vector2(block_x, block_y), Vector2(8, cap_height)),
		cap_color
	)
	var edge: Polygon2D = _make_rect_polygon(
		Rect2(tile_position + Vector2(block_x, block_y + cap_height), Vector2(8, 1 if top_corner else 2)),
		edge_color
	)
	wall_root.add_child(block)
	wall_root.add_child(edge)


func _draw_side_wall_tile(tile_position: Vector2, x: int, y: int, has_floor_left: bool, has_floor_right: bool, suppress_top_cap: bool) -> void:
	var shade: float = _cell_noise(x, y, 271) * 0.05 - 0.025
	var on_left_edge: bool = has_floor_right
	var strip_x: float = 24.0 if on_left_edge else 0.0
	var strip_y: float = 7.0 if suppress_top_cap else 0.0
	var strip_height: float = TILE_SIZE - strip_y
	var strip: Polygon2D = _make_rect_polygon(Rect2(tile_position + Vector2(strip_x, strip_y), Vector2(8, strip_height)), Color(0.29 + shade, 0.275 + shade, 0.24 + shade, 1.0))
	var strip_inner_shadow_x: float = strip_x + (6.0 if on_left_edge else 0.0)
	var strip_inner_shadow: Polygon2D = _make_rect_polygon(Rect2(tile_position + Vector2(strip_inner_shadow_x, strip_y), Vector2(2, strip_height)), Color(0.06, 0.055, 0.05, 0.22))
	var strip_outer_rim_x: float = strip_x + (0.0 if on_left_edge else 7.0)
	var strip_outer_rim: Polygon2D = _make_rect_polygon(Rect2(tile_position + Vector2(strip_outer_rim_x, strip_y), Vector2(1, strip_height)), Color(0.42, 0.39, 0.32, 0.18))
	wall_root.add_child(strip)
	wall_root.add_child(strip_inner_shadow)
	wall_root.add_child(strip_outer_rim)
	if not suppress_top_cap and not _is_wall_cell(x, y - 1):
		var cap: Polygon2D = _make_rect_polygon(Rect2(tile_position + Vector2(strip_x - 1, 0), Vector2(10, 6)), Color(0.32, 0.30, 0.255, 1.0))
		var cap_edge: Polygon2D = _make_rect_polygon(Rect2(tile_position + Vector2(strip_x - 1, 6), Vector2(10, 1)), Color(0.10, 0.09, 0.075, 0.25))
		wall_root.add_child(cap)
		wall_root.add_child(cap_edge)
	if not _is_wall_cell(x, y + 1):
		var base_shadow: Polygon2D = _make_rect_polygon(Rect2(tile_position + Vector2(strip_x, 28), Vector2(8, 4)), Color(0.08, 0.075, 0.065, 0.22))
		wall_root.add_child(base_shadow)
	for seam_y in [8.0, 16.0, 24.0]:
		if seam_y <= strip_y:
			continue
		var seam: Polygon2D = _make_rect_polygon(Rect2(tile_position + Vector2(strip_x + 1, seam_y), Vector2(6, 1)), Color(0.41, 0.39, 0.34, 0.10))
		wall_root.add_child(seam)


func _draw_corner_wall_tile(tile_position: Vector2, x: int, y: int, corner_kind: String) -> void:
	match corner_kind:
		"top_left":
			_draw_front_corner_piece(tile_position, x, y, false)
		"top_right":
			_draw_front_corner_piece(tile_position, x, y, true)
		"bottom_left":
			_draw_back_corner_piece(tile_position, x, y, true)
		_:
			_draw_back_corner_piece(tile_position, x, y, false)


func _draw_front_corner_piece(tile_position: Vector2, x: int, y: int, strip_on_right: bool) -> void:
	_draw_front_wall_tile(tile_position, x, y)


func _draw_back_corner_piece(tile_position: Vector2, x: int, y: int, strip_on_right: bool) -> void:
	_draw_back_wall_cap(tile_position, x, y)
	_draw_sidewall_segment(tile_position, x, y, strip_on_right, 8.0, 2.0, false)
	_draw_corner_vertical_return(tile_position, x, y, strip_on_right, 10.0, false)


func _draw_corner_vertical_return(tile_position: Vector2, x: int, y: int, strip_on_right: bool, start_y: float, front_corner: bool) -> void:
	var shade: float = _cell_noise(x, y, 481 if front_corner else 482) * 0.05 - 0.025
	var strip_x: float = 24.0 if strip_on_right else 0.0
	var strip_height: float = TILE_SIZE - start_y
	var strip_rect: Rect2 = Rect2(tile_position + Vector2(strip_x, start_y), Vector2(8, strip_height))
	_draw_sidewall_segment(tile_position, x, y, strip_on_right, start_y, strip_height, front_corner)

	if not _is_wall_cell(x, y + 1):
		var base_shadow: Polygon2D = _make_rect_polygon(
			Rect2(tile_position + Vector2(strip_x, 28), Vector2(8, 4)),
			Color(0.08, 0.075, 0.065, 0.22)
		)
		wall_root.add_child(base_shadow)

	_draw_vertical_wall_bricks(strip_rect, x, y, strip_on_right)


func _draw_sidewall_segment(tile_position: Vector2, x: int, y: int, strip_on_right: bool, start_y: float, height: float, front_corner: bool) -> void:
	var shade_salt: int = 481 if front_corner else 482
	var shade: float = _cell_noise(x, y, shade_salt) * 0.05 - 0.025
	var strip_x: float = 24.0 if strip_on_right else 0.0
	var strip: Polygon2D = _make_rect_polygon(
		Rect2(tile_position + Vector2(strip_x, start_y), Vector2(8, height)),
		Color(0.29 + shade, 0.275 + shade, 0.24 + shade, 1.0)
	)
	var strip_inner_shadow_x: float = strip_x + (6.0 if strip_on_right else 0.0)
	var strip_inner_shadow: Polygon2D = _make_rect_polygon(
		Rect2(tile_position + Vector2(strip_inner_shadow_x, start_y), Vector2(2, height)),
		Color(0.06, 0.055, 0.05, 0.22)
	)
	var strip_outer_rim_x: float = strip_x + (0.0 if strip_on_right else 7.0)
	var strip_outer_rim: Polygon2D = _make_rect_polygon(
		Rect2(tile_position + Vector2(strip_outer_rim_x, start_y), Vector2(1, height)),
		Color(0.42, 0.39, 0.32, 0.18)
	)
	wall_root.add_child(strip)
	wall_root.add_child(strip_inner_shadow)
	wall_root.add_child(strip_outer_rim)


func _draw_vertical_wall_bricks(strip_rect: Rect2, x: int, y: int, strip_on_right: bool) -> void:
	var column_x: float = strip_rect.position.x + (1.0 if strip_on_right else 2.0)
	for brick_y in range(int(strip_rect.position.y) + 4, int(strip_rect.end.y) - 2, 7):
		var seam: Polygon2D = _make_rect_polygon(
			Rect2(Vector2(column_x, brick_y), Vector2(5, 1)),
			Color(0.43, 0.405, 0.34, 0.16)
		)
		var mortar_x: float = column_x + (3.0 if strip_on_right else 1.0)
		var mortar: Polygon2D = _make_rect_polygon(
			Rect2(Vector2(mortar_x, brick_y + 1), Vector2(1, 4)),
			Color(0.08, 0.075, 0.065, 0.12)
		)
		wall_root.add_child(seam)
		wall_root.add_child(mortar)


func _draw_wall_bricks_in_rect(brick_rect: Rect2, x: int, y: int, row_count: int, staggered: bool) -> void:
	for row_index in range(row_count):
		var row_y: float = brick_rect.position.y + float(row_index * 7)
		var offset_x: int = 0 if not staggered or row_index % 2 == 0 else 6
		for local_x in range(-offset_x, int(brick_rect.size.x), 12):
			var brick_width: int = min(10 + int(_cell_noise(x + local_x, y + row_index, 341) * 4.0), int(brick_rect.end.x - (brick_rect.position.x + local_x + offset_x)))
			if brick_width <= 2:
				continue
			var brick_position: Vector2 = Vector2(brick_rect.position.x + local_x + offset_x, row_y)
			var brick: Polygon2D = _make_rect_polygon(
				Rect2(brick_position, Vector2(brick_width, 1)),
				Color(0.43, 0.405, 0.34, 0.20)
			)
			wall_root.add_child(brick)
			var mortar_x: float = brick_position.x + brick_width
			if mortar_x < brick_rect.end.x - 1.0:
				var mortar: Polygon2D = _make_rect_polygon(
					Rect2(Vector2(mortar_x, row_y + 1), Vector2(1, 5)),
					Color(0.08, 0.075, 0.065, 0.14)
				)
				wall_root.add_child(mortar)


func _draw_wall_bricks(origin: Vector2, x: int, y: int, row_count: int, staggered: bool) -> void:
	for row_index in range(row_count):
		var row_y: float = origin.y + float(row_index * 7)
		var offset_x: int = 0 if not staggered or row_index % 2 == 0 else 6
		for brick_x in range(-offset_x, TILE_SIZE, 12):
			var brick_width: int = 10 + int(_cell_noise(x + brick_x, y + row_index, 301) * 4.0)
			var brick: Polygon2D = _make_rect_polygon(
				Rect2(Vector2(origin.x + brick_x + offset_x, row_y), Vector2(brick_width, 1)),
				Color(0.43, 0.405, 0.34, 0.20)
			)
			wall_root.add_child(brick)
			var mortar: Polygon2D = _make_rect_polygon(
				Rect2(Vector2(origin.x + brick_x + offset_x + brick_width, row_y + 1), Vector2(1, 5)),
				Color(0.08, 0.075, 0.065, 0.14)
			)
			wall_root.add_child(mortar)


func _draw_missing_brick(position: Vector2, size: Vector2) -> void:
	var hole: Polygon2D = _make_rect_polygon(Rect2(position, size), Color(0.045, 0.04, 0.035, 0.80))
	var highlight: Polygon2D = _make_rect_polygon(Rect2(position, Vector2(size.x, 1)), Color(0.45, 0.42, 0.33, 0.22))
	wall_root.add_child(hole)
	wall_root.add_child(highlight)


func _draw_dungeon_decor() -> void:
	_draw_room_specials()
	_draw_doorways()
	_draw_wall_torches()
	_draw_floor_props()


func _draw_room_specials() -> void:
	if rooms.is_empty():
		return
	var spawn_room: Rect2i = rooms[0]
	var end_room: Rect2i = _find_longest_route_room_from(spawn_room)
	_draw_special_room_marker(end_room)


func _draw_special_room_marker(room: Rect2i) -> void:
	var center: Vector2 = _cell_to_world(_room_center(room))
	var glow: Polygon2D = _make_ellipse_polygon(center, Vector2(82, 54), Color(0.42, 0.24, 0.12, 0.20), 28)
	decor_root.add_child(glow)
	var ring: Polygon2D = _make_ellipse_polygon(center, Vector2(34, 20), Color(0.12, 0.095, 0.075, 0.48), 18)
	decor_root.add_child(ring)
	var altar: Polygon2D = _make_rect_polygon(Rect2(center + Vector2(-18, -8), Vector2(36, 16)), Color(0.18, 0.14, 0.11, 0.96))
	decor_root.add_child(altar)
	var altar_top: Polygon2D = _make_rect_polygon(Rect2(center + Vector2(-15, -11), Vector2(30, 5)), Color(0.36, 0.28, 0.18, 0.96))
	decor_root.add_child(altar_top)


func _draw_doorways() -> void:
	var door_candidates: Array[Vector2i] = []
	for y in range(2, GRID_HEIGHT - 2):
		for x in range(2, GRID_WIDTH - 2):
			if int(grid[y][x]) != FLOOR_TILE:
				continue
			var horizontal_passage: bool = int(grid[y][x - 1]) == FLOOR_TILE and int(grid[y][x + 1]) == FLOOR_TILE and int(grid[y - 1][x]) == WALL_TILE and int(grid[y + 1][x]) == WALL_TILE
			var vertical_passage: bool = int(grid[y - 1][x]) == FLOOR_TILE and int(grid[y + 1][x]) == FLOOR_TILE and int(grid[y][x - 1]) == WALL_TILE and int(grid[y][x + 1]) == WALL_TILE
			if horizontal_passage or vertical_passage:
				door_candidates.append(Vector2i(x, y))

	var placed: int = 0
	for candidate in door_candidates:
		if placed >= 8:
			return
		if rng.randf() > 0.22:
			continue
		_draw_doorway(candidate)
		placed += 1


func _draw_doorway(cell: Vector2i) -> void:
	var world_position: Vector2 = Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)
	var horizontal_passage: bool = int(grid[cell.y][cell.x - 1]) == FLOOR_TILE and int(grid[cell.y][cell.x + 1]) == FLOOR_TILE
	if horizontal_passage:
		var top_beam: Polygon2D = _make_rect_polygon(Rect2(world_position + Vector2(0, 2), Vector2(TILE_SIZE, 6)), Color(0.11, 0.075, 0.045, 0.92))
		var bottom_beam: Polygon2D = _make_rect_polygon(Rect2(world_position + Vector2(0, 24), Vector2(TILE_SIZE, 6)), Color(0.11, 0.075, 0.045, 0.92))
		decor_root.add_child(top_beam)
		decor_root.add_child(bottom_beam)
	else:
		var left_beam: Polygon2D = _make_rect_polygon(Rect2(world_position + Vector2(2, 0), Vector2(6, TILE_SIZE)), Color(0.11, 0.075, 0.045, 0.92))
		var right_beam: Polygon2D = _make_rect_polygon(Rect2(world_position + Vector2(24, 0), Vector2(6, TILE_SIZE)), Color(0.11, 0.075, 0.045, 0.92))
		decor_root.add_child(left_beam)
		decor_root.add_child(right_beam)


func _draw_wall_torches() -> void:
	var torch_candidates: Array[Vector2i] = []
	for y in range(2, GRID_HEIGHT - 2):
		for x in range(2, GRID_WIDTH - 2):
			if int(grid[y][x]) != WALL_TILE:
				continue
			if _has_floor_neighbor(x, y + 1):
				torch_candidates.append(Vector2i(x, y))

	var torch_budget: int = mini(12 + depth, maxi(3, rooms.size()))
	var placed: int = 0
	while placed < torch_budget and not torch_candidates.is_empty():
		var candidate_index: int = rng.randi_range(0, torch_candidates.size() - 1)
		var cell: Vector2i = torch_candidates[candidate_index]
		torch_candidates.remove_at(candidate_index)
		if not _is_far_from_existing_decor(cell, 5):
			continue
		_draw_torch(cell)
		decor_cells.append(cell)
		placed += 1


func _draw_torch(cell: Vector2i) -> void:
	var center: Vector2 = _cell_to_world(cell) + Vector2(0, -5)
	_draw_torch_light(cell, center)
	var backplate: Polygon2D = _make_rect_polygon(Rect2(center + Vector2(-4, -7), Vector2(8, 13)), Color(0.10, 0.07, 0.045, 0.88))
	decor_root.add_child(backplate)
	var wall_pin: Polygon2D = _make_rect_polygon(Rect2(center + Vector2(-2, -3), Vector2(4, 8)), Color(0.18, 0.13, 0.08, 1.0))
	decor_root.add_child(wall_pin)
	var handle: Polygon2D = Polygon2D.new()
	handle.polygon = PackedVector2Array([
		center + Vector2(-1, 2),
		center + Vector2(3, 2),
		center + Vector2(5, 12),
		center + Vector2(1, 12)
	])
	handle.color = Color(0.11, 0.07, 0.04, 1.0)
	decor_root.add_child(handle)
	var flame: Polygon2D = Polygon2D.new()
	flame.polygon = PackedVector2Array([
		center + Vector2(0, -13),
		center + Vector2(5, -5),
		center + Vector2(1, 0),
		center + Vector2(-4, -5)
	])
	flame.color = Color(1.0, 0.58, 0.18, 0.95)
	decor_root.add_child(flame)
	var flame_core: Polygon2D = Polygon2D.new()
	flame_core.polygon = PackedVector2Array([
		center + Vector2(0, -9),
		center + Vector2(2, -5),
		center + Vector2(0, -2),
		center + Vector2(-2, -5)
	])
	flame_core.color = Color(1.0, 0.88, 0.40, 0.95)
	decor_root.add_child(flame_core)


func _draw_torch_light(wall_cell: Vector2i, center: Vector2) -> void:
	for offset_y in range(-1, 5):
		for offset_x in range(-4, 5):
			var cell: Vector2i = wall_cell + Vector2i(offset_x, offset_y)
			if not _is_visible_dungeon_cell(cell.x, cell.y):
				continue
			var cell_center: Vector2 = _cell_to_world(cell)
			var normalized_distance: float = Vector2((cell_center.x - center.x) / 132.0, (cell_center.y - center.y) / 82.0).length()
			if normalized_distance > 1.0:
				continue
			var alpha: float = pow(1.0 - normalized_distance, 1.75) * 0.18
			if offset_y < 0:
				alpha *= 0.65
			var glow_tile: Polygon2D = _make_rect_polygon(
				Rect2(Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE)),
				Color(1.0, 0.52, 0.18, alpha)
			)
			decor_root.add_child(glow_tile)


func _draw_floor_props() -> void:
	var prop_budget: int = 18 + rooms.size()
	var placed: int = 0
	var attempts: int = 0
	while placed < prop_budget and attempts < prop_budget * 8:
		attempts += 1
		var room: Rect2i = rooms[rng.randi_range(0, rooms.size() - 1)]
		if room.size.x < 5 or room.size.y < 4:
			continue
		var cell: Vector2i = Vector2i(
			rng.randi_range(room.position.x + 1, room.position.x + room.size.x - 2),
			rng.randi_range(room.position.y + 1, room.position.y + room.size.y - 2)
		)
		if not _can_place_decor_on_floor(cell):
			continue
		var prop_roll: float = rng.randf()
		if prop_roll < 0.36:
			_draw_rubble(cell)
		elif prop_roll < 0.68:
			_draw_bones(cell)
		else:
			_draw_barrel(cell)
		decor_cells.append(cell)
		placed += 1


func _draw_rubble(cell: Vector2i) -> void:
	var origin: Vector2 = _cell_to_world(cell)
	var dust: Polygon2D = _make_ellipse_polygon(origin + Vector2(0, 4), Vector2(18, 8), Color(0.08, 0.075, 0.065, 0.20), 16)
	decor_root.add_child(dust)
	for rock_index in range(rng.randi_range(3, 6)):
		var rock_center: Vector2 = origin + Vector2(rng.randi_range(-11, 11), rng.randi_range(-7, 9))
		var rock_size: Vector2 = Vector2(rng.randi_range(4, 9), rng.randi_range(3, 7))
		var rock: Polygon2D = _make_rough_stone_polygon(rock_center, rock_size, Color(0.20, 0.19, 0.17, rng.randf_range(0.75, 0.95)))
		decor_root.add_child(rock)


func _draw_bones(cell: Vector2i) -> void:
	var origin: Vector2 = _cell_to_world(cell)
	var shadow: Polygon2D = _make_ellipse_polygon(origin + Vector2(0, 7), Vector2(20, 8), Color(0.02, 0.02, 0.018, 0.24), 18)
	decor_root.add_child(shadow)
	_draw_skull(origin + Vector2(-8, -4))
	_draw_rib_cage(origin + Vector2(8, 1))
	_draw_long_bone(origin + Vector2(-10, 9), -0.18, 23)


func _draw_skull(center: Vector2) -> void:
	var skull_back: Polygon2D = _make_ellipse_polygon(center, Vector2(9, 8), Color(0.70, 0.66, 0.54, 0.95), 14)
	decor_root.add_child(skull_back)
	var jaw: Polygon2D = _make_rect_polygon(Rect2(center + Vector2(-6, 4), Vector2(12, 7)), Color(0.62, 0.58, 0.48, 0.95))
	decor_root.add_child(jaw)
	var left_eye: Polygon2D = _make_rect_polygon(Rect2(center + Vector2(-5, -2), Vector2(3, 3)), Color(0.035, 0.03, 0.025, 0.88))
	var right_eye: Polygon2D = _make_rect_polygon(Rect2(center + Vector2(2, -2), Vector2(3, 3)), Color(0.035, 0.03, 0.025, 0.88))
	var nose: Polygon2D = _make_rect_polygon(Rect2(center + Vector2(-1, 2), Vector2(3, 3)), Color(0.055, 0.045, 0.035, 0.82))
	decor_root.add_child(left_eye)
	decor_root.add_child(right_eye)
	decor_root.add_child(nose)
	for tooth_index in range(4):
		var tooth: Polygon2D = _make_rect_polygon(Rect2(center + Vector2(-5 + tooth_index * 3, 8), Vector2(1, 3)), Color(0.82, 0.78, 0.64, 0.78))
		decor_root.add_child(tooth)


func _draw_long_bone(start_position: Vector2, rotation_value: float, length: int) -> void:
	var root: Node2D = Node2D.new()
	root.position = start_position
	root.rotation = rotation_value
	decor_root.add_child(root)
	var shaft: Polygon2D = _make_rect_polygon(Rect2(Vector2(0, -2), Vector2(length, 4)), Color(0.69, 0.65, 0.54, 0.90))
	root.add_child(shaft)
	var left_knob: Polygon2D = _make_ellipse_polygon(Vector2(0, 0), Vector2(4, 4), Color(0.76, 0.72, 0.59, 0.92), 10)
	var right_knob: Polygon2D = _make_ellipse_polygon(Vector2(length, 0), Vector2(4, 4), Color(0.76, 0.72, 0.59, 0.92), 10)
	root.add_child(left_knob)
	root.add_child(right_knob)
	var highlight: Polygon2D = _make_rect_polygon(Rect2(Vector2(3, -2), Vector2(length - 6, 1)), Color(0.90, 0.85, 0.66, 0.38))
	root.add_child(highlight)


func _draw_rib_cage(center: Vector2) -> void:
	var root: Node2D = Node2D.new()
	root.position = center
	root.rotation = rng.randf_range(-0.18, 0.18)
	decor_root.add_child(root)

	var spine: Polygon2D = _make_rect_polygon(Rect2(Vector2(-1, -7), Vector2(2, 14)), Color(0.54, 0.50, 0.42, 0.82))
	root.add_child(spine)
	for rib_index in range(3):
		var y_offset: int = -5 + rib_index * 4
		var width: int = 8 - rib_index
		var left_rib: Polygon2D = Polygon2D.new()
		left_rib.polygon = PackedVector2Array([
			Vector2(-1, y_offset),
			Vector2(-width, y_offset + 1),
			Vector2(-width - 1, y_offset + 4),
			Vector2(-width + 1, y_offset + 4),
			Vector2(-2, y_offset + 2)
		])
		left_rib.color = Color(0.66, 0.62, 0.51, 0.86)
		root.add_child(left_rib)

		var right_rib: Polygon2D = Polygon2D.new()
		right_rib.polygon = PackedVector2Array([
			Vector2(1, y_offset),
			Vector2(width, y_offset + 1),
			Vector2(width + 1, y_offset + 4),
			Vector2(width - 1, y_offset + 4),
			Vector2(2, y_offset + 2)
		])
		right_rib.color = Color(0.66, 0.62, 0.51, 0.86)
		root.add_child(right_rib)


func _draw_barrel(cell: Vector2i) -> void:
	var origin: Vector2 = _cell_to_world(cell)
	var shadow: Polygon2D = _make_ellipse_polygon(origin + Vector2(0, 11), Vector2(17, 6), Color(0.02, 0.018, 0.014, 0.30), 18)
	decor_root.add_child(shadow)

	var body: Polygon2D = Polygon2D.new()
	body.polygon = PackedVector2Array([
		origin + Vector2(-12, -8),
		origin + Vector2(12, -8),
		origin + Vector2(10, 12),
		origin + Vector2(-10, 12)
	])
	body.color = Color(0.34, 0.19, 0.09, 1.0)
	decor_root.add_child(body)

	var left_shade: Polygon2D = Polygon2D.new()
	left_shade.polygon = PackedVector2Array([
		origin + Vector2(-12, -7),
		origin + Vector2(-5, -8),
		origin + Vector2(-5, 12),
		origin + Vector2(-10, 12)
	])
	left_shade.color = Color(0.20, 0.11, 0.055, 0.78)
	decor_root.add_child(left_shade)

	var right_highlight: Polygon2D = Polygon2D.new()
	right_highlight.polygon = PackedVector2Array([
		origin + Vector2(5, -8),
		origin + Vector2(11, -7),
		origin + Vector2(9, 11),
		origin + Vector2(4, 12)
	])
	right_highlight.color = Color(0.48, 0.29, 0.13, 0.55)
	decor_root.add_child(right_highlight)

	var top: Polygon2D = _make_ellipse_polygon(origin + Vector2(0, -8), Vector2(13, 6), Color(0.43, 0.26, 0.13, 1.0), 18)
	decor_root.add_child(top)
	var top_inner: Polygon2D = _make_ellipse_polygon(origin + Vector2(0, -8), Vector2(8, 3), Color(0.26, 0.14, 0.065, 0.85), 16)
	decor_root.add_child(top_inner)

	for band_y in [-3, 7]:
		var band: Polygon2D = _make_rect_polygon(Rect2(origin + Vector2(-11, band_y), Vector2(22, 3)), Color(0.105, 0.095, 0.080, 0.92))
		decor_root.add_child(band)

	for stave_x in [-5, 0, 5]:
		var stave: Polygon2D = _make_rect_polygon(Rect2(origin + Vector2(stave_x, -6), Vector2(1, 17)), Color(0.16, 0.08, 0.035, 0.42))
		decor_root.add_child(stave)

	var rim: Polygon2D = _make_ellipse_polygon(origin + Vector2(0, -8), Vector2(13, 6), Color(0.12, 0.09, 0.06, 0.22), 18)
	decor_root.add_child(rim)


func _make_rough_stone_polygon(center: Vector2, size: Vector2, color: Color) -> Polygon2D:
	var half_size: Vector2 = size * 0.5
	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		center + Vector2(-half_size.x, -half_size.y * 0.45),
		center + Vector2(-half_size.x * 0.45, -half_size.y),
		center + Vector2(half_size.x * 0.75, -half_size.y * 0.75),
		center + Vector2(half_size.x, half_size.y * 0.10),
		center + Vector2(half_size.x * 0.35, half_size.y),
		center + Vector2(-half_size.x * 0.80, half_size.y * 0.65)
	])
	polygon.color = color
	return polygon


func _can_place_decor_on_floor(cell: Vector2i) -> bool:
	if cell.x <= 1 or cell.y <= 1 or cell.x >= GRID_WIDTH - 2 or cell.y >= GRID_HEIGHT - 2:
		return false
	if int(grid[cell.y][cell.x]) != FLOOR_TILE:
		return false
	return _count_wall_neighbors(cell.x, cell.y) <= 1


func _is_far_from_existing_decor(cell: Vector2i, minimum_distance: int) -> bool:
	for existing_cell in decor_cells:
		if abs(existing_cell.x - cell.x) + abs(existing_cell.y - cell.y) < minimum_distance:
			return false
	return true


func _count_wall_neighbors(x: int, y: int) -> int:
	var count: int = 0
	for direction in ORTHOGONAL_DIRECTIONS:
		var neighbor: Vector2i = Vector2i(x, y) + direction
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= GRID_WIDTH or neighbor.y >= GRID_HEIGHT:
			continue
		if int(grid[neighbor.y][neighbor.x]) == WALL_TILE:
			count += 1
	return count


func _make_rect_polygon(rect: Rect2, color: Color) -> Polygon2D:
	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y)
	])
	polygon.color = color
	return polygon


func _make_ellipse_polygon(center: Vector2, radius: Vector2, color: Color, point_count: int = 24) -> Polygon2D:
	var polygon: Polygon2D = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(point_count):
		var angle: float = TAU * float(index) / float(point_count)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	polygon.polygon = points
	polygon.color = color
	return polygon


func _make_corner_rounding_polygon(tile_position: Vector2, corner: String, color: Color) -> Polygon2D:
	var polygon: Polygon2D = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	var radius: float = 13.0
	var center: Vector2
	var start_angle: float
	var end_angle: float
	match corner:
		"top_left":
			center = tile_position + Vector2(radius, radius)
			start_angle = PI
			end_angle = PI * 1.5
			points.append(tile_position)
			points.append(tile_position + Vector2(radius, 0))
		"top_right":
			center = tile_position + Vector2(TILE_SIZE - radius, radius)
			start_angle = PI * 1.5
			end_angle = TAU
			points.append(tile_position + Vector2(TILE_SIZE, 0))
			points.append(tile_position + Vector2(TILE_SIZE, radius))
		"bottom_left":
			center = tile_position + Vector2(radius, TILE_SIZE - radius)
			start_angle = PI * 0.5
			end_angle = PI
			points.append(tile_position + Vector2(0, TILE_SIZE))
			points.append(tile_position + Vector2(0, TILE_SIZE - radius))
		_:
			center = tile_position + Vector2(TILE_SIZE - radius, TILE_SIZE - radius)
			start_angle = 0.0
			end_angle = PI * 0.5
			points.append(tile_position + Vector2(TILE_SIZE, TILE_SIZE))
			points.append(tile_position + Vector2(TILE_SIZE - radius, TILE_SIZE))

	var steps: int = 8
	for step in range(steps + 1):
		var amount: float = float(step) / float(steps)
		var angle: float = lerpf(start_angle, end_angle, amount)
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius))
	polygon.polygon = points
	polygon.color = color
	return polygon


func _cell_noise(x: int, y: int, salt: int) -> float:
	var value: int = int(abs((x * 73856093) ^ (y * 19349663) ^ (depth * 83492791) ^ (salt * 2654435761)))
	value = (value ^ (value >> 13)) * 1274126177
	value = value ^ (value >> 16)
	return float(value & 65535) / 65535.0


func _cell_chance(x: int, y: int, salt: int, chance: float) -> bool:
	return _cell_noise(x, y, salt) < chance


func _is_near_floor(x: int, y: int, radius: int = 2) -> bool:
	for offset_y in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			if _has_floor_neighbor(x + offset_x, y + offset_y):
				return true
	return false


func _has_floor_neighbor(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= GRID_WIDTH or y >= GRID_HEIGHT:
		return false
	return int(grid[y][x]) == FLOOR_TILE


func _is_visible_dungeon_cell(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= GRID_WIDTH or y >= GRID_HEIGHT:
		return false
	return int(grid[y][x]) == FLOOR_TILE or _is_near_floor(x, y)


func _build_wall_collision() -> void:
	for y in range(GRID_HEIGHT):
		var run_start: int = -1
		for x in range(GRID_WIDTH):
			var should_collide: bool = int(grid[y][x]) != FLOOR_TILE and _is_near_floor(x, y)
			if should_collide and run_start < 0:
				run_start = x
			if (not should_collide or x == GRID_WIDTH - 1) and run_start >= 0:
				var run_end: int = x - 1 if not should_collide else x
				_add_collision_run(run_start, run_end, y)
				run_start = -1


func _add_collision_run(start_x: int, end_x: int, y: int) -> void:
	var width: int = end_x - start_x + 1
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(width * TILE_SIZE, TILE_SIZE)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(start_x * TILE_SIZE + width * TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
	collision_body.add_child(collision)


func _spawn_gameplay() -> void:
	if rooms.is_empty():
		return

	var spawn_room: Rect2i = rooms[0]
	var stairs_room: Rect2i = _find_longest_route_room_from(spawn_room)
	var down_stairs_cell: Vector2i = _room_center(stairs_room)
	var up_stairs_cell: Vector2i = _room_cell_with_offset(spawn_room, Vector2i(2, 0))
	var player_spawn_cell: Vector2i = _get_player_spawn_cell(spawn_room, up_stairs_cell, down_stairs_cell)
	player = PlayerScene.instantiate()
	player.global_position = _cell_to_world(player_spawn_cell)
	gameplay_root.add_child(player)
	player.attack_requested.connect(_on_player_attack_requested)
	player.interacted.connect(_on_player_interacted)
	if player.has_signal("context_action_requested"):
		player.context_action_requested.connect(_perform_context_action)

	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera2D"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(dungeon_size.x)
	camera.limit_bottom = int(dungeon_size.y)
	camera.zoom = Vector2(1.05, 1.05)
	player.add_child(camera)
	camera.make_current()

	var stairs: Node2D = StairsScene.instantiate()
	stairs.global_position = _cell_to_world(down_stairs_cell)
	stairs.set("target_depth", depth + 1)
	stairs.set("speaker_name", "Stairs Down")
	gameplay_root.add_child(stairs)

	var upstairs: Node2D = StairsScene.instantiate()
	upstairs.global_position = _cell_to_world(up_stairs_cell)
	upstairs.set("target_depth", depth - 1)
	upstairs.set("speaker_name", "Stairs Up")
	gameplay_root.add_child(upstairs)

	_spawn_chests()
	_spawn_enemies()
	_spawn_mobile_controls()


func _spawn_chests() -> void:
	var chest_count: int = mini(2, maxi(0, rooms.size() - 2))
	for chest_index in range(chest_count):
		var room_index: int = rooms.size() - 2 - chest_index
		var room: Rect2i = rooms[room_index]
		var chest: Node2D = ChestScene.instantiate()
		chest.global_position = _cell_to_world(Vector2i(room.position.x + 1, room.position.y + 1))
		chest.set("chest_id", "depth_%d_chest_%d" % [depth, chest_index])
		chest.set("speaker_name", "Old Dungeon Chest")
		chest.set("item_name", "Minor Potion" if depth > 1 else "Trail Ration")
		chest.set("item_kind", "consumable")
		chest.set("closed_message", "Dusty hinges creak. Something useful is inside.")
		gameplay_root.add_child(chest)


func _spawn_enemies() -> void:
	var enemy_counter: int = 0
	for room_index in range(1, rooms.size() - 1):
		var room: Rect2i = rooms[room_index]
		var enemies_in_room: int = 1 + int(depth > 1 and rng.randf() > 0.45)
		for enemy_index in range(enemies_in_room):
			enemy_counter += 1
			var enemy: Node2D = RatScene.instantiate()
			var spawn_x: int = rng.randi_range(room.position.x + 1, room.position.x + room.size.x - 2)
			var spawn_y: int = rng.randi_range(room.position.y + 1, room.position.y + room.size.y - 2)
			var enemy_rarity: String = _roll_enemy_rarity()
			var rarity_stats: Dictionary = _get_enemy_rarity_stats(enemy_rarity)
			enemy.global_position = _cell_to_world(Vector2i(spawn_x, spawn_y))
			enemy.set("enemy_id", "dungeon_%d_rat_%d" % [depth, enemy_counter])
			enemy.set("enemy_rarity", enemy_rarity)
			enemy.set("enemy_name", _get_enemy_display_name("Dungeon Rat", enemy_rarity))
			enemy.set("max_health", int(round(float(30 + depth * 10) * float(rarity_stats.get("health_multiplier", 1.0)))))
			enemy.set("contact_damage", int(round(float(11 + depth * 2) * float(rarity_stats.get("damage_multiplier", 1.0)))))
			enemy.set("attack_cooldown", 0.9)
			enemy.set("xp_reward", int(round(float(4 + depth) * float(rarity_stats.get("xp_multiplier", 1.0)))))
			enemy.set("gold_reward", 0)
			enemy.set("loot_drop_name", "")
			enemy.set("loot_drop_kind", "")
			gameplay_root.add_child(enemy)
			if enemy.has_method("set_player"):
				enemy.call("set_player", player)
			if enemy.has_signal("defeated"):
				enemy.connect("defeated", Callable(self, "_on_enemy_defeated"))
			if enemy.has_signal("attacked_player"):
				enemy.connect("attacked_player", Callable(self, "_on_enemy_attacked_player"))


func _roll_enemy_rarity() -> String:
	var rare_chance: float = minf(0.10 + float(depth - 1) * 0.015, 0.24)
	if rng.randf() <= rare_chance:
		return "rare"
	return "normal"


func _get_enemy_rarity_stats(enemy_rarity: String) -> Dictionary:
	match enemy_rarity:
		"rare":
			return {
				"health_multiplier": 1.85,
				"damage_multiplier": 1.25,
				"xp_multiplier": 1.8
			}
		"epic":
			return {
				"health_multiplier": 4.0,
				"damage_multiplier": 1.75,
				"xp_multiplier": 5.0
			}
		_:
			return {
				"health_multiplier": 1.0,
				"damage_multiplier": 1.0,
				"xp_multiplier": 1.0
			}


func _get_enemy_display_name(base_name: String, enemy_rarity: String) -> String:
	match enemy_rarity:
		"rare":
			return "Dire %s" % base_name
		"epic":
			return "Epic %s" % base_name
		_:
			return base_name


func _spawn_mobile_controls() -> void:
	mobile_controls_layer = CanvasLayer.new()
	mobile_controls_layer.name = "MobileControlsLayer"
	mobile_controls_layer.layer = 20
	add_child(mobile_controls_layer)

	mobile_controls = MobileControlsScene.instantiate()
	mobile_controls_layer.add_child(mobile_controls)
	if mobile_controls.has_signal("context_action_pressed"):
		mobile_controls.connect("context_action_pressed", Callable(self, "_perform_context_action"))
	if mobile_controls.has_signal("quick_item_pressed"):
		mobile_controls.connect("quick_item_pressed", Callable(self, "_use_quick_item"))
	_update_context_button()


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE * 0.5, cell.y * TILE_SIZE + TILE_SIZE * 0.5)


func _get_player_spawn_cell(spawn_room: Rect2i, up_stairs_cell: Vector2i, down_stairs_cell: Vector2i) -> Vector2i:
	match pending_spawn_mode:
		SPAWN_UP_STAIRS:
			return _find_floor_spawn_near(up_stairs_cell)
		SPAWN_DOWN_STAIRS:
			return _find_floor_spawn_near(down_stairs_cell)
		_:
			return _room_center(spawn_room)


func _find_floor_spawn_near(stairs_cell: Vector2i) -> Vector2i:
	var offsets: Array[Vector2i] = [
		Vector2i(0, 1),
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, -1),
		Vector2i(1, 1),
		Vector2i(-1, 1),
		Vector2i(1, -1),
		Vector2i(-1, -1)
	]
	for offset in offsets:
		var candidate: Vector2i = stairs_cell + offset
		if candidate.x < 0 or candidate.y < 0 or candidate.x >= GRID_WIDTH or candidate.y >= GRID_HEIGHT:
			continue
		if int(grid[candidate.y][candidate.x]) == FLOOR_TILE:
			return candidate
	return stairs_cell


func _find_farthest_room_from(origin_room: Rect2i) -> Rect2i:
	var origin_center: Vector2i = _room_center(origin_room)
	var farthest_room: Rect2i = origin_room
	var farthest_distance: float = -1.0
	for room in rooms:
		if room == origin_room:
			continue
		var distance: float = Vector2(_room_center(room) - origin_center).length_squared()
		if distance > farthest_distance:
			farthest_distance = distance
			farthest_room = room
	return farthest_room


func _find_longest_route_room_from(origin_room: Rect2i) -> Rect2i:
	var origin_cell: Vector2i = _room_center(origin_room)
	var distances: Array[Array] = []
	for y in range(GRID_HEIGHT):
		var row: Array[int] = []
		for _x in range(GRID_WIDTH):
			row.append(-1)
		distances.append(row)

	var queue: Array[Vector2i] = [origin_cell]
	distances[origin_cell.y][origin_cell.x] = 0
	var queue_index: int = 0
	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1
		var current_distance: int = int(distances[current.y][current.x])
		for direction in ORTHOGONAL_DIRECTIONS:
			var next_cell: Vector2i = current + direction
			if next_cell.x < 0 or next_cell.y < 0 or next_cell.x >= GRID_WIDTH or next_cell.y >= GRID_HEIGHT:
				continue
			if int(grid[next_cell.y][next_cell.x]) != FLOOR_TILE:
				continue
			if int(distances[next_cell.y][next_cell.x]) >= 0:
				continue
			distances[next_cell.y][next_cell.x] = current_distance + 1
			queue.append(next_cell)

	var longest_room: Rect2i = origin_room
	var longest_distance: int = -1
	for room in rooms:
		if room == origin_room:
			continue
		var center: Vector2i = _room_center(room)
		var distance: int = int(distances[center.y][center.x])
		if distance > longest_distance:
			longest_distance = distance
			longest_room = room

	if longest_distance < 0:
		return _find_farthest_room_from(origin_room)
	return longest_room


func _room_cell_with_offset(room: Rect2i, offset: Vector2i) -> Vector2i:
	var center: Vector2i = _room_center(room)
	return Vector2i(
		clampi(center.x + offset.x, room.position.x + 1, room.position.x + room.size.x - 2),
		clampi(center.y + offset.y, room.position.y + 1, room.position.y + room.size.y - 2)
	)


func _perform_context_action() -> void:
	if player == null:
		return

	var nearby: Node = player.call("get_nearby_interactable")
	if nearby != null and player.call("can_interact_with", nearby):
		player.call("try_interact")
		return

	player.call("try_attack")


func _on_player_attack_requested(origin: Vector2, direction: Vector2, attack_distance: float) -> void:
	var attack_value: int = _get_attack_value()
	var hit_anything: bool = false
	for child in gameplay_root.get_children():
		if not child.is_in_group("enemies"):
			continue
		if bool(child.get("defeated_state")):
			continue
		var enemy_position: Vector2 = (child as Node2D).global_position
		var offset: Vector2 = enemy_position - origin
		var distance: float = offset.length()
		if distance > attack_distance:
			continue
		var facing: Vector2 = direction.normalized()
		var aim_score: float = 1.0 if distance < 18.0 else facing.dot(offset.normalized())
		if aim_score < 0.15:
			continue
		child.call("take_damage", attack_value, origin, true)
		hit_anything = true

	combat_message = "You hit for %d." % attack_value if hit_anything else "Your swing cuts the dark."
	_update_overlay()


func _on_player_interacted(target: Node) -> void:
	if target == null:
		return

	if target.is_in_group("dungeon_stairs"):
		var target_depth_value: int = int(target.get("target_depth"))
		if target_depth_value <= 0:
			GameSession.change_scene_with_fade("res://scenes/world/world.tscn")
			return
		combat_message = "You descend to depth %d." % target_depth_value if target_depth_value > depth else "You climb to depth %d." % target_depth_value
		var next_spawn_mode: String = SPAWN_UP_STAIRS if target_depth_value > depth else SPAWN_DOWN_STAIRS
		_build_dungeon(target_depth_value, next_spawn_mode)
		return

	if target.has_method("open_chest") and not bool(target.get("is_open")):
		var item_name: String = str(target.get("item_name"))
		var item_kind: String = str(target.get("item_kind"))
		target.call("open_chest")
		InventoryStateScript.add_item(bag_slots, item_name, item_kind, 1)
		combat_message = "Found %s." % item_name
		_update_overlay()
		return

	if target.has_method("collect_pickup"):
		var pickup_data: Dictionary = target.call("collect_pickup")
		if not pickup_data.is_empty():
			var pickup_name: String = str(pickup_data.get("name", "item"))
			var pickup_kind: String = str(pickup_data.get("kind", "consumable"))
			var pickup_count: int = int(pickup_data.get("count", 1))
			if pickup_kind == "gold":
				player_gold += pickup_count
				combat_message = "Picked up %d gold." % pickup_count
			else:
				InventoryStateScript.add_item(bag_slots, pickup_name, pickup_kind, pickup_count)
				combat_message = "Picked up %s." % pickup_name
			_update_overlay()


func _on_enemy_defeated(enemy_id: String, enemy_name: String, xp_reward: int, _gold_reward: int, _loot_drop_name: String, _loot_drop_kind: String, _faction: String, _is_boss: bool) -> void:
	player_xp += xp_reward
	var enemy_position: Vector2 = _find_enemy_position(enemy_id)
	var enemy_rarity: String = _find_enemy_rarity(enemy_id)
	var drop_count: int = _spawn_mob_loot(enemy_position, "rat", enemy_rarity)
	combat_message = "%s defeated. +%d XP." % [enemy_name, xp_reward]
	if drop_count > 0:
		combat_message += " Loot dropped."
	_apply_stats_to_player()
	_update_overlay()


func _find_enemy_position(enemy_id: String) -> Vector2:
	for child in gameplay_root.get_children():
		if not child.is_in_group("enemies"):
			continue
		if str(child.get("enemy_id")) == enemy_id:
			return (child as Node2D).global_position
	return player.global_position if player != null else Vector2.ZERO


func _find_enemy_rarity(enemy_id: String) -> String:
	for child in gameplay_root.get_children():
		if not child.is_in_group("enemies"):
			continue
		if str(child.get("enemy_id")) == enemy_id:
			return str(child.get("enemy_rarity"))
	return "normal"


func _spawn_mob_loot(origin: Vector2, enemy_type: String, enemy_rarity: String) -> int:
	var drops: Array[Dictionary] = LootTablesScript.roll_mob_drops(enemy_type, depth, rng, enemy_rarity)
	for drop_index in range(drops.size()):
		_spawn_loot_drop(drops[drop_index], origin, drop_index, drops.size())
	return drops.size()


func _spawn_loot_drop(drop_data: Dictionary, origin: Vector2, drop_index: int, drop_count: int) -> void:
	var loot: Node2D = DroppedLootScene.instantiate()
	var spread_angle: float = (TAU / float(maxi(1, drop_count))) * float(drop_index)
	var spread: Vector2 = Vector2(cos(spread_angle), sin(spread_angle)) * (14.0 + float(drop_index % 2) * 6.0)
	loot.global_position = origin + spread
	loot.set("pickup_id", "drop_depth_%d_%d_%d" % [depth, Time.get_ticks_msec(), drop_index])
	loot.set("item_name", str(drop_data.get("name", "")))
	loot.set("item_kind", str(drop_data.get("kind", "consumable")))
	loot.set("item_count", int(drop_data.get("count", 1)))
	loot.set("loot_visual", str(drop_data.get("visual", "bag")))
	loot.set("available_message", "%s lies on the ground." % str(drop_data.get("name", "Loot")))
	gameplay_root.add_child(loot)


func _on_enemy_attacked_player(damage: int, enemy_name: String) -> void:
	var final_damage: int = maxi(1, damage - _get_defense_value())
	player_health = maxi(0, player_health - final_damage)
	if player != null and player.has_method("show_hurt_feedback"):
		player.call("show_hurt_feedback")

	if player_health <= 0:
		combat_message = "%s dropped you. The dungeon spits you back out." % enemy_name
		player_health = player_max_health
		_build_dungeon(1, SPAWN_ENTRANCE)
		return

	combat_message = "%s bites for %d." % [enemy_name, final_damage]
	_update_overlay()


func _on_inventory_changed(next_bag_slots: Array, next_equipment_slots: Dictionary) -> void:
	bag_slots = InventoryStateScript.normalize_bag(next_bag_slots)
	equipment_slots = InventoryStateScript.normalize_equipment(next_equipment_slots)
	_apply_stats_to_player()
	_update_overlay()


func _on_item_use_requested(item_name: String) -> void:
	_use_item(item_name)


func _on_quick_item_assigned(item_name: String, _item_kind: String) -> void:
	quick_item_name = item_name
	_update_context_button()


func _on_stat_increase_requested(stat_name: String) -> void:
	var progression_state: Dictionary = ProgressionScript.get_progression_state(player_xp, stat_allocations)
	if int(progression_state.get("unspent_points", 0)) <= 0:
		return
	stat_allocations = ProgressionScript.increase_stat(stat_allocations, stat_name)
	_apply_stats_to_player()
	_update_overlay("Raised %s." % stat_name.capitalize())


func _on_overlay_menu_toggled(is_open: bool) -> void:
	get_tree().paused = is_open
	if player != null and player.has_method("set_can_move"):
		player.call("set_can_move", not is_open)
	if mobile_controls != null and mobile_controls.has_method("set_controls_enabled"):
		mobile_controls.call("set_controls_enabled", not is_open)


func _use_quick_item() -> void:
	if quick_item_name.is_empty():
		return
	_use_item(quick_item_name)


func _use_item(item_name: String) -> void:
	var effects: Dictionary = InventoryStateScript.get_consumable_effects(item_name)
	var heal_amount: int = int(effects.get("heal", 0))
	if heal_amount <= 0:
		return
	if player_health >= player_max_health:
		combat_message = "You are already healthy."
		_update_overlay()
		return
	InventoryStateScript.remove_item(bag_slots, equipment_slots, item_name, 1)
	player_health = mini(player_max_health, player_health + heal_amount)
	combat_message = "Used %s. Restored %d HP." % [item_name, heal_amount]
	_update_overlay()


func _apply_stats_to_player() -> void:
	var old_max_health: int = player_max_health
	var stat_bonuses: Dictionary = ProgressionScript.get_stat_bonuses(stat_allocations)
	var equipment_totals: Dictionary = InventoryStateScript.get_equipment_totals(equipment_slots)
	player_max_health = BASE_PLAYER_HEALTH + int(stat_bonuses.get("max_health", 0)) + int(equipment_totals.get("max_health", 0))
	if player_max_health != old_max_health:
		player_health = clampi(player_health + player_max_health - old_max_health, 1, player_max_health)
	if player != null:
		player.set("move_speed", 165.0 + float(stat_bonuses.get("move_speed", 0)))
		if player.has_method("set_equipment_visuals"):
			player.call("set_equipment_visuals", equipment_slots)


func _get_attack_value() -> int:
	var stat_bonuses: Dictionary = ProgressionScript.get_stat_bonuses(stat_allocations)
	var equipment_totals: Dictionary = InventoryStateScript.get_equipment_totals(equipment_slots)
	return 1 + int(stat_bonuses.get("attack", 0)) + int(equipment_totals.get("attack", 0))


func _get_defense_value() -> int:
	var stat_bonuses: Dictionary = ProgressionScript.get_stat_bonuses(stat_allocations)
	var equipment_totals: Dictionary = InventoryStateScript.get_equipment_totals(equipment_slots)
	return int(stat_bonuses.get("defense", 0)) + int(equipment_totals.get("defense", 0))


func _update_overlay(next_message: String = "") -> void:
	if not next_message.is_empty():
		combat_message = next_message
	_apply_stats_to_player()
	var progression_state: Dictionary = ProgressionScript.get_progression_state(player_xp, stat_allocations)
	var level_value: int = int(progression_state.get("level", 1))
	var xp_into_level: int = int(progression_state.get("xp_into_level", 0))
	var xp_to_next: int = int(progression_state.get("xp_to_next", 10))
	GameSession.set_overlay_header("Depth %d" % depth, "Dungeon Depth %d" % depth)
	GameSession.set_overlay_status(player_health, player_max_health, xp_into_level, combat_message, player_health <= 2, xp_to_next, level_value)
	GameSession.set_overlay_inventory_state(bag_slots, equipment_slots, player_gold)
	GameSession.set_overlay_progression_state(
		level_value,
		int(progression_state.get("unspent_points", 0)),
		stat_allocations,
		_get_attack_value(),
		_get_defense_value(),
		player_max_health
	)
	GameSession.set_overlay_quest_journal(_build_dungeon_journal(), tracked_quest_ids)
	_update_context_button()


func _build_dungeon_journal() -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		{
			"id": "dungeon_descent",
			"title": "Into the Dark",
			"status": "Active",
			"status_text": "Find the stairs and descend deeper.",
			"summary": "Reach the stairs on depth %d." % depth,
			"details": "Clear rooms, gather supplies, and find the stairway down. Each floor becomes more dangerous.",
			"trackable": true
		}
	]
	tracked_quest_ids = GameSession.autofill_tracked_quest_ids(tracked_quest_ids, entries, MAX_TRACKED_QUESTS)
	return entries


func _update_context_button() -> void:
	if mobile_controls == null:
		return
	var label_text: String = "Attack"
	if player != null:
		var nearby: Node = player.call("get_nearby_interactable")
		if nearby != null:
			if nearby.is_in_group("dungeon_stairs"):
				var target_depth_value: int = int(nearby.get("target_depth"))
				label_text = "Up" if target_depth_value < depth else "Down"
			elif nearby.has_method("open_chest") or nearby.has_method("collect_pickup"):
				label_text = "Use"
	if mobile_controls.has_method("set_context_action_label"):
		mobile_controls.call("set_context_action_label", label_text)
	if mobile_controls.has_method("set_quick_item"):
		var quick_count: int = _get_bag_item_count(quick_item_name)
		mobile_controls.call("set_quick_item", quick_item_name, quick_count)


func _get_bag_item_count(item_name: String) -> int:
	if item_name.is_empty():
		return 0
	var total: int = 0
	for item in bag_slots:
		var item_data: Dictionary = InventoryStateScript.normalize_item(item)
		if str(item_data.get("name", "")) == item_name:
			total += int(item_data.get("count", 1))
	return total
