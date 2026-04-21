extends Node

const SaveManagerScript = preload("res://scripts/world/save_manager.gd")
const OverlayScene = preload("res://scenes/ui/game_overlay.tscn")

var continue_requested: bool = false
var save_manager: RefCounted = SaveManagerScript.new()
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var overlay: CanvasLayer
var transition_in_progress: bool = false
var pending_spawn_marker: String = ""
var transition_state: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_fade_layer()
	_setup_overlay()


func start_new_game() -> void:
	continue_requested = false
	pending_spawn_marker = ""
	transition_state = {}
	save_manager.delete_save()
	await change_scene_with_fade("res://scenes/world/world.tscn")


func continue_game() -> void:
	continue_requested = true
	var save_data: Dictionary = save_manager.load_game()
	var scene_path := str(save_data.get("current_scene_path", "res://scenes/world/world.tscn"))
	await change_scene_with_fade(scene_path)


func return_to_menu() -> void:
	continue_requested = false
	pending_spawn_marker = ""
	transition_state = {}
	await change_scene_with_fade("res://scenes/ui/main_menu.tscn")


func has_save() -> bool:
	return save_manager.has_save()


func consume_continue_request() -> bool:
	var result := continue_requested
	continue_requested = false
	return result


func transition_to_scene(scene_path: String, spawn_marker: String = "") -> void:
	pending_spawn_marker = spawn_marker
	await change_scene_with_fade(scene_path)


func consume_spawn_marker() -> String:
	var result := pending_spawn_marker
	pending_spawn_marker = ""
	return result


func set_transition_state(state: Dictionary) -> void:
	transition_state = state.duplicate(true)


func consume_transition_state() -> Dictionary:
	var result := transition_state.duplicate(true)
	transition_state = {}
	return result


func change_scene_with_fade(scene_path: String) -> void:
	if transition_in_progress:
		return

	transition_in_progress = true
	await _fade_to(1.0, 0.2)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await _fade_to(0.0, 0.2)
	transition_in_progress = false


func _setup_fade_layer() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.03, 0.04, 0.05, 0.0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)


func _setup_overlay() -> void:
	overlay = OverlayScene.instantiate()
	add_child(overlay)


func show_game_overlay() -> void:
	if overlay != null:
		overlay.visible = true


func hide_game_overlay() -> void:
	if overlay != null:
		overlay.visible = false


func set_overlay_quest(title: String, body: String) -> void:
	if overlay != null:
		overlay.set_quest(title, body)


func set_overlay_quest_journal(entries: Array, tracked_quest_ids: Array = []) -> void:
	if overlay != null:
		overlay.set_quest_journal(entries, tracked_quest_ids)


func set_overlay_header(helper_text: String, location_text: String) -> void:
	if overlay != null:
		overlay.set_header(helper_text, location_text)


func set_overlay_status(health_value: int, max_health: int, xp_value: int, combat_text: String, low_health: bool, xp_max_value: int = 10, level_value: int = 1) -> void:
	if overlay != null:
		overlay.set_status(health_value, max_health, xp_value, combat_text, low_health, xp_max_value, level_value)


func set_overlay_inventory(_text: String) -> void:
	if overlay != null:
		overlay.set_inventory_state([], {}, 0)


func set_overlay_inventory_state(bag_slots: Variant, equipment_slots: Variant, gold_amount: int = 0) -> void:
	if overlay != null:
		overlay.set_inventory_state(bag_slots, equipment_slots, gold_amount)


func set_overlay_progression_state(level: int, unspent_points: int, allocations: Dictionary, attack_value: int, defense_value: int, max_health_value: int) -> void:
	if overlay != null:
		overlay.set_progression_state(level, unspent_points, allocations, attack_value, defense_value, max_health_value)


func set_overlay_save_status(text: String) -> void:
	if overlay != null:
		overlay.set_save_status(text)


func set_overlay_menu_locked(value: bool) -> void:
	if overlay != null:
		overlay.set_menu_locked(value)


func bind_overlay_actions(save_callable: Callable, load_callable: Callable) -> void:
	if overlay == null:
		return

	if overlay.save_requested.is_connected(save_callable):
		overlay.save_requested.disconnect(save_callable)
	if overlay.load_requested.is_connected(load_callable):
		overlay.load_requested.disconnect(load_callable)

	_disconnect_overlay_signal("save_requested")
	_disconnect_overlay_signal("load_requested")

	if save_callable.is_valid():
		overlay.save_requested.connect(save_callable)
	if load_callable.is_valid():
		overlay.load_requested.connect(load_callable)


func bind_overlay_inventory_changed(inventory_callable: Callable) -> void:
	if overlay == null:
		return

	if inventory_callable.is_valid() and overlay.inventory_changed.is_connected(inventory_callable):
		overlay.inventory_changed.disconnect(inventory_callable)

	_disconnect_overlay_signal("inventory_changed")

	if inventory_callable.is_valid():
		overlay.inventory_changed.connect(inventory_callable)


func bind_overlay_item_use_requested(use_callable: Callable) -> void:
	if overlay == null:
		return

	if use_callable.is_valid() and overlay.use_item_requested.is_connected(use_callable):
		overlay.use_item_requested.disconnect(use_callable)

	_disconnect_overlay_signal("use_item_requested")

	if use_callable.is_valid():
		overlay.use_item_requested.connect(use_callable)


func bind_overlay_quick_item_assigned(quick_callable: Callable) -> void:
	if overlay == null:
		return

	if quick_callable.is_valid() and overlay.quick_item_assigned.is_connected(quick_callable):
		overlay.quick_item_assigned.disconnect(quick_callable)

	_disconnect_overlay_signal("quick_item_assigned")

	if quick_callable.is_valid():
		overlay.quick_item_assigned.connect(quick_callable)


func bind_overlay_stat_increase_requested(stat_callable: Callable) -> void:
	if overlay == null:
		return

	if stat_callable.is_valid() and overlay.stat_increase_requested.is_connected(stat_callable):
		overlay.stat_increase_requested.disconnect(stat_callable)

	_disconnect_overlay_signal("stat_increase_requested")

	if stat_callable.is_valid():
		overlay.stat_increase_requested.connect(stat_callable)


func bind_overlay_menu_toggled(menu_callable: Callable) -> void:
	if overlay == null:
		return

	if menu_callable.is_valid() and overlay.menu_toggled.is_connected(menu_callable):
		overlay.menu_toggled.disconnect(menu_callable)

	_disconnect_overlay_signal("menu_toggled")

	if menu_callable.is_valid():
		overlay.menu_toggled.connect(menu_callable)


func bind_overlay_tracked_quest_changed(track_callable: Callable) -> void:
	if overlay == null:
		return

	if track_callable.is_valid() and overlay.tracked_quest_toggled.is_connected(track_callable):
		overlay.tracked_quest_toggled.disconnect(track_callable)

	_disconnect_overlay_signal("tracked_quest_toggled")

	if track_callable.is_valid():
		overlay.tracked_quest_toggled.connect(track_callable)


func build_quest_journal_entries(
	quest_stage: String,
	quest_two_stage: String,
	rowan_offer_state: String,
	summary_max_length: int = 44,
	rat_quest_stage: String = "locked",
	rat_tail_count: int = 0,
	rat_tail_goal: int = 10
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	var intro_summary := ""
	var intro_status := ""
	var intro_status_text := ""
	var intro_details := ""

	match quest_stage:
		"not_started":
			intro_status = "Available"
			intro_status_text = "Elder Rowan has a simple village errand waiting."
			intro_summary = "Speak with Rowan in the square."
			intro_details = "Rowan wants to see whether you can listen, explore, and report back. Start by speaking with him in Oakcross Village."
		"in_progress":
			intro_status = "Active"
			intro_status_text = "Rowan sent you to check in with Mira."
			intro_summary = "Talk to Mira, then return to Rowan."
			intro_details = "Rowan asked you to find Mira by the market stall. Once you've spoken to her, return to Rowan with the update."
		"ready_to_turn_in":
			intro_status = "Return"
			intro_status_text = "Mira has given you what Rowan needs."
			intro_summary = "Return to Rowan."
			intro_details = "You've checked in with Mira and learned what Rowan wanted to know. Head back to Rowan in the square to complete the errand."
		"complete":
			intro_status = "Complete"
			intro_status_text = "Your first Oakcross errand is finished."
			intro_summary = "Village Introduction complete."
			intro_details = "You found Mira, returned to Rowan, and proved you can follow through on simple village work."
		_:
			intro_status = "Active"
			intro_status_text = "Explore Oakcross Village."
			intro_summary = "Explore Oakcross Village."
			intro_details = "Spend some time learning the village layout and speaking with its residents."

	if quest_stage != "not_started":
		entries.append({
			"id": "village_intro",
			"title": "Village Introduction",
			"status": intro_status,
			"status_text": intro_status_text,
			"summary": _compress_text(intro_summary, summary_max_length),
			"details": intro_details,
			"trackable": intro_status != "Complete"
		})

	var supply_status := ""
	var supply_status_text := ""
	var supply_summary := ""
	var supply_details := ""

	match quest_two_stage:
		"locked":
			supply_status = "Locked"
			if rowan_offer_state == "declined":
				supply_status_text = "Rowan is waiting until you're ready."
				supply_summary = "Speak to Rowan when you're ready."
				supply_details = "You turned Rowan down for now. Return to him once you're ready to take on the village supply run."
			else:
				supply_status_text = "A second assignment is available after the introduction quest."
				supply_summary = "Speak to Rowan for more work."
				supply_details = "Rowan has another task lined up, but he'll only brief you once the time is right."
		"visit_sign":
			supply_status = "Active"
			supply_status_text = "Rowan wants you to confirm the route."
			supply_summary = "Read the village sign."
			supply_details = "Start the supply run by reading the village sign in the square, then continue toward the sealed supply chest."
		"open_chest":
			supply_status = "Active"
			supply_status_text = "You know the route. Time to collect the ledger."
			supply_summary = "Open the eastern supply chest."
			supply_details = "Head to the eastern house area, open the sealed chest, and recover Mira's supply ledger."
		"report_to_mira":
			supply_status = "Return"
			supply_status_text = "The ledger is in your pack."
			supply_summary = "Bring the ledger to Mira."
			supply_details = "You've recovered Mira's supply ledger. Bring it back to her at the market to complete the delivery."
		"complete":
			supply_status = "Complete"
			supply_status_text = "Mira received the ledger and rewarded you."
			supply_summary = "Supply Run complete."
			supply_details = "You followed Rowan's route, recovered the sealed ledger, and returned it to Mira in exchange for healer's herbs."
		_:
			supply_status = "Locked"
			supply_status_text = "No current update."
			supply_summary = "Speak to Rowan for more work."
			supply_details = "Rowan will let you know when the next part of the supply route is ready."

	if quest_two_stage != "locked":
		entries.append({
			"id": "supply_run",
			"title": "Supply Run",
			"status": supply_status,
			"status_text": supply_status_text,
			"summary": _compress_text(supply_summary, summary_max_length),
			"details": supply_details,
			"trackable": supply_status != "Complete"
		})

	var rat_status := ""
	var rat_status_text := ""
	var rat_summary := ""
	var rat_details := ""
	var clamped_rat_tail_count: int = clampi(rat_tail_count, 0, rat_tail_goal)

	match rat_quest_stage:
		"not_started":
			rat_status = "Available"
			rat_status_text = "Mira has heard rats in the southern field."
			rat_summary = "Speak to Mira about the infestation."
			rat_details = "Mira has a rat problem near the south road. Talk with her at the market to hear what she needs."
		"active":
			if clamped_rat_tail_count >= rat_tail_goal:
				rat_status = "Return"
				rat_status_text = "You have enough rat tails for Mira."
				rat_summary = "Return to Mira with %d Rat Tails." % rat_tail_goal
				rat_details = "You've collected %d/%d Rat Tails. Bring them back to Mira so she knows the infestation was handled." % [clamped_rat_tail_count, rat_tail_goal]
			else:
				rat_status = "Active"
				rat_status_text = "Mira wants proof the rats are gone."
				rat_summary = "Collect Rat Tails: %d/%d." % [clamped_rat_tail_count, rat_tail_goal]
				rat_details = "The southern field is crawling with rats. Defeat rats, pick up their tails, and bring %d Rat Tails back to Mira. Progress: %d/%d." % [rat_tail_goal, clamped_rat_tail_count, rat_tail_goal]
		"complete":
			rat_status = "Complete"
			rat_status_text = "Mira's rat problem is under control."
			rat_summary = "Rat Infestation complete."
			rat_details = "You cleared the southern rats and brought Mira proof of the work."
		_:
			rat_status = "Locked"

	if rat_quest_stage != "locked" and rat_quest_stage != "not_started":
		entries.append({
			"id": "rat_infestation",
			"title": "Rat Infestation",
			"status": rat_status,
			"status_text": rat_status_text,
			"summary": _compress_text(rat_summary, summary_max_length),
			"details": rat_details,
			"trackable": rat_status != "Complete"
		})

	return entries


func normalize_tracked_quest_array(raw_value: Variant, max_tracked: int = 5) -> Array[String]:
	var result: Array[String] = []

	if typeof(raw_value) == TYPE_STRING:
		var single_id: String = str(raw_value)
		if not single_id.is_empty():
			result.append(single_id)
		return result

	if typeof(raw_value) != TYPE_ARRAY:
		return result

	for quest_id_variant in raw_value:
		var quest_id: String = str(quest_id_variant)
		if quest_id.is_empty() or result.has(quest_id):
			continue
		result.append(quest_id)
		if result.size() >= max_tracked:
			break

	return result


func normalize_tracked_quest_ids(current_ids: Array[String], entries: Array[Dictionary], max_tracked: int = 5) -> Array[String]:
	var valid_ids: Array[String] = []
	for entry in entries:
		if bool(entry.get("trackable", true)):
			valid_ids.append(str(entry.get("id", "")))

	var next_ids: Array[String] = []
	for quest_id in current_ids:
		if valid_ids.has(quest_id) and not next_ids.has(quest_id):
			next_ids.append(quest_id)
		if next_ids.size() >= max_tracked:
			break

	return next_ids


func toggle_tracked_quest(current_ids: Array[String], quest_id: String, max_tracked: int = 5) -> Array[String]:
	var next_ids: Array[String] = current_ids.duplicate()
	if quest_id.is_empty():
		return next_ids

	if next_ids.has(quest_id):
		next_ids.erase(quest_id)
		return next_ids

	if next_ids.size() >= max_tracked:
		next_ids.remove_at(0)
	next_ids.append(quest_id)
	return next_ids


func autofill_tracked_quest_ids(current_ids: Array[String], entries: Array[Dictionary], max_tracked: int = 5) -> Array[String]:
	var next_ids: Array[String] = normalize_tracked_quest_ids(current_ids, entries, max_tracked)
	if next_ids.size() >= max_tracked:
		return next_ids

	for entry in entries:
		var quest_id: String = str(entry.get("id", ""))
		if quest_id.is_empty() or next_ids.has(quest_id):
			continue
		next_ids.append(quest_id)
		if next_ids.size() >= max_tracked:
			break

	return next_ids


func update_tracked_quests_for_new_entries(current_ids: Array[String], known_ids: Array[String], entries: Array[Dictionary], max_tracked: int = 5) -> Dictionary:
	var next_ids: Array[String] = normalize_tracked_quest_ids(current_ids, entries, max_tracked)
	var entry_ids: Array[String] = []

	for entry in entries:
		var quest_id: String = str(entry.get("id", ""))
		if quest_id.is_empty():
			continue
		entry_ids.append(quest_id)
		if not bool(entry.get("trackable", true)):
			continue
		if known_ids.has(quest_id) or next_ids.has(quest_id):
			continue
		if next_ids.size() >= max_tracked:
			break
		next_ids.append(quest_id)

	return {
		"tracked_ids": next_ids,
		"known_ids": entry_ids
	}


func _disconnect_overlay_signal(signal_name: String) -> void:
	if overlay == null:
		return

	var connections: Array = overlay.get_signal_connection_list(signal_name)

	for connection in connections:
		var callable: Callable = connection.get("callable", Callable())
		if callable.is_valid():
			overlay.disconnect(signal_name, callable)


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", alpha, duration)
	await tween.finished


func _compress_text(text: String, max_length: int) -> String:
	if text.length() <= max_length:
		return text

	if max_length <= 3:
		return text.substr(0, max_length)

	return text.substr(0, max_length - 3).rstrip(" ,.") + "..."
