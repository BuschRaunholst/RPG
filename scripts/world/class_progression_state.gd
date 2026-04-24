extends RefCounted

const ProgressionScript = preload("res://scripts/world/progression.gd")
const SkillTreeResolverScript = preload("res://scripts/world/skill_tree_resolver.gd")

const DEFAULT_CLASS_ID := "rogue"
const SKILL_SLOT_COUNT := 4
const CLASS_IDS := ["rogue", "mage", "fighter"]
const CLASS_STARTER_DATA := {
	"rogue": {
		"unlocked_node_ids": ["rogue_start"],
		"equipped_skill_families": ["", "", "", ""]
	},
	"mage": {
		"unlocked_node_ids": ["mage_start", "firebolt_1"],
		"equipped_skill_families": ["firebolt", "", "", ""]
	},
	"fighter": {
		"unlocked_node_ids": ["fighter_start", "cleave_1"],
		"equipped_skill_families": ["cleave", "", "", ""]
	}
}


static func normalize_class_id(raw_value: Variant) -> String:
	var class_id: String = str(raw_value).to_lower()
	return class_id if CLASS_IDS.has(class_id) else DEFAULT_CLASS_ID


static func create_new_state(class_id: String) -> Dictionary:
	var normalized_class_id: String = normalize_class_id(class_id)
	var starter_data: Dictionary = CLASS_STARTER_DATA.get(normalized_class_id, CLASS_STARTER_DATA[DEFAULT_CLASS_ID])
	return {
		"class_id": normalized_class_id,
		"available_skill_points": 0,
		"unlocked_node_ids": normalize_node_ids(starter_data.get("unlocked_node_ids", [])),
		"equipped_skill_families": normalize_equipped_skill_families(starter_data.get("equipped_skill_families", [])),
		"milestone_points_claimed": []
	}


static func normalize_state(raw_value: Variant, total_xp: int = 0) -> Dictionary:
	if typeof(raw_value) != TYPE_DICTIONARY:
		return sync_state(create_new_state(DEFAULT_CLASS_ID), total_xp)

	var raw_state: Dictionary = raw_value
	var class_id: String = normalize_class_id(raw_state.get("class_id", DEFAULT_CLASS_ID))
	var starter_state: Dictionary = create_new_state(class_id)
	var starter_nodes: Array[String] = starter_state.get("unlocked_node_ids", [])
	var unlocked_nodes: Array[String] = starter_nodes.duplicate()
	var raw_unlocked_nodes: Variant = raw_state.get("unlocked_node_ids", starter_nodes)
	if typeof(raw_unlocked_nodes) == TYPE_ARRAY:
		for node_variant in raw_unlocked_nodes:
			var node_id: String = str(node_variant)
			if node_id.is_empty() or unlocked_nodes.has(node_id):
				continue
			unlocked_nodes.append(node_id)

	var equipped_skill_families: Array[String] = normalize_equipped_skill_families(raw_state.get("equipped_skill_families", starter_state.get("equipped_skill_families", [])))
	var claimed_milestones: Array[String] = ProgressionScript.normalize_claimed_milestones(raw_state.get("milestone_points_claimed", []))
	var normalized_state := {
		"class_id": class_id,
		"available_skill_points": maxi(0, int(raw_state.get("available_skill_points", 0))),
		"unlocked_node_ids": unlocked_nodes,
		"equipped_skill_families": equipped_skill_families,
		"milestone_points_claimed": claimed_milestones
	}
	return sync_state(normalized_state, total_xp)


static func sync_state(raw_state: Variant, total_xp: int) -> Dictionary:
	var normalized_state: Dictionary = raw_state if typeof(raw_state) == TYPE_DICTIONARY else create_new_state(DEFAULT_CLASS_ID)
	var class_id: String = normalize_class_id(normalized_state.get("class_id", DEFAULT_CLASS_ID))
	var spent_points: int = get_spent_skill_points(normalized_state)
	var earned_points: int = ProgressionScript.get_total_skill_points_earned(total_xp, normalized_state.get("milestone_points_claimed", []))
	normalized_state["class_id"] = class_id
	normalized_state["available_skill_points"] = maxi(0, earned_points - spent_points)
	normalized_state["equipped_skill_families"] = normalize_equipped_skill_families(normalized_state.get("equipped_skill_families", []))
	return normalized_state


static func get_spent_skill_points(raw_state: Variant) -> int:
	var state: Dictionary = raw_state if typeof(raw_state) == TYPE_DICTIONARY else create_new_state(DEFAULT_CLASS_ID)
	var class_id: String = normalize_class_id(state.get("class_id", DEFAULT_CLASS_ID))
	var unlocked_nodes: Array = state.get("unlocked_node_ids", [])
	return maxi(0, unlocked_nodes.size() - get_starting_node_ids(class_id).size())


static func get_starting_node_ids(class_id: String) -> Array[String]:
	var normalized_class_id: String = normalize_class_id(class_id)
	var starter_data: Dictionary = CLASS_STARTER_DATA.get(normalized_class_id, CLASS_STARTER_DATA[DEFAULT_CLASS_ID])
	return normalize_node_ids(starter_data.get("unlocked_node_ids", []))


static func normalize_node_ids(raw_value: Variant) -> Array[String]:
	var node_ids: Array[String] = []
	if typeof(raw_value) != TYPE_ARRAY:
		return node_ids

	for node_variant in raw_value:
		var node_id: String = str(node_variant)
		if node_id.is_empty() or node_ids.has(node_id):
			continue
		node_ids.append(node_id)

	return node_ids


static func normalize_equipped_skill_families(raw_value: Variant) -> Array[String]:
	var equipped_skills: Array[String] = []
	if typeof(raw_value) == TYPE_ARRAY:
		for family_variant in raw_value:
			if equipped_skills.size() >= SKILL_SLOT_COUNT:
				break
			equipped_skills.append(str(family_variant))

	while equipped_skills.size() < SKILL_SLOT_COUNT:
		equipped_skills.append("")

	return equipped_skills


static func can_unlock_node(raw_state: Variant, node_id: String, total_xp: int) -> bool:
	var state: Dictionary = normalize_state(raw_state, total_xp)
	if node_id.is_empty():
		return false
	if int(state.get("available_skill_points", 0)) <= 0:
		return false
	return SkillTreeResolverScript.is_node_unlockable(
		str(state.get("class_id", DEFAULT_CLASS_ID)),
		node_id,
		state.get("unlocked_node_ids", [])
	)


static func unlock_node(raw_state: Variant, node_id: String, total_xp: int) -> Dictionary:
	var state: Dictionary = normalize_state(raw_state, total_xp)
	if not can_unlock_node(state, node_id, total_xp):
		return state

	var unlocked_nodes: Array[String] = []
	for node_variant in state.get("unlocked_node_ids", []):
		unlocked_nodes.append(str(node_variant))
	unlocked_nodes.append(node_id)
	state["unlocked_node_ids"] = unlocked_nodes
	return sync_state(state, total_xp)


static func equip_skill_family(raw_state: Variant, skill_family: String, slot_index: int, total_xp: int) -> Dictionary:
	var state: Dictionary = normalize_state(raw_state, total_xp)
	if slot_index < 0 or slot_index >= SKILL_SLOT_COUNT:
		return state

	var resolved_tree: Dictionary = SkillTreeResolverScript.resolve(
		str(state.get("class_id", DEFAULT_CLASS_ID)),
		state.get("unlocked_node_ids", [])
	)
	var active_skill_tiers: Dictionary = resolved_tree.get("active_skill_tiers", {})
	if not skill_family.is_empty() and not active_skill_tiers.has(skill_family):
		return state

	var equipped_skills: Array[String] = normalize_equipped_skill_families(state.get("equipped_skill_families", []))
	equipped_skills[slot_index] = skill_family
	state["equipped_skill_families"] = equipped_skills
	return state
