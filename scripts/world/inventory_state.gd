extends RefCounted

const BAG_SLOT_COUNT := 20
const EQUIPMENT_SLOT_ORDER := ["head", "weapon", "body", "boots", "offhand", "accessory", "trinket"]
const ITEM_DATA := {
	"Traveler Knife": {
		"equip_slot": "weapon",
		"value": 12,
		"stats": {
			"attack": 6
		}
	},
	"Village Tunic": {
		"equip_slot": "body",
		"value": 14,
		"stats": {
			"defense": 2,
			"max_health": 2
		}
	},
	"Oak Buckler": {
		"equip_slot": "offhand",
		"value": 16,
		"stats": {
			"defense": 8
		}
	},
	"Worn Boots": {
		"equip_slot": "boots",
		"value": 8,
		"stats": {
			"defense": 1
		}
	}
}
const CONSUMABLE_DATA := {
	"Trail Ration": {
		"value": 4,
		"heal": 2
	},
	"Healer's Herbs": {
		"value": 6,
		"heal": 3
	},
	"Minor Potion": {
		"value": 9,
		"heal": 4
	}
}
const MATERIAL_DATA := {
	"Slime Jelly": {
		"value": 3
	},
	"Rat Tail": {
		"value": 2
	}
}
const DEFAULT_EQUIPMENT := {
	"weapon": {
		"name": "Traveler Knife",
		"kind": "equipment",
		"count": 1,
		"equip_slot": "weapon"
	},
	"body": {
		"name": "Village Tunic",
		"kind": "equipment",
		"count": 1,
		"equip_slot": "body"
	},
	"boots": {
		"name": "Worn Boots",
		"kind": "equipment",
		"count": 1,
		"equip_slot": "boots"
	}
}


static func create_empty_bag() -> Array[Dictionary]:
	var bag: Array[Dictionary] = []

	for _slot_index in range(BAG_SLOT_COUNT):
		bag.append({})

	return bag


static func normalize_bag(raw_value: Variant) -> Array[Dictionary]:
	var bag: Array[Dictionary] = create_empty_bag()

	if typeof(raw_value) == TYPE_ARRAY:
		var raw_array: Array = raw_value
		var slot_count: int = mini(raw_array.size(), BAG_SLOT_COUNT)

		for slot_index in range(slot_count):
			var normalized_item: Dictionary = normalize_item(raw_array[slot_index])
			if not normalized_item.is_empty():
				bag[slot_index] = normalized_item

		return bag

	if typeof(raw_value) == TYPE_DICTIONARY:
		var raw_dict: Dictionary = raw_value
		var next_slot: int = 0

		for item_name in raw_dict.keys():
			if next_slot >= BAG_SLOT_COUNT:
				break

			var item_payload: Variant = raw_dict[item_name]
			if typeof(item_payload) != TYPE_DICTIONARY:
				continue

			var payload_dict: Dictionary = item_payload
			var normalized_item: Dictionary = normalize_item({
				"name": str(item_name),
				"kind": str(payload_dict.get("kind", "consumable")),
				"count": int(payload_dict.get("count", 1)),
				"equip_slot": str(payload_dict.get("equip_slot", ""))
			})

			if normalized_item.is_empty():
				continue

			bag[next_slot] = normalized_item
			next_slot += 1

		return bag

	return bag


static func normalize_equipment(raw_value: Variant) -> Dictionary:
	var equipment: Dictionary = {}

	for slot_name in EQUIPMENT_SLOT_ORDER:
		equipment[slot_name] = {}

	if raw_value == null:
		return _apply_default_equipment(equipment)

	if typeof(raw_value) != TYPE_DICTIONARY:
		return _apply_default_equipment(equipment)

	var raw_dict: Dictionary = raw_value

	for slot_name in EQUIPMENT_SLOT_ORDER:
		var normalized_item: Dictionary = normalize_item(raw_dict.get(slot_name, {}))
		if normalized_item.is_empty():
			continue
		if str(normalized_item.get("equip_slot", "")) != slot_name:
			continue

		equipment[slot_name] = normalized_item

	return equipment


static func normalize_item(raw_value: Variant) -> Dictionary:
	if typeof(raw_value) == TYPE_STRING:
		return {
			"name": str(raw_value),
			"kind": "consumable",
			"count": 1,
			"equip_slot": ""
		}

	if typeof(raw_value) != TYPE_DICTIONARY:
		return {}

	var raw_dict: Dictionary = raw_value
	var item_name: String = str(raw_dict.get("name", ""))
	if item_name.is_empty():
		return {}

	var item_kind: String = str(raw_dict.get("kind", "consumable"))
	var equip_slot: String = str(raw_dict.get("equip_slot", ""))
	if item_kind == "equipment" and equip_slot.is_empty():
		equip_slot = infer_equip_slot(item_name)

	return {
		"name": item_name,
		"kind": item_kind,
		"count": maxi(1, int(raw_dict.get("count", 1))),
		"equip_slot": equip_slot
	}


static func add_item(bag_slots: Array[Dictionary], item_name: String, item_kind: String = "consumable", count: int = 1, equip_slot: String = "") -> void:
	if item_name.is_empty() or count <= 0:
		return

	if item_kind != "equipment":
		var stack_index: int = _find_matching_stack(bag_slots, item_name, item_kind, equip_slot)
		if stack_index >= 0:
			var existing_item: Dictionary = normalize_item(bag_slots[stack_index])
			existing_item["count"] = int(existing_item.get("count", 1)) + count
			bag_slots[stack_index] = existing_item
			return

		var empty_stack_index: int = _find_empty_slot(bag_slots)
		if empty_stack_index >= 0:
			bag_slots[empty_stack_index] = normalize_item({
				"name": item_name,
				"kind": item_kind,
				"count": count,
				"equip_slot": equip_slot
			})
		return

	var remaining_count: int = count
	while remaining_count > 0:
		var empty_slot_index: int = _find_empty_slot(bag_slots)
		if empty_slot_index < 0:
			return

		bag_slots[empty_slot_index] = normalize_item({
			"name": item_name,
			"kind": item_kind,
			"count": 1,
			"equip_slot": equip_slot
		})
		remaining_count -= 1


static func remove_item(bag_slots: Array[Dictionary], equipment_slots: Dictionary, item_name: String, count: int = 1) -> void:
	if item_name.is_empty() or count <= 0:
		return

	var remaining_count: int = count

	for slot_index in range(bag_slots.size()):
		if remaining_count <= 0:
			return

		var item_data: Dictionary = normalize_item(bag_slots[slot_index])
		if item_data.is_empty():
			continue
		if str(item_data.get("name", "")) != item_name:
			continue

		var next_count: int = int(item_data.get("count", 1)) - remaining_count
		if next_count > 0:
			item_data["count"] = next_count
			bag_slots[slot_index] = item_data
			return

		remaining_count = abs(next_count)
		bag_slots[slot_index] = {}

	for slot_name in EQUIPMENT_SLOT_ORDER:
		if remaining_count <= 0:
			return

		var equipped_item: Dictionary = normalize_item(equipment_slots.get(slot_name, {}))
		if equipped_item.is_empty():
			continue
		if str(equipped_item.get("name", "")) != item_name:
			continue

		equipment_slots[slot_name] = {}
		remaining_count -= 1


static func infer_equip_slot(item_name: String) -> String:
	if ITEM_DATA.has(item_name):
		var item_info: Dictionary = ITEM_DATA[item_name]
		return str(item_info.get("equip_slot", ""))

	return ""


static func get_item_stats(item_name: String) -> Dictionary:
	if not ITEM_DATA.has(item_name):
		return {}

	var item_info: Dictionary = ITEM_DATA[item_name]
	var raw_stats: Variant = item_info.get("stats", {})
	if typeof(raw_stats) != TYPE_DICTIONARY:
		return {}

	return raw_stats.duplicate(true)


static func get_consumable_effects(item_name: String) -> Dictionary:
	if not CONSUMABLE_DATA.has(item_name):
		return {}

	var raw_effects: Variant = CONSUMABLE_DATA[item_name]
	if typeof(raw_effects) != TYPE_DICTIONARY:
		return {}

	return raw_effects.duplicate(true)


static func get_item_value(item_name: String, item_kind: String = "") -> int:
	if ITEM_DATA.has(item_name):
		var equipment_info: Dictionary = ITEM_DATA[item_name]
		return int(equipment_info.get("value", 0))

	if CONSUMABLE_DATA.has(item_name):
		var consumable_info: Dictionary = CONSUMABLE_DATA[item_name]
		return int(consumable_info.get("value", 0))

	if MATERIAL_DATA.has(item_name):
		var material_info: Dictionary = MATERIAL_DATA[item_name]
		return int(material_info.get("value", 0))

	if item_kind == "quest":
		return 0

	return 0


static func get_item_category(item_name: String, item_kind: String = "") -> String:
	if item_kind == "quest":
		return "Quest"

	if ITEM_DATA.has(item_name):
		var equip_slot_name: String = infer_equip_slot(item_name)
		if equip_slot_name == "weapon":
			return "Weapons"
		if equip_slot_name == "body" or equip_slot_name == "offhand" or equip_slot_name == "head" or equip_slot_name == "boots":
			return "Armor"
		return "Accessories"

	if CONSUMABLE_DATA.has(item_name):
		return "Consumables"

	if MATERIAL_DATA.has(item_name):
		return "Materials"

	return item_kind.capitalize()


static func get_equipment_totals(raw_equipment_slots: Variant) -> Dictionary:
	var equipment_slots: Dictionary = normalize_equipment(raw_equipment_slots)
	var totals := {
		"attack": 0,
		"defense": 0,
		"max_health": 0
	}

	for slot_name in EQUIPMENT_SLOT_ORDER:
		var item_data: Dictionary = normalize_item(equipment_slots.get(slot_name, {}))
		if item_data.is_empty():
			continue

		var item_stats: Dictionary = get_item_stats(str(item_data.get("name", "")))
		totals["attack"] += int(item_stats.get("attack", 0))
		totals["defense"] += int(item_stats.get("defense", 0))
		totals["max_health"] += int(item_stats.get("max_health", 0))

	return totals


static func _find_empty_slot(bag_slots: Array[Dictionary]) -> int:
	for slot_index in range(bag_slots.size()):
		if normalize_item(bag_slots[slot_index]).is_empty():
			return slot_index

	return -1


static func _find_matching_stack(bag_slots: Array[Dictionary], item_name: String, item_kind: String, equip_slot: String) -> int:
	for slot_index in range(bag_slots.size()):
		var item_data: Dictionary = normalize_item(bag_slots[slot_index])
		if item_data.is_empty():
			continue
		if str(item_data.get("name", "")) != item_name:
			continue
		if str(item_data.get("kind", "")) != item_kind:
			continue
		if str(item_data.get("equip_slot", "")) != equip_slot:
			continue
		return slot_index

	return -1


static func _apply_default_equipment(equipment: Dictionary) -> Dictionary:
	for slot_name in DEFAULT_EQUIPMENT.keys():
		equipment[slot_name] = normalize_item(DEFAULT_EQUIPMENT[slot_name])

	return equipment
