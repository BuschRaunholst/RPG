extends RefCounted

const GOLD_KIND := "gold"
const CONSUMABLE_KIND := "consumable"
const EQUIPMENT_KIND := "equipment"


static func roll_mob_drops(enemy_type: String, depth: int, rng: RandomNumberGenerator, enemy_rarity: String = "normal") -> Array[Dictionary]:
	match enemy_type:
		"rat":
			return _roll_rat_drops(depth, rng, enemy_rarity)
		_:
			return _roll_common_drops(depth, rng, enemy_rarity)


static func _roll_rat_drops(depth: int, rng: RandomNumberGenerator, enemy_rarity: String) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	var safe_depth: int = maxi(1, depth)
	var gold_chance: float = 0.72
	var potion_chance: float = 0.20
	var equipment_chance: float = minf(0.06 + float(safe_depth - 1) * 0.015, 0.12)
	var gold_multiplier: int = 1

	match enemy_rarity:
		"rare":
			gold_chance = 1.0
			potion_chance = 0.38
			equipment_chance = minf(0.20 + float(safe_depth - 1) * 0.025, 0.35)
			gold_multiplier = 2
		"epic":
			gold_chance = 1.0
			potion_chance = 0.70
			equipment_chance = 0.75
			gold_multiplier = 4

	if rng.randf() <= gold_chance:
		drops.append({
			"name": "Gold",
			"kind": GOLD_KIND,
			"count": rng.randi_range(2 + safe_depth, 5 + safe_depth * 2) * gold_multiplier,
			"visual": "gold"
		})

	if rng.randf() <= potion_chance:
		var potion_name: String = "Minor Potion" if rng.randf() <= 0.35 else "Trail Ration"
		drops.append({
			"name": potion_name,
			"kind": CONSUMABLE_KIND,
			"count": 1,
			"visual": "potion"
		})

	if rng.randf() <= equipment_chance:
		drops.append(_roll_low_tier_equipment(rng))
	if enemy_rarity == "rare" and rng.randf() <= 0.08:
		drops.append(_roll_low_tier_equipment(rng))
	if enemy_rarity == "epic" and rng.randf() <= 0.45:
		drops.append(_roll_low_tier_equipment(rng))

	return drops


static func _roll_common_drops(depth: int, rng: RandomNumberGenerator, enemy_rarity: String) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	var safe_depth: int = maxi(1, depth)
	var gold_chance: float = 0.65
	var potion_chance: float = 0.16
	var equipment_chance: float = 0.05
	var gold_multiplier: int = 1

	if enemy_rarity == "rare":
		gold_chance = 1.0
		potion_chance = 0.32
		equipment_chance = 0.18
		gold_multiplier = 2
	elif enemy_rarity == "epic":
		gold_chance = 1.0
		potion_chance = 0.65
		equipment_chance = 0.65
		gold_multiplier = 4

	if rng.randf() <= gold_chance:
		drops.append({
			"name": "Gold",
			"kind": GOLD_KIND,
			"count": rng.randi_range(2, 4 + safe_depth * 2) * gold_multiplier,
			"visual": "gold"
		})

	if rng.randf() <= potion_chance:
		drops.append({
			"name": "Trail Ration",
			"kind": CONSUMABLE_KIND,
			"count": 1,
			"visual": "potion"
		})

	if rng.randf() <= equipment_chance:
		drops.append(_roll_low_tier_equipment(rng))

	return drops


static func _roll_low_tier_equipment(rng: RandomNumberGenerator) -> Dictionary:
	var equipment_pool: Array[Dictionary] = [
		{
			"name": "Traveler Knife",
			"kind": EQUIPMENT_KIND,
			"count": 1,
			"equip_slot": "weapon",
			"visual": "bag"
		},
		{
			"name": "Hunter Bow",
			"kind": EQUIPMENT_KIND,
			"count": 1,
			"equip_slot": "weapon",
			"visual": "bag"
		},
		{
			"name": "Ash Staff",
			"kind": EQUIPMENT_KIND,
			"count": 1,
			"equip_slot": "weapon",
			"visual": "bag"
		},
		{
			"name": "Willow Wand",
			"kind": EQUIPMENT_KIND,
			"count": 1,
			"equip_slot": "weapon",
			"visual": "bag"
		},
		{
			"name": "Iron Greatsword",
			"kind": EQUIPMENT_KIND,
			"count": 1,
			"equip_slot": "weapon",
			"visual": "bag"
		},
		{
			"name": "Woodsman Axe",
			"kind": EQUIPMENT_KIND,
			"count": 1,
			"equip_slot": "weapon",
			"visual": "bag"
		},
		{
			"name": "Village Tunic",
			"kind": EQUIPMENT_KIND,
			"count": 1,
			"equip_slot": "body",
			"visual": "bag"
		},
		{
			"name": "Oak Buckler",
			"kind": EQUIPMENT_KIND,
			"count": 1,
			"equip_slot": "offhand",
			"visual": "bag"
		},
		{
			"name": "Worn Boots",
			"kind": EQUIPMENT_KIND,
			"count": 1,
			"equip_slot": "boots",
			"visual": "bag"
		}
	]

	return equipment_pool[rng.randi_range(0, equipment_pool.size() - 1)].duplicate(true)
