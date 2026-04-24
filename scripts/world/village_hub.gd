extends Node2D

const InventoryStateScript = preload("res://scripts/world/inventory_state.gd")
const ClassProgressionStateScript = preload("res://scripts/world/class_progression_state.gd")
const ProgressionScript = preload("res://scripts/world/progression.gd")
const SkillTreeResolverScript = preload("res://scripts/world/skill_tree_resolver.gd")
const PlayerBuildRuntimeScript = preload("res://scripts/world/player_build_runtime.gd")
const PlayerScene = preload("res://scenes/actors/player.tscn")
const NpcScene = preload("res://scenes/actors/npc.tscn")
const EntranceScene = preload("res://scenes/interactables/dungeon_entrance.tscn")
const MobileControlsScene = preload("res://scenes/ui/mobile_controls.tscn")

const TILE_SIZE: int = 32
const WORLD_SIZE: Vector2 = Vector2(1280, 864)
const BASE_PLAYER_HEALTH: int = 80

var player: Node2D
var mobile_controls: Control
var mobile_controls_layer: CanvasLayer
var terrain_root: Node2D
var building_root: Node2D
var gameplay_root: Node2D
var collision_body: StaticBody2D

var player_health: int = BASE_PLAYER_HEALTH
var player_max_health: int = BASE_PLAYER_HEALTH
var player_xp: int = 0
var player_gold: int = 0
var progression_state: Dictionary = {}
var resolved_progression: Dictionary = {}
var runtime_build_state: Dictionary = {}
var bag_slots: Array[Dictionary] = []
var equipment_slots: Dictionary = {}
var quick_item_name: String = ""
var status_message: String = "The village sleeps under a bad moon."
var context_update_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_setup_state()
	_create_roots()
	_draw_village()
	_spawn_player()
	_spawn_npcs()
	_spawn_dungeon_entrance()
	_spawn_mobile_controls()
	_bind_overlay()
	_update_overlay()


func _process(delta: float) -> void:
	context_update_timer += delta
	if context_update_timer < 0.15:
		return
	context_update_timer = 0.0
	_update_context_button()


func _setup_state() -> void:
	var transition_state: Dictionary = GameSession.consume_transition_state()
	if transition_state.is_empty():
		progression_state = ClassProgressionStateScript.create_new_state(ClassProgressionStateScript.DEFAULT_CLASS_ID)
		var starting_state: Dictionary = InventoryStateScript.create_default_starting_state_for_class(str(progression_state.get("class_id", ClassProgressionStateScript.DEFAULT_CLASS_ID)))
		bag_slots = InventoryStateScript.normalize_bag(starting_state.get("bag_slots", []))
		equipment_slots = InventoryStateScript.normalize_equipment(starting_state.get("equipment_slots", {}))
		progression_state = ClassProgressionStateScript.sync_state(progression_state, player_xp)
		_refresh_resolved_progression()
		return

	bag_slots = InventoryStateScript.normalize_bag(transition_state.get("bag_slots", []))
	equipment_slots = InventoryStateScript.normalize_equipment(transition_state.get("equipment_slots", {}))
	player_xp = int(transition_state.get("player_xp", 0))
	player_gold = int(transition_state.get("player_gold", 0))
	player_max_health = int(transition_state.get("player_max_health", BASE_PLAYER_HEALTH))
	player_health = clampi(int(transition_state.get("player_health", player_max_health)), 1, player_max_health)
	quick_item_name = str(transition_state.get("quick_item_name", ""))
	progression_state = ClassProgressionStateScript.normalize_state(transition_state.get("progression_state", {}), player_xp)
	_refresh_resolved_progression()


func _bind_overlay() -> void:
	GameSession.show_game_overlay()
	GameSession.set_overlay_menu_locked(false)
	GameSession.bind_overlay_menu_toggled(Callable(self, "_on_overlay_menu_toggled"))
	GameSession.bind_overlay_inventory_changed(Callable(self, "_on_inventory_changed"))
	GameSession.bind_overlay_item_use_requested(Callable(self, "_on_item_use_requested"))
	GameSession.bind_overlay_quick_item_assigned(Callable(self, "_on_quick_item_assigned"))
	GameSession.bind_overlay_skill_node_unlock_requested(Callable(self, "_on_skill_node_unlock_requested"))
	GameSession.bind_overlay_skill_family_equipped(Callable(self, "_on_skill_family_equipped"))


func _create_roots() -> void:
	terrain_root = Node2D.new()
	terrain_root.name = "Terrain"
	add_child(terrain_root)

	building_root = Node2D.new()
	building_root.name = "Buildings"
	building_root.y_sort_enabled = true
	add_child(building_root)

	collision_body = StaticBody2D.new()
	collision_body.name = "VillageCollision"
	add_child(collision_body)

	gameplay_root = Node2D.new()
	gameplay_root.name = "Gameplay"
	gameplay_root.y_sort_enabled = true
	add_child(gameplay_root)


func _draw_village() -> void:
	_draw_rect(terrain_root, Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.045, 0.062, 0.055, 1.0), "NightGrass")
	for y in range(0, int(WORLD_SIZE.y), TILE_SIZE):
		for x in range(0, int(WORLD_SIZE.x), TILE_SIZE):
			var noise_value: float = float((x * 17 + y * 31) % 97) / 97.0
			var tile_color: Color = Color(0.060 + noise_value * 0.018, 0.092 + noise_value * 0.022, 0.070 + noise_value * 0.018, 0.46)
			_draw_rect(terrain_root, Rect2(Vector2(x, y), Vector2(TILE_SIZE, TILE_SIZE)), tile_color, "GrassShade")

	_draw_path(Rect2(80, 386, 1120, 88))
	_draw_path(Rect2(586, 178, 88, 560))
	_draw_path(Rect2(674, 178, 250, 72))
	_draw_path(Rect2(356, 250, 230, 72))
	_draw_path(Rect2(224, 474, 108, 160))
	_draw_well(Vector2(512, 430))
	_draw_house(Vector2(188, 198), "blue")
	_draw_house(Vector2(838, 226), "orange")
	_draw_house(Vector2(246, 570), "brown")
	_draw_fence(Vector2(700, 540), 9)
	_draw_dead_tree(Vector2(1042, 486))
	_draw_lantern(Vector2(606, 315))
	_draw_rect(terrain_root, Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.02, 0.025, 0.035, 0.18), "NightWash")


func _draw_path(rect: Rect2) -> void:
	_draw_rect(terrain_root, rect, Color(0.165, 0.145, 0.115, 1.0), "Path")
	for i in range(18):
		var px: float = rect.position.x + float((i * 67) % int(rect.size.x))
		var py: float = rect.position.y + float((i * 37) % int(rect.size.y))
		_draw_rect(terrain_root, Rect2(Vector2(px, py), Vector2(22, 8)), Color(0.28, 0.25, 0.20, 0.20), "PathPebble")


func _draw_house(origin: Vector2, roof_kind: String) -> void:
	var wall_color: Color = Color(0.18, 0.165, 0.135, 1.0)
	var roof_color: Color = Color(0.095, 0.135, 0.165, 1.0)
	if roof_kind == "orange":
		roof_color = Color(0.22, 0.115, 0.075, 1.0)
	elif roof_kind == "brown":
		roof_color = Color(0.18, 0.125, 0.070, 1.0)

	_draw_rect(building_root, Rect2(origin + Vector2(6, 78), Vector2(164, 14)), Color(0, 0, 0, 0.28), "HouseShadow")
	_draw_rect(building_root, Rect2(origin + Vector2(20, 42), Vector2(132, 76)), wall_color.darkened(0.05), "HouseWall")
	_draw_rect(building_root, Rect2(origin + Vector2(26, 47), Vector2(120, 6)), wall_color.lightened(0.08), "HouseBeam")
	for plank_index in range(5):
		var seam_x: float = 38.0 + plank_index * 23.0
		if seam_x >= 96.0 and seam_x <= 126.0:
			continue
		if seam_x >= 56.0 and seam_x <= 88.0:
			continue
		_draw_rect(building_root, Rect2(origin + Vector2(seam_x, 54), Vector2(2, 62)), Color(0.09, 0.078, 0.062, 0.50), "HousePlank")
	_draw_rect(building_root, Rect2(origin + Vector2(58, 72), Vector2(28, 46)), Color(0.075, 0.052, 0.040, 1.0), "HouseDoor")
	_draw_rect(building_root, Rect2(origin + Vector2(100, 62), Vector2(24, 22)), Color(0.86, 0.56, 0.18, 0.48), "Window")
	_draw_rect(building_root, Rect2(origin + Vector2(104, 66), Vector2(16, 14)), Color(0.035, 0.042, 0.047, 1.0), "WindowDark")

	var roof: Polygon2D = Polygon2D.new()
	roof.position = origin
	roof.polygon = PackedVector2Array([
		Vector2(0, 48),
		Vector2(86, 0),
		Vector2(172, 48)
	])
	roof.color = roof_color
	building_root.add_child(roof)
	var roof_lip: Polygon2D = Polygon2D.new()
	roof_lip.position = origin
	roof_lip.polygon = PackedVector2Array([
		Vector2(7, 48),
		Vector2(165, 48),
		Vector2(152, 61),
		Vector2(20, 61)
	])
	roof_lip.color = roof_color.darkened(0.25)
	building_root.add_child(roof_lip)

	_add_collision(Rect2(origin + Vector2(20, 52), Vector2(132, 62)))


func _draw_well(center: Vector2) -> void:
	_draw_rect(building_root, Rect2(center + Vector2(-28, 16), Vector2(56, 8)), Color(0, 0, 0, 0.20), "WellShadow")
	_draw_rect(building_root, Rect2(center + Vector2(-23, -7), Vector2(46, 27)), Color(0.22, 0.21, 0.20, 1.0), "WellStone")
	_draw_rect(building_root, Rect2(center + Vector2(-17, -1), Vector2(34, 15)), Color(0.035, 0.04, 0.045, 1.0), "WellHole")
	_add_collision(Rect2(center + Vector2(-23, -7), Vector2(46, 27)))


func _draw_fence(origin: Vector2, count: int) -> void:
	for index in range(count):
		var x: float = origin.x + index * 28.0
		_draw_rect(building_root, Rect2(Vector2(x, origin.y), Vector2(20, 8)), Color(0.23, 0.14, 0.08, 1.0), "FenceRail")
		_draw_rect(building_root, Rect2(Vector2(x + 7, origin.y - 14), Vector2(6, 28)), Color(0.30, 0.18, 0.10, 1.0), "FencePost")
	_add_collision(Rect2(origin + Vector2(0, -12), Vector2(count * 28.0, 26)))


func _draw_dead_tree(origin: Vector2) -> void:
	_draw_rect(building_root, Rect2(origin + Vector2(-7, -34), Vector2(14, 62)), Color(0.15, 0.10, 0.07, 1.0), "TreeTrunk")
	_draw_rect(building_root, Rect2(origin + Vector2(-36, -52), Vector2(72, 14)), Color(0.10, 0.075, 0.055, 1.0), "TreeBranch")
	_draw_rect(building_root, Rect2(origin + Vector2(-48, -62), Vector2(14, 36)), Color(0.10, 0.075, 0.055, 1.0), "TreeBranchLeft")
	_draw_rect(building_root, Rect2(origin + Vector2(34, -66), Vector2(13, 41)), Color(0.10, 0.075, 0.055, 1.0), "TreeBranchRight")
	_add_collision(Rect2(origin + Vector2(-14, -18), Vector2(28, 44)))


func _draw_lantern(origin: Vector2) -> void:
	_draw_rect(building_root, Rect2(origin + Vector2(-3, -44), Vector2(6, 52)), Color(0.07, 0.06, 0.05, 1.0), "LanternPost")
	_draw_rect(building_root, Rect2(origin + Vector2(-11, -52), Vector2(22, 16)), Color(0.90, 0.58, 0.20, 0.85), "LanternLight")
	_draw_rect(building_root, Rect2(origin + Vector2(-16, -58), Vector2(32, 32)), Color(0.95, 0.50, 0.16, 0.12), "LanternGlow")


func _draw_rect(parent: Node, rect: Rect2, color: Color, node_name: String) -> Polygon2D:
	var polygon: Polygon2D = Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y)
	])
	polygon.color = color
	parent.add_child(polygon)
	return polygon


func _add_collision(rect: Rect2) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.position + rect.size * 0.5
	collision_body.add_child(collision)


func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	player.global_position = _get_player_spawn_position()
	gameplay_root.add_child(player)
	player.attack_requested.connect(_on_player_attack_requested)
	player.interacted.connect(_on_player_interacted)
	if player.has_signal("context_action_requested"):
		player.context_action_requested.connect(_perform_context_action)

	var camera: Camera2D = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	camera.zoom = Vector2(1.0, 1.0)
	player.add_child(camera)
	camera.make_current()


func _get_player_spawn_position() -> Vector2:
	var spawn_marker: String = GameSession.consume_spawn_marker()
	if spawn_marker == "dungeon_return":
		return Vector2(798, 268)
	return Vector2(636, 454)


func _spawn_npcs() -> void:
	_spawn_npc("elder_rowan", "Elder Rowan", Vector2(560, 386), "male", 4, 1, "The old mine opened again last night.\nGo only when your hands are steady.")
	_spawn_npc("mira", "Mira", Vector2(866, 392), "female", 2, 3, "If you go below, carry food and keep moving.\nRats are only the beginning down there.")
	_spawn_npc("line", "Line", Vector2(306, 538), "male", 1, 4, "No one sleeps well when the dungeon breathes.\nI heard scratching under the road.")


func _spawn_npc(npc_id: String, npc_name: String, position: Vector2, gender: String, hair: int, clothing: int, dialogue: String) -> void:
	var npc: Node2D = NpcScene.instantiate()
	npc.global_position = position
	npc.set("npc_id", npc_id)
	npc.set("npc_name", npc_name)
	npc.set("visual_gender", gender)
	npc.set("hair_color_index", hair)
	npc.set("clothing_color_index", clothing)
	npc.set("dialogue_text", dialogue)
	gameplay_root.add_child(npc)


func _spawn_dungeon_entrance() -> void:
	var entrance: Node2D = EntranceScene.instantiate()
	entrance.global_position = Vector2(798, 220)
	gameplay_root.add_child(entrance)


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


func _perform_context_action() -> void:
	if player == null:
		return
	var nearby: Node = player.call("get_nearby_interactable")
	if nearby != null and player.call("can_interact_with", nearby):
		player.call("try_interact")
		return
	player.call("try_attack")


func _on_player_interacted(target: Node) -> void:
	if target == null:
		return
	if target.is_in_group("dungeon_entrance"):
		_enter_dungeon()
		return
	if target.has_method("get_dialogue_lines"):
		var lines: PackedStringArray = target.call("get_dialogue_lines")
		if not lines.is_empty():
			var speaker: String = str(target.get("npc_name")) if "npc_name" in target else str(target.get("speaker_name"))
			status_message = "%s: %s" % [speaker, lines[0]]
			_update_overlay()


func _enter_dungeon() -> void:
	GameSession.set_transition_state({
		"player_health": player_health,
		"player_max_health": player_max_health,
		"player_xp": player_xp,
		"player_gold": player_gold,
		"progression_state": progression_state,
		"bag_slots": bag_slots,
		"equipment_slots": equipment_slots,
		"quick_item_name": quick_item_name
	})
	GameSession.change_scene_with_fade("res://scenes/world/dungeon_run.tscn")


func _on_player_attack_requested(attack_data: Dictionary) -> void:
	var weapon_name: String = str(attack_data.get("weapon_name", "Steel"))
	var attack_kind: String = str(attack_data.get("attack_kind", "melee_arc"))
	if attack_kind == "projectile":
		status_message = "%s hums, but there is nothing to target here." % weapon_name
	else:
		status_message = "%s whispers, but there is nothing to hit here." % weapon_name
	_update_overlay()


func _on_inventory_changed(next_bag_slots: Array, next_equipment_slots: Dictionary) -> void:
	bag_slots = InventoryStateScript.normalize_bag(next_bag_slots)
	equipment_slots = InventoryStateScript.normalize_equipment(next_equipment_slots)
	_apply_stats()
	_update_overlay()


func _on_item_use_requested(item_name: String) -> void:
	_use_item(item_name)


func _on_quick_item_assigned(item_name: String, _item_kind: String) -> void:
	quick_item_name = item_name
	_update_context_button()


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
		status_message = "You are already healthy."
		_update_overlay()
		return
	InventoryStateScript.remove_item(bag_slots, equipment_slots, item_name, 1)
	player_health = mini(player_max_health, player_health + heal_amount)
	status_message = "Used %s. Restored %d HP." % [item_name, heal_amount]
	_update_overlay()


func _apply_stats() -> void:
	var old_max_health: int = player_max_health
	runtime_build_state = PlayerBuildRuntimeScript.build_state(player_xp, progression_state, equipment_slots, BASE_PLAYER_HEALTH, 165.0)
	progression_state = runtime_build_state.get("progression_state", {})
	resolved_progression = runtime_build_state.get("resolved_progression", {})
	player_max_health = int(runtime_build_state.get("max_health", BASE_PLAYER_HEALTH))
	player_health = PlayerBuildRuntimeScript.adjust_health_for_max_change(player_health, old_max_health, player_max_health, true)
	PlayerBuildRuntimeScript.apply_to_player(player, runtime_build_state)


func _get_attack_value() -> int:
	return int(runtime_build_state.get("attack", 1))


func _get_defense_value() -> int:
	return int(runtime_build_state.get("defense", 0))


func _update_overlay() -> void:
	_apply_stats()
	var progression_info: Dictionary = runtime_build_state.get("progression_info", {})
	var level_value: int = int(progression_info.get("level", 1))
	var xp_into_level: int = int(progression_info.get("xp_into_level", 0))
	var xp_to_next: int = int(progression_info.get("xp_to_next", 10))
	GameSession.set_overlay_header("Village", "Ashenford")
	GameSession.set_overlay_status(player_health, player_max_health, xp_into_level, status_message, player_health <= 2, xp_to_next, level_value)
	GameSession.set_overlay_inventory_state(bag_slots, equipment_slots, player_gold)
	GameSession.set_overlay_progression_state(level_value, int(runtime_build_state.get("available_skill_points", 0)), runtime_build_state.get("overlay_allocations", {}), _get_attack_value(), _get_defense_value(), player_max_health)
	GameSession.set_overlay_skills_state(progression_state, resolved_progression)
	GameSession.set_overlay_quest_journal([
		{
			"id": "enter_dungeon",
			"title": "The Old Mine",
			"status": "Active",
			"status_text": "The village dungeon has opened.",
			"summary": "Enter the old mine.",
			"details": "Ashenford is quiet, but the old mine is awake. Speak with villagers, then enter the dungeon when ready.",
			"trackable": true
		}
	], ["enter_dungeon"])
	_update_context_button()


func _update_context_button() -> void:
	if mobile_controls == null:
		return
	var label_text: String = "Attack"
	if player != null:
		var nearby: Node = player.call("get_nearby_interactable")
		if nearby != null:
			label_text = "Enter" if nearby.is_in_group("dungeon_entrance") else "Talk"
	if mobile_controls.has_method("set_context_action_label"):
		mobile_controls.call("set_context_action_label", label_text)
	if mobile_controls.has_method("set_quick_item"):
		mobile_controls.call("set_quick_item", quick_item_name, _get_bag_item_count(quick_item_name))


func _refresh_resolved_progression() -> void:
	runtime_build_state = PlayerBuildRuntimeScript.build_state(player_xp, progression_state, equipment_slots, BASE_PLAYER_HEALTH, 165.0)
	progression_state = runtime_build_state.get("progression_state", {})
	resolved_progression = runtime_build_state.get("resolved_progression", {})


func _on_skill_node_unlock_requested(node_id: String) -> void:
	progression_state = ClassProgressionStateScript.unlock_node(progression_state, node_id, player_xp)
	_update_overlay()


func _on_skill_family_equipped(skill_family: String, slot_index: int) -> void:
	progression_state = ClassProgressionStateScript.equip_skill_family(progression_state, skill_family, slot_index, player_xp)
	_update_overlay()


func _get_bag_item_count(item_name: String) -> int:
	if item_name.is_empty():
		return 0
	var total: int = 0
	for item in bag_slots:
		var item_data: Dictionary = InventoryStateScript.normalize_item(item)
		if str(item_data.get("name", "")) == item_name:
			total += int(item_data.get("count", 1))
	return total
