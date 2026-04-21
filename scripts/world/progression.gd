extends RefCounted

const STAT_KEYS := ["strength", "stamina", "dexterity"]
const STARTING_STAT_POINTS := 3
const POINTS_PER_LEVEL := 2


static func normalize_allocations(raw_value: Variant) -> Dictionary:
	var allocations := {
		"strength": 1,
		"stamina": 1,
		"dexterity": 1
	}

	if typeof(raw_value) != TYPE_DICTIONARY:
		return allocations

	var raw_dict: Dictionary = raw_value
	for stat_key in STAT_KEYS:
		allocations[stat_key] = maxi(0, int(raw_dict.get(stat_key, allocations[stat_key])))

	return allocations


static func increase_stat(allocations: Dictionary, stat_name: String) -> Dictionary:
	var next_allocations: Dictionary = normalize_allocations(allocations)
	if not STAT_KEYS.has(stat_name):
		return next_allocations

	next_allocations[stat_name] = int(next_allocations.get(stat_name, 0)) + 1
	return next_allocations


static func get_points_earned_for_level(level: int) -> int:
	return STARTING_STAT_POINTS + maxi(0, level - 1) * POINTS_PER_LEVEL


static func get_spent_points(allocations: Dictionary) -> int:
	var normalized_allocations: Dictionary = normalize_allocations(allocations)
	var spent_points: int = 0
	for stat_key in STAT_KEYS:
		spent_points += int(normalized_allocations.get(stat_key, 0))
	return spent_points


static func get_level_for_xp(total_xp: int) -> int:
	var level: int = 1
	while total_xp >= get_total_xp_for_level(level + 1):
		level += 1
	return level


static func get_total_xp_for_level(level: int) -> int:
	if level <= 1:
		return 0

	var total_xp: int = 0
	for current_level in range(1, level):
		total_xp += get_xp_to_next_level(current_level)
	return total_xp


static func get_xp_to_next_level(level: int) -> int:
	var level_index: int = maxi(0, level - 1)
	return 10 + (level_index * 8) + (level_index * level_index * 3)


static func get_progression_state(total_xp: int, allocations: Dictionary) -> Dictionary:
	var level: int = get_level_for_xp(total_xp)
	var level_start_xp: int = get_total_xp_for_level(level)
	var xp_to_next: int = get_xp_to_next_level(level)
	var xp_into_level: int = total_xp - level_start_xp
	var normalized_allocations: Dictionary = normalize_allocations(allocations)
	var earned_points: int = get_points_earned_for_level(level)
	var spent_points: int = get_spent_points(normalized_allocations)
	var unspent_points: int = maxi(0, earned_points - spent_points)

	return {
		"level": level,
		"xp_total": total_xp,
		"xp_into_level": xp_into_level,
		"xp_to_next": xp_to_next,
		"allocations": normalized_allocations,
		"unspent_points": unspent_points
	}


static func get_stat_bonuses(allocations: Dictionary) -> Dictionary:
	var normalized_allocations: Dictionary = normalize_allocations(allocations)
	var strength_value: int = int(normalized_allocations.get("strength", 0))
	var stamina_value: int = int(normalized_allocations.get("stamina", 0))
	var dexterity_value: int = int(normalized_allocations.get("dexterity", 0))

	return {
		"attack": strength_value * 4,
		"max_health": stamina_value * 18,
		"defense": dexterity_value * 3,
		"move_speed": dexterity_value * 4
	}
