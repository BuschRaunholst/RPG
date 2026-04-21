extends Control

signal inventory_changed(bag_slots: Array, equipment_slots: Dictionary)
signal use_item_requested(item_name: String)
signal quick_item_assigned(item_name: String, item_kind: String)
signal stat_increase_requested(stat_name: String)

const DISPLAY_PLAYER := "player"
const DISPLAY_INVENTORY := "inventory"

const InventorySlotScript = preload("res://scripts/ui/inventory_slot.gd")
const InventoryStateScript = preload("res://scripts/world/inventory_state.gd")

const EQUIPMENT_LAYOUT := [
	{"id": "head", "label": "Head"},
	{"id": "weapon", "label": "Weapon"},
	{"id": "body", "label": "Body"},
	{"id": "offhand", "label": "Off Hand"},
	{"id": "accessory", "label": "Accessory"},
	{"id": "trinket", "label": "Charm"}
]

@onready var main_row: HBoxContainer = $ContentCenter/MainRow
@onready var equipment_panel: PanelContainer = $ContentCenter/MainRow/EquipmentPanel
@onready var character_panel: PanelContainer = $ContentCenter/MainRow/CharacterPanel
@onready var inventory_panel: PanelContainer = $ContentCenter/MainRow/InventoryPanel
@onready var equipment_grid: GridContainer = $ContentCenter/MainRow/EquipmentPanel/MarginContainer/VBoxContainer/EquipmentGrid
@onready var player_name_label: Label = $ContentCenter/MainRow/CharacterPanel/MarginContainer/VBoxContainer/PlayerName
@onready var gear_summary_label: Label = $ContentCenter/MainRow/CharacterPanel/MarginContainer/VBoxContainer/GearSummary
@onready var inventory_grid: GridContainer = $ContentCenter/MainRow/InventoryPanel/MarginContainer/VBoxContainer/InventoryGrid
@onready var gold_label: Label = $ContentCenter/MainRow/InventoryPanel/MarginContainer/VBoxContainer/TitleRow/GoldLabel
@onready var body_text_label: Label = $ContentCenter/MainRow/CharacterPanel/MarginContainer/VBoxContainer/BodyPanel/BodyMargin/BodyInner/BodyText
@onready var body_hint_label: Label = $ContentCenter/MainRow/CharacterPanel/MarginContainer/VBoxContainer/BodyPanel/BodyMargin/BodyInner/BodyHint
@onready var level_label: Label = $ContentCenter/MainRow/CharacterPanel/MarginContainer/VBoxContainer/ProgressionPanel/MarginContainer/VBoxContainer/LevelLabel
@onready var points_label: Label = $ContentCenter/MainRow/CharacterPanel/MarginContainer/VBoxContainer/ProgressionPanel/MarginContainer/VBoxContainer/PointsLabel
@onready var strength_value_label: Label = $ContentCenter/MainRow/CharacterPanel/MarginContainer/VBoxContainer/ProgressionPanel/MarginContainer/VBoxContainer/StatRows/StrengthRow/StrengthValue
@onready var stamina_value_label: Label = $ContentCenter/MainRow/CharacterPanel/MarginContainer/VBoxContainer/ProgressionPanel/MarginContainer/VBoxContainer/StatRows/StaminaRow/StaminaValue
@onready var dexterity_value_label: Label = $ContentCenter/MainRow/CharacterPanel/MarginContainer/VBoxContainer/ProgressionPanel/MarginContainer/VBoxContainer/StatRows/DexterityRow/DexterityValue
@onready var strength_add_button: Button = $ContentCenter/MainRow/CharacterPanel/MarginContainer/VBoxContainer/ProgressionPanel/MarginContainer/VBoxContainer/StatRows/StrengthRow/StrengthAdd
@onready var stamina_add_button: Button = $ContentCenter/MainRow/CharacterPanel/MarginContainer/VBoxContainer/ProgressionPanel/MarginContainer/VBoxContainer/StatRows/StaminaRow/StaminaAdd
@onready var dexterity_add_button: Button = $ContentCenter/MainRow/CharacterPanel/MarginContainer/VBoxContainer/ProgressionPanel/MarginContainer/VBoxContainer/StatRows/DexterityRow/DexterityAdd
@onready var item_popup: PanelContainer = $ItemPopup
@onready var popup_title_label: Label = $ItemPopup/PopupMargin/PopupVBox/PopupTitle
@onready var popup_body_label: Label = $ItemPopup/PopupMargin/PopupVBox/PopupBody
@onready var popup_action_row: HBoxContainer = $ItemPopup/PopupMargin/PopupVBox/PopupActionRow
@onready var popup_use_button: Button = $ItemPopup/PopupMargin/PopupVBox/PopupActionRow/PopupUseButton
@onready var popup_quick_button: Button = $ItemPopup/PopupMargin/PopupVBox/PopupActionRow/PopupQuickButton

var bag_slots: Array[Dictionary] = []
var equipment_slots: Dictionary = {}
var player_gold: int = 0
var player_level: int = 1
var player_unspent_points: int = 0
var player_allocations := {
	"strength": 1,
	"stamina": 1,
	"dexterity": 1
}
var player_attack_value: int = 1
var player_defense_value: int = 0
var player_max_health_value: int = 5
var bag_slot_controls: Array[Control] = []
var equipment_slot_controls: Dictionary = {}
var selected_group: String = ""
var selected_key: Variant = null
var display_mode: String = DISPLAY_INVENTORY


func _ready() -> void:
	_build_equipment_slots()
	_build_bag_slots()
	popup_use_button.pressed.connect(_on_use_button_pressed)
	popup_quick_button.pressed.connect(_on_quick_button_pressed)
	strength_add_button.pressed.connect(_on_stat_add_pressed.bind("strength"))
	stamina_add_button.pressed.connect(_on_stat_add_pressed.bind("stamina"))
	dexterity_add_button.pressed.connect(_on_stat_add_pressed.bind("dexterity"))
	set_inventory_state([], {})
	set_display_mode(DISPLAY_INVENTORY)


func set_display_mode(mode: String) -> void:
	display_mode = mode
	_apply_display_mode()


func set_inventory_state(raw_bag_slots: Variant, raw_equipment_slots: Variant, gold_amount: int = 0) -> void:
	bag_slots = InventoryStateScript.normalize_bag(raw_bag_slots)
	equipment_slots = InventoryStateScript.normalize_equipment(raw_equipment_slots)
	player_gold = gold_amount
	if not _has_valid_selection():
		selected_group = ""
		selected_key = null
		item_popup.visible = false
	_refresh_view()


func set_progression_state(level: int, unspent_points: int, allocations: Dictionary, attack_value: int, defense_value: int, max_health_value: int) -> void:
	player_level = level
	player_unspent_points = unspent_points
	player_allocations = allocations.duplicate(true)
	player_attack_value = attack_value
	player_defense_value = defense_value
	player_max_health_value = max_health_value
	_refresh_view()


func select_slot(group_name: String, key_value: Variant) -> void:
	open_item_popup(group_name, key_value, null)


func open_item_popup(group_name: String, key_value: Variant, slot_control: Control) -> void:
	var item_data: Dictionary = _get_item(group_name, key_value)
	if item_data.is_empty():
		selected_group = ""
		selected_key = null
		item_popup.visible = false
	else:
		selected_group = group_name
		selected_key = key_value
		_refresh_view()
		_update_item_popup(item_data)
		_position_item_popup(slot_control)
		item_popup.visible = true
		return

	_refresh_view()


func can_drop_item(target_group: String, target_key: Variant, accepted_equip_slot: String, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false

	var payload: Dictionary = data
	var source_group: String = str(payload.get("source_group", ""))
	var source_key: Variant = payload.get("source_key", -1)
	var source_item: Dictionary = InventoryStateScript.normalize_item(payload.get("item_data", {}))

	if source_item.is_empty():
		return false
	if source_group.is_empty():
		return false
	if source_group == target_group and source_key == target_key:
		return false

	var target_item: Dictionary = _get_item(target_group, target_key)

	if target_group == "equipment":
		if str(source_item.get("kind", "")) != "equipment":
			return false
		if str(source_item.get("equip_slot", "")) != accepted_equip_slot:
			return false

		if source_group == "equipment" and not target_item.is_empty():
			var source_slot_name: String = str(payload.get("source_equip_slot", ""))
			return str(target_item.get("equip_slot", "")) == source_slot_name

	return true


func drop_item(target_group: String, target_key: Variant, _accepted_equip_slot: String, data: Variant) -> void:
	if not can_drop_item(target_group, target_key, _accepted_equip_slot, data):
		return

	var payload: Dictionary = data
	var source_group: String = str(payload.get("source_group", ""))
	var source_key: Variant = payload.get("source_key", -1)

	var next_bag_slots: Array[Dictionary] = bag_slots.duplicate(true)
	var next_equipment_slots: Dictionary = equipment_slots.duplicate(true)
	var source_item: Dictionary = _get_item_from_state(next_bag_slots, next_equipment_slots, source_group, source_key)
	var target_item: Dictionary = _get_item_from_state(next_bag_slots, next_equipment_slots, target_group, target_key)

	_set_item_in_state(next_bag_slots, next_equipment_slots, source_group, source_key, {})

	if target_group == "bag" and _can_stack_items(source_item, target_item):
		var merged_item: Dictionary = target_item.duplicate(true)
		merged_item["count"] = int(merged_item.get("count", 1)) + int(source_item.get("count", 1))
		_set_item_in_state(next_bag_slots, next_equipment_slots, target_group, target_key, merged_item)
	else:
		_set_item_in_state(next_bag_slots, next_equipment_slots, target_group, target_key, source_item)

		if not target_item.is_empty():
			_set_item_in_state(next_bag_slots, next_equipment_slots, source_group, source_key, target_item)

	bag_slots = next_bag_slots
	equipment_slots = next_equipment_slots
	_refresh_view()
	inventory_changed.emit(bag_slots.duplicate(true), equipment_slots.duplicate(true))


func _refresh_view() -> void:
	gold_label.text = "Gold: %d" % player_gold
	for slot_index in range(bag_slot_controls.size()):
		var bag_slot: Control = bag_slot_controls[slot_index]
		if bag_slot.has_method("set_item_data"):
			bag_slot.call("set_item_data", bag_slots[slot_index])
		if bag_slot.has_method("set_selected"):
			bag_slot.call("set_selected", selected_group == "bag" and int(selected_key) == slot_index)

	for slot_name in equipment_slot_controls.keys():
		var equipment_slot: Control = equipment_slot_controls[slot_name]
		if equipment_slot.has_method("set_item_data"):
			equipment_slot.call("set_item_data", InventoryStateScript.normalize_item(equipment_slots.get(slot_name, {})))
		if equipment_slot.has_method("set_selected"):
			equipment_slot.call("set_selected", selected_group == "equipment" and str(selected_key) == slot_name)

	_update_character_card()
	_apply_display_mode()
	if item_popup.visible and _has_valid_selection():
		_update_item_popup(_get_selected_item())


func _build_equipment_slots() -> void:
	for child in equipment_grid.get_children():
		child.queue_free()

	equipment_slot_controls.clear()

	for slot_data in EQUIPMENT_LAYOUT:
		var slot_control := InventorySlotScript.new()
		slot_control.configure(self, "equipment", str(slot_data.get("id", "")), str(slot_data.get("id", "")))
		equipment_grid.add_child(slot_control)
		equipment_slot_controls[str(slot_data.get("id", ""))] = slot_control


func _build_bag_slots() -> void:
	for child in inventory_grid.get_children():
		child.queue_free()

	bag_slot_controls.clear()

	for slot_index in range(InventoryStateScript.BAG_SLOT_COUNT):
		var slot_control := InventorySlotScript.new()
		slot_control.configure(self, "bag", slot_index)
		inventory_grid.add_child(slot_control)
		bag_slot_controls.append(slot_control)


func _get_item(group_name: String, key_value: Variant) -> Dictionary:
	return _get_item_from_state(bag_slots, equipment_slots, group_name, key_value)


func _get_item_from_state(source_bag_slots: Array[Dictionary], source_equipment_slots: Dictionary, group_name: String, key_value: Variant) -> Dictionary:
	if group_name == "bag":
		var slot_index: int = int(key_value)
		if slot_index < 0 or slot_index >= source_bag_slots.size():
			return {}
		return InventoryStateScript.normalize_item(source_bag_slots[slot_index])

	var slot_name: String = str(key_value)
	return InventoryStateScript.normalize_item(source_equipment_slots.get(slot_name, {}))


func _set_item_in_state(target_bag_slots: Array[Dictionary], target_equipment_slots: Dictionary, group_name: String, key_value: Variant, item_value: Dictionary) -> void:
	if group_name == "bag":
		var slot_index: int = int(key_value)
		if slot_index < 0 or slot_index >= target_bag_slots.size():
			return
		target_bag_slots[slot_index] = InventoryStateScript.normalize_item(item_value)
		return

	target_equipment_slots[str(key_value)] = InventoryStateScript.normalize_item(item_value)


func _can_stack_items(source_item: Dictionary, target_item: Dictionary) -> bool:
	if source_item.is_empty() or target_item.is_empty():
		return false
	if str(source_item.get("kind", "")) == "equipment":
		return false

	return str(source_item.get("name", "")) == str(target_item.get("name", "")) \
		and str(source_item.get("kind", "")) == str(target_item.get("kind", "")) \
		and str(source_item.get("equip_slot", "")) == str(target_item.get("equip_slot", ""))


func _update_character_card() -> void:
	player_name_label.text = "PLAYER"
	body_text_label.text = "Adventurer"
	body_hint_label.text = "ATK %d  DEF %d  HP %d" % [player_attack_value, player_defense_value, player_max_health_value]
	level_label.text = "Level %d" % player_level
	points_label.text = "Points: %d" % player_unspent_points
	strength_value_label.text = str(int(player_allocations.get("strength", 0)))
	stamina_value_label.text = str(int(player_allocations.get("stamina", 0)))
	dexterity_value_label.text = str(int(player_allocations.get("dexterity", 0)))
	var can_add_stats: bool = player_unspent_points > 0
	strength_add_button.disabled = not can_add_stats
	stamina_add_button.disabled = not can_add_stats
	dexterity_add_button.disabled = not can_add_stats

	var gear_lines: Array[String] = []
	for slot_data in EQUIPMENT_LAYOUT:
		var slot_name: String = str(slot_data.get("id", ""))
		var slot_label: String = str(slot_data.get("label", slot_name.capitalize()))
		var item_data: Dictionary = InventoryStateScript.normalize_item(equipment_slots.get(slot_name, {}))
		var item_name: String = "Empty"
		if not item_data.is_empty():
			item_name = str(item_data.get("name", ""))

		gear_lines.append("%s: %s" % [slot_label, item_name])

	gear_summary_label.text = "\n".join(gear_lines)


func _get_selected_bag_item() -> Dictionary:
	if selected_group != "bag":
		return {}
	return _get_selected_item()


func _get_selected_item() -> Dictionary:
	if selected_group.is_empty():
		return {}
	return _get_item(selected_group, selected_key)


func _on_use_button_pressed() -> void:
	var selected_item: Dictionary = _get_selected_bag_item()
	if selected_item.is_empty():
		return
	if str(selected_item.get("kind", "")) != "consumable":
		return

	use_item_requested.emit(str(selected_item.get("name", "")))


func _on_quick_button_pressed() -> void:
	var selected_item: Dictionary = _get_selected_bag_item()
	if selected_item.is_empty():
		return
	if str(selected_item.get("kind", "")) != "consumable":
		return

	quick_item_assigned.emit(str(selected_item.get("name", "")), str(selected_item.get("kind", "consumable")))


func _on_stat_add_pressed(stat_name: String) -> void:
	if player_unspent_points <= 0:
		return

	stat_increase_requested.emit(stat_name)


func _update_item_popup(selected_item: Dictionary) -> void:
	var item_name: String = str(selected_item.get("name", ""))
	var item_kind: String = str(selected_item.get("kind", "consumable"))
	popup_title_label.text = item_name

	var detail_lines: Array[String] = []
	detail_lines.append("Type: %s" % item_kind.capitalize())

	if item_kind == "equipment":
		var equip_slot_name: String = str(selected_item.get("equip_slot", ""))
		if not equip_slot_name.is_empty():
			detail_lines.append("Slot: %s" % equip_slot_name.capitalize())

		var item_stats: Dictionary = InventoryStateScript.get_item_stats(item_name)
		var stat_line: String = _format_stat_block(item_stats)
		if not stat_line.is_empty():
			detail_lines.append(stat_line)

		var compare_line: String = _build_compare_line(selected_item)
		if not compare_line.is_empty():
			detail_lines.append(compare_line)

		popup_action_row.visible = false
	else:
		var effects: Dictionary = InventoryStateScript.get_consumable_effects(item_name)
		var heal_amount: int = int(effects.get("heal", 0))
		if heal_amount > 0:
			detail_lines.append("Restores %d HP" % heal_amount)

		popup_action_row.visible = true
		popup_use_button.text = "Use"
		popup_quick_button.text = "Quick Slot"

	popup_body_label.text = "\n".join(detail_lines)


func _position_item_popup(slot_control: Control) -> void:
	var popup_size := item_popup.custom_minimum_size
	var target_rect := Rect2(Vector2.ZERO, size)

	var slot_position: Vector2 = target_rect.size * 0.5 - popup_size * 0.5
	if slot_control != null:
		slot_position = slot_control.global_position - global_position
		slot_position.x += (slot_control.size.x - popup_size.x) * 0.5
		slot_position.y -= popup_size.y + 8.0
		if slot_position.y < 8.0:
			slot_position.y = slot_control.global_position.y - global_position.y + slot_control.size.y + 8.0

	slot_position.x = clampf(slot_position.x, 8.0, maxf(8.0, size.x - popup_size.x - 8.0))
	slot_position.y = clampf(slot_position.y, 8.0, maxf(8.0, size.y - popup_size.y - 8.0))

	item_popup.position = slot_position


func _build_compare_line(item_data: Dictionary) -> String:
	var slot_name: String = str(item_data.get("equip_slot", ""))
	if slot_name.is_empty():
		return ""

	var equipped_item: Dictionary = InventoryStateScript.normalize_item(equipment_slots.get(slot_name, {}))
	if equipped_item.is_empty():
		return "Compare: slot empty"

	if selected_group == "equipment" and str(selected_key) == slot_name:
		return "Compare: equipped now"

	var item_stats: Dictionary = InventoryStateScript.get_item_stats(str(item_data.get("name", "")))
	var equipped_stats: Dictionary = InventoryStateScript.get_item_stats(str(equipped_item.get("name", "")))
	var compare_bits: Array[String] = []

	_append_compare_bit(compare_bits, "ATK", int(item_stats.get("attack", 0)) - int(equipped_stats.get("attack", 0)))
	_append_compare_bit(compare_bits, "DEF", int(item_stats.get("defense", 0)) - int(equipped_stats.get("defense", 0)))
	_append_compare_bit(compare_bits, "HP", int(item_stats.get("max_health", 0)) - int(equipped_stats.get("max_health", 0)))

	if compare_bits.is_empty():
		return "Compare: same as %s" % str(equipped_item.get("name", "equipped"))

	return "Compare vs %s: %s" % [str(equipped_item.get("name", "equipped")), " ".join(compare_bits)]


func _append_compare_bit(compare_bits: Array[String], label: String, delta_value: int) -> void:
	if delta_value > 0:
		compare_bits.append("+%d %s" % [delta_value, label])
	elif delta_value < 0:
		compare_bits.append("%d %s" % [delta_value, label])


func _format_stat_block(item_stats: Dictionary) -> String:
	var stat_bits: Array[String] = []
	var attack_value: int = int(item_stats.get("attack", 0))
	var defense_value: int = int(item_stats.get("defense", 0))
	var health_value: int = int(item_stats.get("max_health", 0))

	if attack_value > 0:
		stat_bits.append("+%d ATK" % attack_value)
	if defense_value > 0:
		stat_bits.append("+%d DEF" % defense_value)
	if health_value > 0:
		stat_bits.append("+%d HP" % health_value)

	return "Stats: " + " ".join(stat_bits) if not stat_bits.is_empty() else ""


func _has_valid_selection() -> bool:
	if selected_group.is_empty():
		return false

	return not _get_item(selected_group, selected_key).is_empty()


func _apply_display_mode() -> void:
	match display_mode:
		DISPLAY_PLAYER:
			equipment_panel.visible = false
			character_panel.visible = true
			inventory_panel.visible = false
			character_panel.custom_minimum_size = Vector2(320, 344)
			character_panel.size_flags_horizontal = 0
		DISPLAY_INVENTORY:
			equipment_panel.visible = true
			character_panel.visible = false
			inventory_panel.visible = true
			character_panel.custom_minimum_size = Vector2(220, 344)
			equipment_panel.size_flags_horizontal = 0
			inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_:
			equipment_panel.visible = true
			character_panel.visible = true
			inventory_panel.visible = true
			character_panel.custom_minimum_size = Vector2(220, 344)
