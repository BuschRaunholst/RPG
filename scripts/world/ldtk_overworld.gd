extends Node2D

const IMPORTED_LEVEL_SCENE: PackedScene = preload("res://assets/maps/levels/Level_0.scn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/actors/player.tscn")
const NPC_SCENE: PackedScene = preload("res://scenes/actors/npc.tscn")
const RAT_SCENE: PackedScene = preload("res://scenes/actors/rat.tscn")

const COLLISION_LAYER_NAME := "Collision-values"
const ENTITY_LAYER_NAMES := ["Player_Spawn", "NPC", "Enemy", "Interactable"]

var imported_level: Node2D
var player: Node2D
var gameplay_root: Node2D
var collision_body: StaticBody2D


func _ready() -> void:
	GameSession.show_game_overlay()
	GameSession.set_overlay_header("", "Oakcross Village")
	GameSession.set_overlay_status(9, 9, 0, "", false, 10, 1)
	GameSession.set_overlay_quest_journal([], [])
	GameSession.set_overlay_save_status("LDtk world")

	_build_world()


func _build_world() -> void:
	imported_level = IMPORTED_LEVEL_SCENE.instantiate()
	add_child(imported_level)

	gameplay_root = Node2D.new()
	gameplay_root.name = "Gameplay"
	gameplay_root.y_sort_enabled = true
	add_child(gameplay_root)

	_build_collision_from_imported_layer()
	_spawn_gameplay_entities()
	_assign_player_to_enemies()
	_add_player_camera()


func _build_collision_from_imported_layer() -> void:
	var collision_layer := imported_level.get_node_or_null(COLLISION_LAYER_NAME) as TileMapLayer
	if collision_layer == null:
		push_warning("LDtk collision layer not found: %s" % COLLISION_LAYER_NAME)
		return

	collision_layer.visible = false
	collision_body = StaticBody2D.new()
	collision_body.name = "LDtkCollision"
	add_child(collision_body)

	var tile_size := Vector2(16, 16)
	if collision_layer.tile_set != null:
		tile_size = Vector2(collision_layer.tile_set.tile_size)

	var used_cells := collision_layer.get_used_cells()
	var used_lookup: Dictionary = {}
	for cell in used_cells:
		used_lookup[cell] = true

	var visited: Dictionary = {}
	for cell in used_cells:
		if visited.has(cell):
			continue

		var run_length := 0
		var cursor := cell
		while used_lookup.has(cursor) and not visited.has(cursor):
			visited[cursor] = true
			run_length += 1
			cursor.x += 1

		_add_collision_run(collision_layer, cell, run_length, tile_size)


func _add_collision_run(layer: TileMapLayer, start_cell: Vector2i, length: int, tile_size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(tile_size.x * length, tile_size.y)

	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.global_position = layer.to_global(layer.map_to_local(start_cell)) + Vector2(tile_size.x * float(length - 1) * 0.5, 0.0)
	collision_body.add_child(collision)


func _spawn_gameplay_entities() -> void:
	for layer_name in ENTITY_LAYER_NAMES:
		var entity_layer := imported_level.get_node_or_null(layer_name)
		if entity_layer == null:
			continue

		entity_layer.visible = false
		if not "entities" in entity_layer:
			continue

		var entities: Array = entity_layer.get("entities")
		for entity_index in range(entities.size()):
			_spawn_entity(entities[entity_index], entity_index)


func _spawn_entity(entity: Dictionary, entity_index: int) -> void:
	var identifier := str(entity.get("identifier", ""))
	var instance: Node2D = null

	match identifier:
		"Player":
			instance = PLAYER_SCENE.instantiate()
			player = instance
		"Elder_Rowan", "Mira":
			instance = NPC_SCENE.instantiate()
			_configure_npc(instance, entity)
		"Rat":
			instance = RAT_SCENE.instantiate()
			_configure_rat(instance, entity, entity_index)
		_:
			return

	instance.global_position = _entity_position(entity)
	instance.name = identifier
	gameplay_root.add_child(instance)


func _entity_position(entity: Dictionary) -> Vector2:
	var position_value: Variant = entity.get("position", Vector2.ZERO)
	if position_value is Vector2:
		return position_value

	return Vector2.ZERO


func _configure_npc(npc: Node, entity: Dictionary) -> void:
	var identifier := str(entity.get("identifier", ""))
	var fields: Dictionary = entity.get("fields", {})

	if identifier == "Elder_Rowan":
		npc.set("npc_id", "elder_rowan")
		npc.set("npc_name", "Elder Rowan")
		npc.set("dialogue_text", "LDtk placed me here. The village is ours to build now.")
	else:
		npc.set("npc_id", _string_or_fallback(fields.get("npc_id", ""), "mira"))
		npc.set("npc_name", "Mira")
		npc.set("dialogue_text", "This map comes from LDtk now. Much nicer to shape, right?")


func _configure_rat(rat: Node, entity: Dictionary, entity_index: int) -> void:
	var fields: Dictionary = entity.get("fields", {})
	var enemy_id := _string_or_fallback(fields.get("enemy_id", ""), "")
	if enemy_id.is_empty() or enemy_id == "0":
		enemy_id = "ldtk_rat_%02d" % entity_index

	rat.set("enemy_id", enemy_id)
	rat.set("enemy_name", "Field Rat")
	rat.set("enemy_type", _string_or_fallback(fields.get("enemy_type", ""), "rat"))


func _assign_player_to_enemies() -> void:
	if player == null:
		return

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if gameplay_root.is_ancestor_of(enemy) and enemy.has_method("set_player"):
			enemy.set_player(player)


func _add_player_camera() -> void:
	if player == null:
		return

	var camera := Camera2D.new()
	camera.name = "PlayerCamera"
	camera.enabled = true
	player.add_child(camera)
	camera.make_current()


func _string_or_fallback(value: Variant, fallback: String) -> String:
	if value == null:
		return fallback

	var text := str(value).strip_edges()
	return fallback if text.is_empty() else text
