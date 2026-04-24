extends RefCounted

const InventoryStateScript = preload("res://scripts/world/inventory_state.gd")
const ClassProgressionStateScript = preload("res://scripts/world/class_progression_state.gd")
const ProgressionScript = preload("res://scripts/world/progression.gd")
const SkillTreeResolverScript = preload("res://scripts/world/skill_tree_resolver.gd")


static func build_state(total_xp: int, raw_progression_state: Variant, raw_equipment_slots: Variant, base_max_health: int, base_move_speed: float) -> Dictionary:
	var progression_state: Dictionary = ClassProgressionStateScript.normalize_state(raw_progression_state, total_xp)
	var equipment_slots: Dictionary = InventoryStateScript.normalize_equipment(raw_equipment_slots)
	var resolved_progression: Dictionary = SkillTreeResolverScript.resolve(
		str(progression_state.get("class_id", ClassProgressionStateScript.DEFAULT_CLASS_ID)),
		progression_state.get("unlocked_node_ids", [])
	)
	var runtime_bonuses: Dictionary = SkillTreeResolverScript.get_runtime_bonuses(resolved_progression, equipment_slots)
	var equipment_totals: Dictionary = InventoryStateScript.get_equipment_totals(equipment_slots)
	var progression_info: Dictionary = ProgressionScript.get_progression_state(
		total_xp,
		progression_state.get("milestone_points_claimed", [])
	)

	return {
		"progression_state": progression_state,
		"resolved_progression": resolved_progression,
		"runtime_bonuses": runtime_bonuses,
		"equipment_totals": equipment_totals,
		"equipment_slots": equipment_slots,
		"progression_info": progression_info,
		"level": int(progression_info.get("level", 1)),
		"available_skill_points": int(progression_state.get("available_skill_points", 0)),
		"attack": 1 + int(runtime_bonuses.get("attack", 0)) + int(equipment_totals.get("attack", 0)),
		"defense": int(runtime_bonuses.get("defense", 0)) + int(equipment_totals.get("defense", 0)),
		"max_health": base_max_health + int(runtime_bonuses.get("max_health", 0)) + int(equipment_totals.get("max_health", 0)),
		"move_speed": base_move_speed + float(runtime_bonuses.get("move_speed", 0)),
		"mana": int(runtime_bonuses.get("mana", 0)),
		"mana_regen": int(runtime_bonuses.get("mana_regen", 0)),
		"overlay_allocations": SkillTreeResolverScript.get_legacy_overlay_allocations(resolved_progression)
	}


static func adjust_health_for_max_change(current_health: int, old_max_health: int, new_max_health: int, keep_minimum_one: bool) -> int:
	if new_max_health <= 0:
		return 0
	if old_max_health <= 0:
		return clampi(current_health, 1 if keep_minimum_one else 0, new_max_health)

	var next_health: int = current_health
	if new_max_health != old_max_health:
		next_health += new_max_health - old_max_health
	return clampi(next_health, 1 if keep_minimum_one else 0, new_max_health)


static func apply_to_player(player: Node, build_state: Dictionary) -> void:
	if player == null:
		return
	player.set("move_speed", float(build_state.get("move_speed", player.get("move_speed"))))
	if player.has_method("set_equipment_visuals"):
		player.call("set_equipment_visuals", build_state.get("equipment_slots", {}))
