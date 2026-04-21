extends PanelContainer

signal purchase_requested(item_name: String, item_kind: String, price: int)
signal sell_requested(item_name: String, item_kind: String, price: int)
signal closed

const InventoryStateScript = preload("res://scripts/world/inventory_state.gd")

@onready var title_label: Label = $MarginContainer/VBoxContainer/HeaderRow/TitleLabel
@onready var gold_label: Label = $MarginContainer/VBoxContainer/HeaderRow/GoldLabel
@onready var buy_tab_button: Button = $MarginContainer/VBoxContainer/TabRow/BuyTabButton
@onready var sell_tab_button: Button = $MarginContainer/VBoxContainer/TabRow/SellTabButton
@onready var buy_section: VBoxContainer = $MarginContainer/VBoxContainer/Pages/BuySection
@onready var sell_section: VBoxContainer = $MarginContainer/VBoxContainer/Pages/SellSection
@onready var stock_list: VBoxContainer = $MarginContainer/VBoxContainer/Pages/BuySection/BuyScroll/BuyList
@onready var sell_list: VBoxContainer = $MarginContainer/VBoxContainer/Pages/SellSection/SellScroll/SellList
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var current_shop_name: String = "Shop"
var current_gold: int = 0
var current_stock: Array[Dictionary] = []
var current_bag_items: Array[Dictionary] = []
var current_mode: String = "buy"


func _ready() -> void:
	visible = false
	buy_tab_button.pressed.connect(_on_buy_tab_button_pressed)
	sell_tab_button.pressed.connect(_on_sell_tab_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	_show_mode("buy")


func _input(event: InputEvent) -> void:
	if not visible:
		return

	var click_position := Vector2.ZERO
	var is_click := false

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		is_click = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
		click_position = mouse_event.position
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		is_click = touch_event.pressed
		click_position = touch_event.position

	if not is_click:
		return

	if get_global_rect().has_point(click_position):
		return

	visible = false
	closed.emit()
	get_viewport().set_input_as_handled()


func open_shop(shop_name: String, gold_amount: int, stock_items: Array, bag_items: Array, status_text: String = "") -> void:
	current_shop_name = shop_name
	current_gold = gold_amount
	current_stock.clear()
	current_bag_items.clear()
	for stock_item in stock_items:
		if typeof(stock_item) == TYPE_DICTIONARY:
			current_stock.append((stock_item as Dictionary).duplicate(true))
	for bag_item in bag_items:
		if typeof(bag_item) == TYPE_DICTIONARY:
			current_bag_items.append((bag_item as Dictionary).duplicate(true))
	title_label.text = shop_name
	_refresh_gold()
	_refresh_lists()
	set_status(status_text)
	_show_mode(current_mode)
	visible = true


func set_gold(gold_amount: int) -> void:
	current_gold = gold_amount
	_refresh_gold()
	_refresh_lists()


func set_inventory_items(bag_items: Array) -> void:
	current_bag_items.clear()
	for bag_item in bag_items:
		if typeof(bag_item) == TYPE_DICTIONARY:
			current_bag_items.append((bag_item as Dictionary).duplicate(true))
	_refresh_lists()


func set_status(text: String) -> void:
	status_label.text = text
	status_label.visible = not text.is_empty()


func _refresh_gold() -> void:
	gold_label.text = "Gold: %d" % current_gold


func _refresh_lists() -> void:
	_refresh_stock()
	_refresh_sell_list()


func _show_mode(mode: String) -> void:
	current_mode = mode
	buy_section.visible = mode == "buy"
	sell_section.visible = mode == "sell"
	_update_tab_buttons()


func _update_tab_buttons() -> void:
	buy_tab_button.disabled = current_mode == "buy"
	sell_tab_button.disabled = current_mode == "sell"
	_apply_tab_style(buy_tab_button, current_mode == "buy")
	_apply_tab_style(sell_tab_button, current_mode == "sell")


func _refresh_stock() -> void:
	for child in stock_list.get_children():
		child.queue_free()

	var grouped_stock: Dictionary = _group_items_by_category(current_stock)
	var category_order := ["Consumables", "Weapons", "Armor", "Accessories", "Materials"]
	var category_index: int = 0

	for category_name in category_order:
		if not grouped_stock.has(category_name):
			continue

		var section: VBoxContainer = _build_category_section(category_name)
		var grid: GridContainer = section.get_meta("grid") as GridContainer
		var section_items: Array = grouped_stock[category_name]
		for stock_item_variant in section_items:
			var stock_item: Dictionary = stock_item_variant
			var price: int = int(stock_item.get("price", 0))
			var row := _build_shop_row(
				str(stock_item.get("name", "Item")),
				_build_item_summary(stock_item),
				"Buy",
				price,
				price > current_gold,
				category_index
			)
			var action_button: Button = row.get_meta("action_button") as Button
			action_button.pressed.connect(_on_buy_button_pressed.bind(str(stock_item.get("name", "")), str(stock_item.get("kind", "consumable")), price))
			grid.add_child(row)

		stock_list.add_child(section)
		category_index += 1


func _refresh_sell_list() -> void:
	for child in sell_list.get_children():
		child.queue_free()

	var sellable_items: Array[Dictionary] = _build_sellable_items()
	if sellable_items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No sellable items in bag."
		empty_label.add_theme_color_override("font_color", Color(0.917647, 0.92549, 0.878431, 0.75))
		empty_label.add_theme_font_size_override("font_size", 11)
		sell_list.add_child(empty_label)
		return

	var grouped_sell: Dictionary = _group_items_by_category(sellable_items)
	var category_order := ["Consumables", "Weapons", "Armor", "Accessories", "Materials"]
	var category_index: int = 0

	for category_name in category_order:
		if not grouped_sell.has(category_name):
			continue

		var section: VBoxContainer = _build_category_section(category_name)
		var grid: GridContainer = section.get_meta("grid") as GridContainer
		var section_items: Array = grouped_sell[category_name]
		for sell_item_variant in section_items:
			var sell_item: Dictionary = sell_item_variant
			var price: int = int(sell_item.get("price", 0))
			var row := _build_shop_row(
				str(sell_item.get("name", "Item")),
				_build_sell_summary(sell_item),
				"Sell",
				price,
				false,
				category_index
			)
			var action_button: Button = row.get_meta("action_button") as Button
			action_button.pressed.connect(_on_sell_button_pressed.bind(str(sell_item.get("name", "")), str(sell_item.get("kind", "consumable")), price))
			grid.add_child(row)

		sell_list.add_child(section)
		category_index += 1


func _build_category_section(category_name: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	var title_label := Label.new()
	title_label.text = category_name
	title_label.add_theme_color_override("font_color", Color(0.964706, 0.933333, 0.654902, 1))
	title_label.add_theme_font_size_override("font_size", 13)
	section.add_child(title_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	section.add_child(grid)
	section.set_meta("grid", grid)
	return section


func _group_items_by_category(items: Array) -> Dictionary:
	var grouped: Dictionary = {}

	for item_variant in items:
		if typeof(item_variant) != TYPE_DICTIONARY:
			continue

		var item_data: Dictionary = item_variant
		var category_name: String = InventoryStateScript.get_item_category(
			str(item_data.get("name", "")),
			str(item_data.get("kind", "consumable"))
		)

		if category_name == "Quest":
			continue

		if not grouped.has(category_name):
			grouped[category_name] = []

		var category_items: Array = grouped[category_name]
		category_items.append(item_data)
		grouped[category_name] = category_items

	return grouped


func _build_shop_row(item_name: String, summary_text: String, action_label: String, price: int, is_disabled: bool, row_index: int) -> PanelContainer:
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(250, 70)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.add_theme_stylebox_override("panel", _create_row_style(row_index))

	var row_margin := MarginContainer.new()
	row_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_margin.add_theme_constant_override("margin_left", 10)
	row_margin.add_theme_constant_override("margin_top", 8)
	row_margin.add_theme_constant_override("margin_right", 10)
	row_margin.add_theme_constant_override("margin_bottom", 8)
	row_panel.add_child(row_margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	row_margin.add_child(row)

	var item_info := VBoxContainer.new()
	item_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_info.add_theme_constant_override("separation", 2)
	row.add_child(item_info)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.add_theme_color_override("font_color", Color(0.964706, 0.933333, 0.654902, 1))
	name_label.add_theme_font_size_override("font_size", 14)
	item_info.add_child(name_label)

	var summary_label := Label.new()
	summary_label.text = summary_text
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_color_override("font_color", Color(0.917647, 0.92549, 0.878431, 0.9))
	summary_label.add_theme_font_size_override("font_size", 11)
	item_info.add_child(summary_label)

	var action_column := VBoxContainer.new()
	action_column.custom_minimum_size = Vector2(92, 0)
	action_column.alignment = BoxContainer.ALIGNMENT_CENTER
	action_column.add_theme_constant_override("separation", 4)
	row.add_child(action_column)

	var price_label := Label.new()
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.text = "%d G" % price
	price_label.add_theme_color_override("font_color", Color(0.984314, 0.827451, 0.313726, 1))
	price_label.add_theme_font_size_override("font_size", 13)
	action_column.add_child(price_label)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(92, 30)
	action_button.text = action_label
	action_button.disabled = is_disabled
	action_column.add_child(action_button)

	row_panel.set_meta("action_button", action_button)
	return row_panel


func _create_row_style(row_index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.18, 0.17, 0.92) if row_index % 2 == 0 else Color(0.205, 0.215, 0.205, 0.92)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.980392, 0.937255, 0.662745, 0.08)
	return style


func _apply_tab_style(button: Button, is_active: bool) -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1

	if is_active:
		normal_style.bg_color = Color(0.16, 0.18, 0.17, 0.96)
		normal_style.border_color = Color(0.980392, 0.937255, 0.662745, 0.18)
		button.add_theme_color_override("font_color", Color(0.964706, 0.933333, 0.654902, 1))
	else:
		normal_style.bg_color = Color(0.10, 0.11, 0.11, 0.86)
		normal_style.border_color = Color(0.980392, 0.937255, 0.662745, 0.08)
		button.add_theme_color_override("font_color", Color(0.86, 0.88, 0.84, 0.86))

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", normal_style)
	button.add_theme_stylebox_override("pressed", normal_style)
	button.add_theme_stylebox_override("disabled", normal_style)


func _build_item_summary(stock_item: Dictionary) -> String:
	var item_name: String = str(stock_item.get("name", ""))
	var item_kind: String = str(stock_item.get("kind", "consumable"))

	if item_kind == "equipment":
		var equip_slot_name: String = InventoryStateScript.infer_equip_slot(item_name)
		var stats: Dictionary = InventoryStateScript.get_item_stats(item_name)
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

		return "%s  %s" % [equip_slot_name.capitalize(), " ".join(stat_bits)]

	var effects: Dictionary = InventoryStateScript.get_consumable_effects(item_name)
	var heal_amount: int = int(effects.get("heal", 0))
	if heal_amount > 0:
		return "Consumable  Restores %d HP" % heal_amount

	return item_kind.capitalize()


func _build_sell_summary(sell_item: Dictionary) -> String:
	var count: int = int(sell_item.get("count", 1))
	var kind: String = str(sell_item.get("kind", "consumable"))
	var detail := kind.capitalize()

	if kind == "equipment":
		detail = _build_item_summary(sell_item)
	elif kind == "consumable":
		detail = _build_item_summary(sell_item)

	return "x%d  %s" % [count, detail]


func _build_sellable_items() -> Array[Dictionary]:
	var sellable: Array[Dictionary] = []
	var grouped: Dictionary = {}

	for raw_item in current_bag_items:
		var normalized_item: Dictionary = InventoryStateScript.normalize_item(raw_item)
		if normalized_item.is_empty():
			continue

		var item_name: String = str(normalized_item.get("name", ""))
		var item_kind: String = str(normalized_item.get("kind", "consumable"))
		var item_value: int = InventoryStateScript.get_item_value(item_name, item_kind)
		if item_value <= 0:
			continue

		if not grouped.has(item_name):
			grouped[item_name] = {
				"name": item_name,
				"kind": item_kind,
				"count": 0,
				"price": maxi(1, int(floor(item_value / 2.0)))
			}

		var grouped_item: Dictionary = grouped[item_name]
		grouped_item["count"] = int(grouped_item.get("count", 0)) + int(normalized_item.get("count", 1))
		grouped[item_name] = grouped_item

	for item_name in grouped.keys():
		sellable.append((grouped[item_name] as Dictionary).duplicate(true))

	sellable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return sellable


func _on_buy_button_pressed(item_name: String, item_kind: String, price: int) -> void:
	purchase_requested.emit(item_name, item_kind, price)


func _on_sell_button_pressed(item_name: String, item_kind: String, price: int) -> void:
	sell_requested.emit(item_name, item_kind, price)


func _on_buy_tab_button_pressed() -> void:
	_show_mode("buy")


func _on_sell_tab_button_pressed() -> void:
	_show_mode("sell")


func _on_close_button_pressed() -> void:
	visible = false
	closed.emit()
