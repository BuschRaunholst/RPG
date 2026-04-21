extends Node2D

const InventoryStateScript = preload("res://scripts/world/inventory_state.gd")
const InteractionControllerScript = preload("res://scripts/world/interaction_controller.gd")
const ProgressionScript = preload("res://scripts/world/progression.gd")
const SaveManagerScript = preload("res://scripts/world/save_manager.gd")
const BASE_PLAYER_MAX_HEALTH := 5
const BASE_PLAYER_MOVE_SPEED := 180.0

@onready var player: Node = $Player
@onready var dialogue_box: Node = $DialogueBox
@onready var mobile_controls: Node = $CanvasLayer/MobileControls

var save_manager: RefCounted = SaveManagerScript.new()
var interaction_controller: RefCounted = InteractionControllerScript.new()
var quest_stage: String = "not_started"
var quest_two_stage: String = "locked"
var rat_quest_stage: String = "locked"
var rowan_offer_state: String = "unseen"
var inventory_slots: Array[Dictionary] = InventoryStateScript.create_empty_bag()
var equipment_slots: Dictionary = InventoryStateScript.normalize_equipment(null)
var player_health: int = 5
var player_max_health: int = 5
var player_xp: int = 0
var player_level: int = 1
var player_unspent_stat_points: int = 0
var player_allocations := {
	"strength": 1,
	"stamina": 1,
	"dexterity": 1
}
var player_gold: int = 18
var tracked_quest_ids: Array[String] = []
var known_quest_entry_ids: Array[String] = []
var quick_item_name: String = ""
var quick_item_kind: String = "consumable"
var gameplay_paused: bool = false


func _ready() -> void:
	GameSession.show_game_overlay()
	GameSession.bind_overlay_actions(Callable(self, "_on_save_button_pressed"), Callable(self, "_on_load_button_pressed"))
	GameSession.bind_overlay_inventory_changed(Callable(self, "_on_inventory_layout_changed"))
	GameSession.bind_overlay_item_use_requested(Callable(self, "_on_inventory_item_use_requested"))
	GameSession.bind_overlay_quick_item_assigned(Callable(self, "_on_quick_item_assigned"))
	GameSession.bind_overlay_stat_increase_requested(Callable(self, "_on_stat_increase_requested"))
	GameSession.bind_overlay_menu_toggled(Callable(self, "_on_menu_toggled"))
	GameSession.bind_overlay_tracked_quest_changed(Callable(self, "_on_tracked_quest_changed"))
	GameSession.set_overlay_header("Tap the door to head back outside", "Blue House")
	player.interacted.connect(_on_player_interacted)
	if player.has_signal("context_action_requested") and not player.is_connected("context_action_requested", Callable(self, "_on_context_action_pressed")):
		player.connect("context_action_requested", Callable(self, "_on_context_action_pressed"))
	dialogue_box.dialogue_finished.connect(_on_dialogue_finished)
	if mobile_controls.has_signal("quick_item_pressed"):
		mobile_controls.quick_item_pressed.connect(_on_quick_item_button_pressed)
	if mobile_controls.has_signal("context_action_pressed"):
		mobile_controls.context_action_pressed.connect(_on_context_action_pressed)
	_register_tap_interactables()
	_load_ui_state_from_save()
	_recalculate_player_stats()
	_refresh_status_panel()
	_update_quest_log()
	_update_inventory_log()
	_update_save_status()

	var transition_state: Dictionary = GameSession.consume_transition_state()
	if not transition_state.is_empty():
		_apply_save_data(transition_state)
		_apply_pending_spawn_marker()
	elif GameSession.consume_continue_request():
		_load_continue_save()
	else:
		_apply_pending_spawn_marker()


func _process(_delta: float) -> void:
	_update_context_action_button()


func _on_player_interacted(target: Node) -> void:
	if gameplay_paused:
		return

	if dialogue_box.is_open:
		dialogue_box.advance_dialogue()
		return

	if _handle_exit_transition(target):
		return

	if not target.has_method("get_dialogue_lines"):
		return

	var lines: PackedStringArray = target.get_dialogue_lines()
	if lines.is_empty():
		return

	player.set_can_move(false)
	GameSession.set_overlay_menu_locked(true)
	dialogue_box.start_dialogue(_get_speaker_name(target), lines)


func _on_dialogue_finished() -> void:
	player.set_can_move(not gameplay_paused)
	GameSession.set_overlay_menu_locked(false)


func _register_tap_interactables() -> void:
	for child in get_children():
		if child is CollisionObject2D:
			var collision_object := child as CollisionObject2D
			collision_object.input_pickable = true
			if not collision_object.input_event.is_connected(_on_interactable_input_event.bind(child)):
				collision_object.input_event.connect(_on_interactable_input_event.bind(child))


func _on_interactable_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, target: Node) -> void:
	if gameplay_paused:
		return

	if dialogue_box.is_open:
		return

	var is_tap := false

	if event is InputEventScreenTouch:
		is_tap = event.pressed
	elif event is InputEventMouseButton:
		is_tap = event.button_index == MOUSE_BUTTON_LEFT and event.pressed

	if not is_tap:
		return

	if not player.can_interact_with(target):
		return

	_on_player_interacted(target)


func _handle_exit_transition(target: Node) -> bool:
	var exit_scene_value: Variant = target.get("exit_scene_path")
	if exit_scene_value == null:
		return false

	var exit_scene_path := str(exit_scene_value)
	if exit_scene_path.is_empty():
		return false

	var spawn_marker := str(target.get("exit_spawn_marker"))
	var transition_state: Dictionary = _build_scene_state(exit_scene_path)
	player.set_can_move(false)
	GameSession.set_transition_state(transition_state)
	GameSession.transition_to_scene(exit_scene_path, spawn_marker)
	return true


func _get_speaker_name(target: Node) -> String:
	var npc_name: Variant = target.get("npc_name")
	if npc_name != null:
		return str(npc_name)

	var speaker_name: Variant = target.get("speaker_name")
	if speaker_name != null:
		return str(speaker_name)

	return "Resident"


func _on_save_button_pressed() -> void:
	var save_data: Dictionary = _build_scene_state("res://scenes/interiors/blue_house_interior.tscn")

	if save_manager.save_game(save_data):
		_update_save_status("Game saved")
	else:
		_update_save_status("Save failed")


func _on_load_button_pressed() -> void:
	var save_data: Dictionary = save_manager.load_game()
	if save_data.is_empty():
		_update_save_status("No save")
		return

	var scene_path := str(save_data.get("current_scene_path", ""))
	if scene_path == "res://scenes/interiors/blue_house_interior.tscn":
		_apply_save_data(save_data)
		_update_save_status("Game loaded")
	else:
		GameSession.continue_requested = true
		GameSession.transition_to_scene(scene_path)


func _load_continue_save() -> void:
	var save_data: Dictionary = save_manager.load_game()
	if save_data.is_empty():
		_update_save_status("No save")
		return

	_apply_save_data(save_data)
	_update_save_status("Continued")


func _apply_save_data(save_data: Dictionary) -> void:
	var player_position_data: Dictionary = save_data.get("player_position", {})
	var x_value: float = float(player_position_data.get("x", player.global_position.x))
	var y_value: float = float(player_position_data.get("y", player.global_position.y))
	player.global_position = Vector2(x_value, y_value)
	_apply_ui_state(save_data)
	_refresh_status_panel()
	_update_quest_log()
	_update_inventory_log()


func _apply_pending_spawn_marker() -> void:
	var marker_name := GameSession.consume_spawn_marker()
	if marker_name.is_empty():
		return

	var marker: Node = get_node_or_null("SpawnPoints/%s" % marker_name)
	if marker is Marker2D:
		player.global_position = marker.global_position


func _update_save_status(message: String = "") -> void:
	if not message.is_empty():
		GameSession.set_overlay_save_status(message)
		return

	if save_manager.has_save():
		GameSession.set_overlay_save_status("Ready")
	else:
		GameSession.set_overlay_save_status("No save")


func _load_ui_state_from_save() -> void:
	var save_data: Dictionary = save_manager.load_game()
	if save_data.is_empty():
		return

	_apply_ui_state(save_data)


func _apply_ui_state(save_data: Dictionary) -> void:
	quest_stage = str(save_data.get("quest_stage", quest_stage))
	quest_two_stage = str(save_data.get("quest_two_stage", quest_two_stage))
	rat_quest_stage = str(save_data.get("rat_quest_stage", rat_quest_stage))
	rowan_offer_state = str(save_data.get("rowan_offer_state", rowan_offer_state))
	player_health = int(save_data.get("player_health", player_health))
	player_xp = int(save_data.get("player_xp", player_xp))
	player_allocations = ProgressionScript.normalize_allocations(save_data.get("player_allocations", player_allocations))
	player_gold = int(save_data.get("player_gold", player_gold))
	tracked_quest_ids = GameSession.normalize_tracked_quest_array(save_data.get("tracked_quest_ids", save_data.get("tracked_quest_id", tracked_quest_ids)))
	known_quest_entry_ids = GameSession.normalize_tracked_quest_array(save_data.get("known_quest_entry_ids", known_quest_entry_ids))
	quick_item_name = str(save_data.get("quick_item_name", quick_item_name))
	quick_item_kind = str(save_data.get("quick_item_kind", quick_item_kind))
	inventory_slots = InventoryStateScript.normalize_bag(save_data.get("inventory_items", {}))
	equipment_slots = InventoryStateScript.normalize_equipment(save_data.get("equipment_slots", null))
	if quest_two_stage == "complete" and rat_quest_stage == "locked":
		rat_quest_stage = "not_started"
	_recalculate_player_stats()


func _update_quest_log() -> void:
	var journal_entries: Array[Dictionary] = _build_quest_journal_entries()
	var tracking_state: Dictionary = GameSession.update_tracked_quests_for_new_entries(
		tracked_quest_ids,
		known_quest_entry_ids,
		journal_entries
	)
	tracked_quest_ids = tracking_state.get("tracked_ids", [])
	known_quest_entry_ids = tracking_state.get("known_ids", [])
	if journal_entries.is_empty():
		tracked_quest_ids.clear()
		known_quest_entry_ids.clear()
	GameSession.set_overlay_quest_journal(journal_entries, tracked_quest_ids)


func _update_inventory_log() -> void:
	if quest_two_stage == "complete":
		InventoryStateScript.remove_item(inventory_slots, equipment_slots, "Supply Ledger", 999)
	if not _has_item_in_bag(quick_item_name):
		quick_item_name = ""
		quick_item_kind = "consumable"

	GameSession.set_overlay_inventory_state(inventory_slots, equipment_slots, player_gold)
	var equipment_totals: Dictionary = InventoryStateScript.get_equipment_totals(equipment_slots)
	var stat_bonuses: Dictionary = ProgressionScript.get_stat_bonuses(player_allocations)
	GameSession.set_overlay_progression_state(
		player_level,
		player_unspent_stat_points,
		player_allocations,
		1 + int(equipment_totals.get("attack", 0)) + int(stat_bonuses.get("attack", 0)),
		int(equipment_totals.get("defense", 0)) + int(stat_bonuses.get("defense", 0)),
		player_max_health
	)
	_update_quick_item_button()


func _refresh_status_panel() -> void:
	var progression_state: Dictionary = ProgressionScript.get_progression_state(player_xp, player_allocations)
	GameSession.set_overlay_status(
		player_health,
		player_max_health,
		int(progression_state.get("xp_into_level", 0)),
		"Safe indoors.",
		player_health <= 1,
		int(progression_state.get("xp_to_next", 10)),
		player_level
	)


func _build_scene_state(current_scene_path: String) -> Dictionary:
	var save_data: Dictionary = save_manager.load_game()

	save_data["current_scene_path"] = current_scene_path
	save_data["player_position"] = {
		"x": player.global_position.x,
		"y": player.global_position.y
	}
	save_data["player_health"] = player_health
	save_data["player_xp"] = player_xp
	save_data["player_allocations"] = player_allocations.duplicate(true)
	save_data["player_gold"] = player_gold
	save_data["tracked_quest_ids"] = tracked_quest_ids.duplicate()
	save_data["known_quest_entry_ids"] = known_quest_entry_ids.duplicate()
	save_data["quick_item_name"] = quick_item_name
	save_data["quick_item_kind"] = quick_item_kind
	save_data["quest_stage"] = quest_stage
	save_data["quest_two_stage"] = quest_two_stage
	save_data["rat_quest_stage"] = rat_quest_stage
	save_data["rowan_offer_state"] = rowan_offer_state
	save_data["inventory_items"] = inventory_slots.duplicate(true)
	save_data["equipment_slots"] = equipment_slots.duplicate(true)

	return save_data


func _on_inventory_layout_changed(next_bag_slots: Array, next_equipment_slots: Dictionary) -> void:
	inventory_slots = InventoryStateScript.normalize_bag(next_bag_slots)
	equipment_slots = InventoryStateScript.normalize_equipment(next_equipment_slots)
	_recalculate_player_stats()
	_update_inventory_log()
	_refresh_status_panel()
	_autosave("Autosaved gear")


func _on_stat_increase_requested(stat_name: String) -> void:
	if player_unspent_stat_points <= 0:
		_update_save_status("No stat points available")
		return

	player_allocations = ProgressionScript.increase_stat(player_allocations, stat_name)
	_recalculate_player_stats()
	_update_inventory_log()
	_refresh_status_panel()
	_autosave("Autosaved stats")


func _on_inventory_item_use_requested(item_name: String) -> void:
	_use_consumable_item(item_name, true)


func _on_quick_item_assigned(item_name: String, item_kind: String) -> void:
	quick_item_name = item_name
	quick_item_kind = item_kind
	_update_quick_item_button()
	_update_save_status("Quick item ready")


func _on_quick_item_button_pressed() -> void:
	if gameplay_paused or dialogue_box.is_open:
		return

	_use_consumable_item(quick_item_name, false)


func _on_context_action_pressed() -> void:
	if gameplay_paused:
		return

	var nearby_target: Node = player.get_nearby_interactable()
	match interaction_controller.resolve_context_action(dialogue_box.is_open, false, false, nearby_target):
		"next":
			dialogue_box.advance_dialogue()
		"use", "talk":
			player.try_interact()
		_:
			player.try_attack()


func _on_menu_toggled(is_open: bool) -> void:
	gameplay_paused = is_open

	if mobile_controls.has_method("set_controls_enabled"):
		mobile_controls.call("set_controls_enabled", not is_open)

	player.set_can_move(not is_open and not dialogue_box.is_open)


func _on_tracked_quest_changed(quest_id: String) -> void:
	tracked_quest_ids = GameSession.toggle_tracked_quest(tracked_quest_ids, quest_id)
	_update_quest_log()


func _recalculate_player_stats() -> void:
	var progression_state: Dictionary = ProgressionScript.get_progression_state(player_xp, player_allocations)
	var stat_totals: Dictionary = InventoryStateScript.get_equipment_totals(equipment_slots)
	var stat_bonuses: Dictionary = ProgressionScript.get_stat_bonuses(progression_state.get("allocations", {}))
	player_level = int(progression_state.get("level", 1))
	player_unspent_stat_points = int(progression_state.get("unspent_points", 0))
	player_allocations = ProgressionScript.normalize_allocations(progression_state.get("allocations", {}))
	player_max_health = BASE_PLAYER_MAX_HEALTH + int(stat_totals.get("max_health", 0)) + int(stat_bonuses.get("max_health", 0))
	player_health = clampi(player_health, 0, player_max_health)
	player.set("move_speed", BASE_PLAYER_MOVE_SPEED + float(stat_bonuses.get("move_speed", 0)))


func _use_consumable_item(item_name: String, from_menu: bool) -> void:
	if item_name.is_empty():
		if from_menu:
			_update_save_status("Select an item first")
		else:
			_set_status_message("No quick item set.")
		return

	if not _has_item_in_bag(item_name):
		if quick_item_name == item_name:
			quick_item_name = ""
			quick_item_kind = "consumable"
			_update_quick_item_button()

		if from_menu:
			_update_save_status("Item not in bag")
		else:
			_set_status_message("You're out of %s." % item_name)
		return

	var consumable_effects: Dictionary = InventoryStateScript.get_consumable_effects(item_name)
	if consumable_effects.is_empty():
		if from_menu:
			_update_save_status("That item can't be used")
		return

	var heal_amount: int = int(consumable_effects.get("heal", 0))
	if heal_amount > 0 and player_health >= player_max_health:
		if from_menu:
			_update_save_status("HP is already full")
		else:
			_set_status_message("HP is already full.")
		return

	var previous_health: int = player_health
	player_health = mini(player_max_health, player_health + heal_amount)
	var restored_amount: int = player_health - previous_health

	InventoryStateScript.remove_item(inventory_slots, equipment_slots, item_name, 1)
	_update_inventory_log()
	_refresh_status_panel()
	_autosave("Autosaved item use")

	var result_message := "Used %s." % item_name
	if restored_amount > 0:
		result_message += " Restored %d HP." % restored_amount

	if from_menu:
		_update_save_status(result_message)
	else:
		_set_status_message(result_message)


func _update_context_action_button() -> void:
	if not mobile_controls.has_method("set_context_action_label"):
		return

	var nearby_target: Node = player.get_nearby_interactable()
	var action_label: String = interaction_controller.resolve_context_action(dialogue_box.is_open, false, false, nearby_target).capitalize()
	mobile_controls.call("set_context_action_label", action_label)


func _has_item_in_bag(item_name: String) -> bool:
	return _get_item_count(item_name) > 0


func _get_item_count(item_name: String) -> int:
	if item_name.is_empty():
		return 0

	var total_count: int = 0
	for item_data in inventory_slots:
		var normalized_item: Dictionary = InventoryStateScript.normalize_item(item_data)
		if normalized_item.is_empty():
			continue
		if str(normalized_item.get("name", "")) != item_name:
			continue
		total_count += int(normalized_item.get("count", 1))

	return total_count


func _update_quick_item_button() -> void:
	if mobile_controls.has_method("set_quick_item"):
		mobile_controls.call("set_quick_item", quick_item_name, _get_item_count(quick_item_name))


func _autosave(status_message: String) -> void:
	if save_manager.save_game(_build_scene_state("res://scenes/interiors/blue_house_interior.tscn")):
		_update_save_status(status_message)
	else:
		_update_save_status("Autosave failed")


func _set_status_message(message: String) -> void:
	var progression_state: Dictionary = ProgressionScript.get_progression_state(player_xp, player_allocations)
	GameSession.set_overlay_status(
		player_health,
		player_max_health,
		int(progression_state.get("xp_into_level", 0)),
		message,
		player_health <= 1,
		int(progression_state.get("xp_to_next", 10)),
		player_level
	)


func _build_quest_journal_entries() -> Array[Dictionary]:
	return GameSession.build_quest_journal_entries(
		quest_stage,
		quest_two_stage,
		rowan_offer_state,
		44,
		rat_quest_stage,
		_get_item_count("Rat Tail"),
		10
	)


func _find_quest_entry_by_id(entries: Array[Dictionary], quest_id: String) -> Dictionary:
	for entry in entries:
		if str(entry.get("id", "")) == quest_id:
			return entry
	return {}
