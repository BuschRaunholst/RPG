extends PanelContainer

const InventoryStateScript = preload("res://scripts/world/inventory_state.gd")
const ItemIconScript = preload("res://scripts/ui/item_icon.gd")

const EMPTY_SLOT_COLOR := Color(0.12, 0.14, 0.13, 0.92)
const FILLED_SLOT_COLOR := Color(0.2, 0.235, 0.2, 0.98)
const EQUIPMENT_EMPTY_COLOR := Color(0.145, 0.16, 0.15, 0.96)
const BORDER_COLOR := Color(0.964706, 0.933333, 0.654902, 0.14)

var inventory_view: Node
var slot_group: String = ""
var slot_key: Variant = null
var accepted_equip_slot: String = ""
var item_data: Dictionary = {}
var selected: bool = false

var icon_label: Label
var item_icon: Control
var name_label: Label
var count_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(76, 76)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("panel", _make_style_box(EMPTY_SLOT_COLOR))
	_build_contents()
	_refresh()


func configure(view: Node, group_name: String, key_value: Variant, equip_slot_name: String = "") -> void:
	inventory_view = view
	slot_group = group_name
	slot_key = key_value
	accepted_equip_slot = equip_slot_name
	tooltip_text = ""


func set_item_data(value: Dictionary) -> void:
	item_data = value.duplicate(true)
	_refresh()


func set_selected(value: bool) -> void:
	selected = value
	_refresh()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_data.is_empty():
		return null

	var preview_panel := PanelContainer.new()
	preview_panel.top_level = true
	preview_panel.z_index = 100
	preview_panel.add_theme_stylebox_override("panel", _make_style_box(FILLED_SLOT_COLOR))
	preview_panel.custom_minimum_size = Vector2(78, 50)

	var preview_label := Label.new()
	preview_label.text = _build_slot_title(item_data)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(preview_label)

	set_drag_preview(preview_panel)
	return {
		"source_group": slot_group,
		"source_key": slot_key,
		"source_equip_slot": accepted_equip_slot,
		"item_data": item_data.duplicate(true)
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if inventory_view == null:
		return false

	return bool(inventory_view.call("can_drop_item", slot_group, slot_key, accepted_equip_slot, data))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if inventory_view == null:
		return

	inventory_view.call("drop_item", slot_group, slot_key, accepted_equip_slot, data)


func _gui_input(event: InputEvent) -> void:
	if inventory_view == null:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			inventory_view.call("open_item_popup", slot_group, slot_key, self)
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			inventory_view.call("open_item_popup", slot_group, slot_key, self)


func _build_contents() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 1)
	margin.add_child(column)

	icon_label = Label.new()
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_color_override("font_color", Color(0.964706, 0.933333, 0.654902, 1))
	icon_label.add_theme_font_size_override("font_size", 24)
	column.add_child(icon_label)

	item_icon = ItemIconScript.new()
	item_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_child(item_icon)

	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.add_theme_color_override("font_color", Color(0.937255, 0.94902, 0.898039, 1))
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.clip_text = true
	column.add_child(name_label)

	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_color_override("font_color", Color(0.756863, 0.886275, 0.741176, 1))
	count_label.add_theme_font_size_override("font_size", 10)
	column.add_child(count_label)


func _refresh() -> void:
	if icon_label == null:
		return

	if item_data.is_empty():
		var empty_color := EMPTY_SLOT_COLOR
		if slot_group == "equipment":
			empty_color = EQUIPMENT_EMPTY_COLOR
		add_theme_stylebox_override("panel", _make_style_box(empty_color, selected))
		item_icon.visible = false
		icon_label.text = _get_empty_icon()
		icon_label.visible = true
		name_label.text = _get_empty_label()
		count_label.text = ""
		tooltip_text = ""
		return

	add_theme_stylebox_override("panel", _make_style_box(FILLED_SLOT_COLOR, selected))
	item_icon.visible = true
	if item_icon.has_method("set_item_name"):
		item_icon.call("set_item_name", str(item_data.get("name", "")))
	icon_label.visible = false
	icon_label.text = ""
	name_label.text = _build_slot_title(item_data)

	var item_count: int = int(item_data.get("count", 1))
	if str(item_data.get("kind", "")) == "equipment":
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.text = _build_stat_summary(item_data)
	else:
		var sell_value_text: String = _build_sell_value_summary(item_data)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if item_count > 1 and not sell_value_text.is_empty():
			count_label.text = "x%d  %s" % [item_count, sell_value_text]
		elif item_count > 1:
			count_label.text = "x%d" % item_count
		else:
			count_label.text = sell_value_text
	tooltip_text = ""


func _get_empty_label() -> String:
	if slot_group == "equipment":
		return accepted_equip_slot.replace("_", " ").capitalize()

	return "Empty"


func _get_empty_icon() -> String:
	if slot_group == "equipment":
		return accepted_equip_slot.substr(0, 1).to_upper()

	return "+"


func _get_item_icon(data: Dictionary) -> String:
	var item_name: String = str(data.get("name", ""))

	match item_name:
		"Traveler Knife":
			return "K"
		"Village Tunic":
			return "T"
		"Slime Jelly":
			return "J"
		"Healer's Herbs":
			return "H"
		"Trail Ration":
			return "R"
		"Supply Ledger":
			return "L"
		_:
			return item_name.substr(0, 1).to_upper()


func _build_slot_title(data: Dictionary) -> String:
	var item_name: String = str(data.get("name", ""))
	if item_name.length() <= 10:
		return item_name

	return item_name.substr(0, 9) + "."


func _build_item_tooltip(data: Dictionary) -> String:
	var item_name: String = str(data.get("name", ""))
	var item_kind: String = str(data.get("kind", "consumable"))
	var equip_slot_name: String = str(data.get("equip_slot", ""))
	var tooltip: String = item_name + "\nType: " + item_kind.capitalize()
	var stat_summary: String = _build_verbose_stat_summary(data)

	if not equip_slot_name.is_empty():
		tooltip += "\nSlot: " + equip_slot_name.capitalize()
	if not stat_summary.is_empty():
		tooltip += "\n" + stat_summary
	var sell_value: int = InventoryStateScript.get_item_value(item_name, item_kind)
	if sell_value > 0:
		tooltip += "\nSell Value: %d G" % maxi(1, int(floor(sell_value / 2.0)))

	return tooltip


func _build_empty_tooltip() -> String:
	if slot_group == "equipment":
		return accepted_equip_slot.capitalize() + " slot"

	return "Bag slot"


func _build_stat_summary(data: Dictionary) -> String:
	var item_name: String = str(data.get("name", ""))
	var stats: Dictionary = InventoryStateScript.get_item_stats(item_name)
	if stats.is_empty():
		return ""

	var stat_bits: Array[String] = []
	var attack_value: int = int(stats.get("attack", 0))
	var defense_value: int = int(stats.get("defense", 0))
	var health_value: int = int(stats.get("max_health", 0))

	if attack_value > 0:
		stat_bits.append("+%d ATK" % attack_value)
	if defense_value > 0:
		stat_bits.append("+%d DEF" % defense_value)
	if health_value > 0:
		stat_bits.append("+%d HP" % health_value)

	return " ".join(stat_bits)


func _build_verbose_stat_summary(data: Dictionary) -> String:
	var item_name: String = str(data.get("name", ""))
	var stats: Dictionary = InventoryStateScript.get_item_stats(item_name)
	if stats.is_empty():
		return ""

	var stat_lines: Array[String] = []
	var attack_value: int = int(stats.get("attack", 0))
	var defense_value: int = int(stats.get("defense", 0))
	var health_value: int = int(stats.get("max_health", 0))

	if attack_value > 0:
		stat_lines.append("Attack: +%d" % attack_value)
	if defense_value > 0:
		stat_lines.append("Defense: +%d" % defense_value)
	if health_value > 0:
		stat_lines.append("Max HP: +%d" % health_value)

	return "\n".join(stat_lines)


func _build_sell_value_summary(data: Dictionary) -> String:
	var item_name: String = str(data.get("name", ""))
	var item_kind: String = str(data.get("kind", "consumable"))
	var item_value: int = InventoryStateScript.get_item_value(item_name, item_kind)
	if item_value <= 0:
		return ""

	return "%d G" % maxi(1, int(floor(item_value / 2.0)))


func _make_style_box(fill_color: Color, is_selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.980392, 0.937255, 0.662745, 0.5) if is_selected else BORDER_COLOR
	style.shadow_color = Color(0, 0, 0, 0.14)
	style.shadow_size = 3
	return style
