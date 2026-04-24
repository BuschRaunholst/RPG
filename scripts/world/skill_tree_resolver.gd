extends RefCounted

const InventoryStateScript = preload("res://scripts/world/inventory_state.gd")
const RogueTreeScript = preload("res://scripts/world/rogue_skill_tree.gd")
const MageTreeScript = preload("res://scripts/world/mage_skill_tree.gd")
const FighterTreeScript = preload("res://scripts/world/fighter_skill_tree.gd")

const TREE_MAP := {
	"rogue": RogueTreeScript.TREE,
	"mage": MageTreeScript.TREE,
	"fighter": FighterTreeScript.TREE
}

const BASE_STATS := {
	"strength": 0,
	"stamina": 0,
	"dexterity": 0,
	"intelligence": 0,
	"cast_speed": 0,
	"run_speed": 0,
	"block": 0,
	"parry": 0,
	"attack_speed": 0,
	"crit": 0,
	"bow_damage": 0,
	"one_hand_damage": 0,
	"two_hand_damage": 0,
	"melee_damage": 0,
	"staff_damage": 0,
	"wand_damage": 0,
	"spell_damage": 0,
	"fire_damage": 0,
	"cold_damage": 0,
	"mana": 0,
	"mana_regen": 0,
	"max_health": 0,
	"health_regen": 0,
	"defense": 0
}


static func get_tree_for_class(class_id: String) -> Dictionary:
	return (TREE_MAP.get(class_id, TREE_MAP["rogue"]) as Dictionary).duplicate(true)


static func get_node_data(class_id: String, node_id: String) -> Dictionary:
	var tree: Dictionary = get_tree_for_class(class_id)
	var nodes: Dictionary = tree.get("nodes", {})
	return (nodes.get(node_id, {}) as Dictionary).duplicate(true)


static func get_cluster_data(class_id: String, cluster_id: String) -> Dictionary:
	var tree: Dictionary = get_tree_for_class(class_id)
	var clusters: Array = tree.get("clusters", [])
	for cluster_variant in clusters:
		if typeof(cluster_variant) != TYPE_DICTIONARY:
			continue
		var cluster: Dictionary = cluster_variant
		if str(cluster.get("id", "")) == cluster_id:
			return cluster.duplicate(true)
	return {}


static func get_completed_cluster_ids(class_id: String, unlocked_node_ids: Array) -> Array[String]:
	var tree: Dictionary = get_tree_for_class(class_id)
	var unlocked_lookup: Dictionary = _build_lookup(unlocked_node_ids)
	var completed: Array[String] = []

	for cluster_variant in tree.get("clusters", []):
		if typeof(cluster_variant) != TYPE_DICTIONARY:
			continue
		var cluster: Dictionary = cluster_variant
		var cluster_id: String = str(cluster.get("id", ""))
		if cluster_id.is_empty():
			continue
		if _is_cluster_complete(cluster, unlocked_lookup):
			completed.append(cluster_id)

	return completed


static func get_cluster_progress(class_id: String, unlocked_node_ids: Array) -> Dictionary:
	var tree: Dictionary = get_tree_for_class(class_id)
	var unlocked_lookup: Dictionary = _build_lookup(unlocked_node_ids)
	var progress := {}

	for cluster_variant in tree.get("clusters", []):
		if typeof(cluster_variant) != TYPE_DICTIONARY:
			continue
		var cluster: Dictionary = cluster_variant
		var cluster_id: String = str(cluster.get("id", ""))
		if cluster_id.is_empty():
			continue

		var outer_nodes: Array = cluster.get("outer_node_ids", [])
		var unlocked_outer: int = 0
		for node_variant in outer_nodes:
			if unlocked_lookup.has(str(node_variant)):
				unlocked_outer += 1

		progress[cluster_id] = {
			"cluster_id": cluster_id,
			"name": str(cluster.get("name", cluster_id)),
			"outer_total": outer_nodes.size(),
			"outer_unlocked": unlocked_outer,
			"is_complete": unlocked_outer >= outer_nodes.size() and outer_nodes.size() > 0,
			"center_node_id": str(cluster.get("center_node_id", ""))
		}

	return progress


static func is_node_unlockable(class_id: String, node_id: String, unlocked_node_ids: Array) -> bool:
	var tree: Dictionary = get_tree_for_class(class_id)
	var nodes: Dictionary = tree.get("nodes", {})
	if not nodes.has(node_id):
		return false

	var unlocked_lookup: Dictionary = _build_lookup(unlocked_node_ids)
	if unlocked_lookup.has(node_id):
		return false

	var node_data: Dictionary = nodes[node_id]
	var unlock_rule: String = str(node_data.get("unlock_rule", "adjacent"))

	match unlock_rule:
		"always":
			return true
		"cluster_complete":
			var cluster_id: String = str(node_data.get("cluster_id", ""))
			var cluster: Dictionary = get_cluster_data(class_id, cluster_id)
			return not cluster.is_empty() and _is_cluster_complete(cluster, unlocked_lookup)
		"adjacent_and_cluster_complete":
			var required_cluster_id: String = str(node_data.get("cluster_id", ""))
			var required_cluster: Dictionary = get_cluster_data(class_id, required_cluster_id)
			return _has_unlocked_connection(node_data, unlocked_lookup) and not required_cluster.is_empty() and _is_cluster_complete(required_cluster, unlocked_lookup)
		_:
			return _has_unlocked_connection(node_data, unlocked_lookup)


static func get_unlockable_node_ids(class_id: String, unlocked_node_ids: Array) -> Array[String]:
	var tree: Dictionary = get_tree_for_class(class_id)
	var nodes: Dictionary = tree.get("nodes", {})
	var unlockable: Array[String] = []

	for node_key in nodes.keys():
		var node_id: String = str(node_key)
		if is_node_unlockable(class_id, node_id, unlocked_node_ids):
			unlockable.append(node_id)

	return unlockable


static func resolve(class_id: String, unlocked_node_ids: Array) -> Dictionary:
	var tree: Dictionary = get_tree_for_class(class_id)
	var nodes: Dictionary = tree.get("nodes", {})
	var stats: Dictionary = BASE_STATS.duplicate(true)
	var unlocked_families := {}
	var keystones: Array[String] = []
	var valid_nodes: Array[String] = []
	var unlocked_lookup: Dictionary = {}

	for node_variant in unlocked_node_ids:
		var node_id: String = str(node_variant)
		if not nodes.has(node_id):
			continue
		if unlocked_lookup.has(node_id):
			continue
		unlocked_lookup[node_id] = true
		valid_nodes.append(node_id)

		var node_data: Dictionary = nodes[node_id]
		var effects: Dictionary = node_data.get("effects", {})
		for effect_key in effects.keys():
			if not stats.has(effect_key):
				stats[effect_key] = 0
			stats[effect_key] = int(stats.get(effect_key, 0)) + int(effects.get(effect_key, 0))

		var node_type: String = str(node_data.get("type", "passive_minor"))
		if node_type == "active_unlock" or node_type == "active_upgrade":
			var family_id: String = str(node_data.get("skill_family", ""))
			var tier: int = int(node_data.get("skill_tier", 1))
			if not family_id.is_empty():
				if not unlocked_families.has(family_id) or int(unlocked_families[family_id]) < tier:
					unlocked_families[family_id] = tier
		elif node_type == "keystone":
			keystones.append(node_id)

	var cluster_progress: Dictionary = get_cluster_progress(class_id, valid_nodes)
	var completed_cluster_ids: Array[String] = get_completed_cluster_ids(class_id, valid_nodes)
	var unlockable_node_ids: Array[String] = get_unlockable_node_ids(class_id, valid_nodes)

	return {
		"class_id": str(tree.get("class_id", class_id)),
		"start_node_id": str(tree.get("start_node_id", "")),
		"starter_active_family": str(tree.get("starter_active_family", "")),
		"regions": tree.get("regions", []).duplicate(true),
		"clusters": tree.get("clusters", []).duplicate(true),
		"stats": stats,
		"valid_unlocked_node_ids": valid_nodes,
		"active_skill_tiers": unlocked_families,
		"keystone_ids": keystones,
		"completed_cluster_ids": completed_cluster_ids,
		"cluster_progress": cluster_progress,
		"unlockable_node_ids": unlockable_node_ids
	}


static func get_runtime_bonuses(resolved_tree: Dictionary, equipment_slots: Variant) -> Dictionary:
	var stats: Dictionary = resolved_tree.get("stats", {})
	var weapon_name: String = str(InventoryStateScript.normalize_item(InventoryStateScript.normalize_equipment(equipment_slots).get("weapon", {})).get("name", ""))
	var weapon_data: Dictionary = InventoryStateScript.get_weapon_data(weapon_name)
	var weapon_type: String = str(weapon_data.get("weapon_type", ""))
	var is_two_handed: bool = bool(weapon_data.get("two_handed", false))
	var attack_bonus: int = 0

	match weapon_type:
		"bow":
			attack_bonus = int(stats.get("dexterity", 0)) * 2 + int(stats.get("bow_damage", 0))
		"staff":
			attack_bonus = int(stats.get("intelligence", 0)) * 2 + int(stats.get("staff_damage", 0)) + int(stats.get("spell_damage", 0))
		"wand":
			attack_bonus = int(stats.get("intelligence", 0)) * 2 + int(stats.get("wand_damage", 0)) + int(stats.get("spell_damage", 0))
		_:
			attack_bonus = int(stats.get("strength", 0)) * 2 + int(stats.get("melee_damage", 0))
			if is_two_handed:
				attack_bonus += int(stats.get("two_hand_damage", 0))
			else:
				attack_bonus += int(stats.get("one_hand_damage", 0))

	return {
		"attack": attack_bonus,
		"max_health": int(stats.get("max_health", 0)) + int(stats.get("stamina", 0)) * 16 + int(stats.get("strength", 0)) * 4,
		"defense": int(stats.get("defense", 0)) + int(stats.get("stamina", 0)) * 2,
		"move_speed": int(stats.get("run_speed", 0)) * 4,
		"mana": int(stats.get("mana", 0)) + int(stats.get("intelligence", 0)) * 12,
		"mana_regen": int(stats.get("mana_regen", 0)) + int(stats.get("intelligence", 0)) * 2
	}


static func get_legacy_overlay_allocations(resolved_tree: Dictionary) -> Dictionary:
	var stats: Dictionary = resolved_tree.get("stats", {})
	return {
		"strength": int(stats.get("strength", 0)),
		"stamina": int(stats.get("stamina", 0)),
		"dexterity": int(stats.get("dexterity", 0))
	}


static func _build_lookup(node_ids: Array) -> Dictionary:
	var lookup := {}
	for node_variant in node_ids:
		var node_id: String = str(node_variant)
		if node_id.is_empty():
			continue
		lookup[node_id] = true
	return lookup


static func _has_unlocked_connection(node_data: Dictionary, unlocked_lookup: Dictionary) -> bool:
	for connection_variant in node_data.get("connections", []):
		if unlocked_lookup.has(str(connection_variant)):
			return true
	return false


static func _is_cluster_complete(cluster: Dictionary, unlocked_lookup: Dictionary) -> bool:
	for node_variant in cluster.get("outer_node_ids", []):
		if not unlocked_lookup.has(str(node_variant)):
			return false
	return true
