extends RefCounted

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


static func get_level_skill_points_earned(level: int) -> int:
	return maxi(0, level - 1)


static func normalize_claimed_milestones(raw_value: Variant) -> Array[String]:
	var claimed: Array[String] = []
	if typeof(raw_value) != TYPE_ARRAY:
		return claimed
	for milestone_variant in raw_value:
		var milestone_id: String = str(milestone_variant)
		if milestone_id.is_empty() or claimed.has(milestone_id):
			continue
		claimed.append(milestone_id)
	return claimed


static func get_milestone_skill_points_earned(raw_claimed_milestones: Variant) -> int:
	return 0


static func get_total_skill_points_earned(total_xp: int, raw_claimed_milestones: Variant) -> int:
	var level: int = get_level_for_xp(total_xp)
	return get_level_skill_points_earned(level) + get_milestone_skill_points_earned(raw_claimed_milestones)


static func get_progression_state(total_xp: int, raw_claimed_milestones: Variant = []) -> Dictionary:
	var level: int = get_level_for_xp(total_xp)
	var level_start_xp: int = get_total_xp_for_level(level)
	var xp_to_next: int = get_xp_to_next_level(level)
	var xp_into_level: int = total_xp - level_start_xp
	var claimed_milestones: Array[String] = normalize_claimed_milestones(raw_claimed_milestones)
	var level_points: int = get_level_skill_points_earned(level)
	var milestone_points: int = claimed_milestones.size()

	return {
		"level": level,
		"xp_total": total_xp,
		"xp_into_level": xp_into_level,
		"xp_to_next": xp_to_next,
		"level_skill_points": level_points,
		"milestone_skill_points": milestone_points,
		"total_skill_points": level_points + milestone_points,
		"claimed_milestones": claimed_milestones
	}
