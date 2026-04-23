extends CanvasLayer

signal save_requested
signal load_requested
signal inventory_changed(bag_slots: Array, equipment_slots: Dictionary)
signal use_item_requested(item_name: String)
signal quick_item_assigned(item_name: String, item_kind: String)
signal stat_increase_requested(stat_name: String)
signal menu_toggled(is_open: bool)
signal tracked_quest_toggled(quest_id: String)

const XP_BAR_STEP := 10
const INFO_DISPLAY_SECONDS := 2.6
const INFO_FADE_SECONDS := 0.45
const HUD_SIDE_MARGIN := 16.0
const HUD_TOP_MARGIN := 12.0
const HUD_GAP := 10.0
const COMPACT_LAYOUT_WIDTH := 760.0
const MINIMAP_RESERVED_WIDTH := 214.0

@onready var location_label: Label = $AreaLabel
@onready var combat_label: Label = $InfoLabel
@onready var vitals_panel: PanelContainer = $VitalsPanel
@onready var health_bar: ProgressBar = $VitalsPanel/VBoxContainer/HealthBar
@onready var health_label: Label = $VitalsPanel/VBoxContainer/HealthBar/HealthLabel
@onready var xp_bar: ProgressBar = $VitalsPanel/VBoxContainer/XpBar
@onready var xp_label: Label = $VitalsPanel/VBoxContainer/XpBar/XpLabel
@onready var top_menu_bar: HBoxContainer = $TopMenuBar
@onready var quest_menu_button: Button = $TopMenuBar/QuestMenuButton
@onready var player_menu_button: Button = $TopMenuBar/PlayerMenuButton
@onready var inventory_menu_button: Button = $TopMenuBar/InventoryMenuButton
@onready var save_menu_button: Button = $TopMenuBar/SaveMenuButton
@onready var tracked_quest_panel: PanelContainer = $TrackedQuestPanel
@onready var tracked_quest_title_label: Label = $TrackedQuestPanel/MarginContainer/VBoxContainer/TrackedQuestTitle
@onready var tracked_quest_body_label: Label = $TrackedQuestPanel/MarginContainer/VBoxContainer/TrackedQuestBody
@onready var menu_dimmer: ColorRect = $MenuDimmer
@onready var menu_panel: PanelContainer = $MenuPanel
@onready var quest_page: VBoxContainer = $MenuPanel/MarginContainer/VBoxContainer/Pages/QuestPage
@onready var character_pages: HBoxContainer = $MenuPanel/MarginContainer/VBoxContainer/Pages/CharacterPages
@onready var quest_active_tab_button: Button = $MenuPanel/MarginContainer/VBoxContainer/Pages/QuestPage/QuestTabRow/QuestActiveTabButton
@onready var quest_completed_tab_button: Button = $MenuPanel/MarginContainer/VBoxContainer/Pages/QuestPage/QuestTabRow/QuestCompletedTabButton
@onready var player_window: MarginContainer = $MenuPanel/MarginContainer/VBoxContainer/Pages/CharacterPages/PlayerWindow
@onready var character_spacer: Control = $MenuPanel/MarginContainer/VBoxContainer/Pages/CharacterPages/CharacterSpacer
@onready var inventory_window: MarginContainer = $MenuPanel/MarginContainer/VBoxContainer/Pages/CharacterPages/InventoryWindow
@onready var save_page: VBoxContainer = $MenuPanel/MarginContainer/VBoxContainer/Pages/SavePage
@onready var quest_list: ItemList = $MenuPanel/MarginContainer/VBoxContainer/Pages/QuestPage/QuestContent/QuestListPanel/MarginContainer/QuestList
@onready var quest_title_label: Label = $MenuPanel/MarginContainer/VBoxContainer/Pages/QuestPage/QuestContent/QuestDetailPanel/MarginContainer/VBoxContainer/QuestTitle
@onready var quest_status_label: Label = $MenuPanel/MarginContainer/VBoxContainer/Pages/QuestPage/QuestContent/QuestDetailPanel/MarginContainer/VBoxContainer/QuestStatus
@onready var quest_body_label: Label = $MenuPanel/MarginContainer/VBoxContainer/Pages/QuestPage/QuestContent/QuestDetailPanel/MarginContainer/VBoxContainer/QuestBody
@onready var track_quest_button: Button = $MenuPanel/MarginContainer/VBoxContainer/Pages/QuestPage/QuestContent/QuestDetailPanel/MarginContainer/VBoxContainer/TrackQuestButton
@onready var player_view: Node = $MenuPanel/MarginContainer/VBoxContainer/Pages/CharacterPages/PlayerWindow/PlayerView
@onready var inventory_view: Node = $MenuPanel/MarginContainer/VBoxContainer/Pages/CharacterPages/InventoryWindow/InventoryView
@onready var save_status_label: Label = $MenuPanel/MarginContainer/VBoxContainer/Pages/SavePage/SaveStatus
@onready var save_button: Button = $MenuPanel/MarginContainer/VBoxContainer/Pages/SavePage/ButtonRow/SaveButton
@onready var load_button: Button = $MenuPanel/MarginContainer/VBoxContainer/Pages/SavePage/ButtonRow/LoadButton
@onready var dungeon_map: Control = $DungeonMap

var info_fade_tween: Tween
var current_tab: String = "quest"
var menu_locked: bool = false
var quest_entries: Array[Dictionary] = []
var visible_quest_ids: Array[String] = []
var selected_quest_id: String = ""
var tracked_quest_ids: Array[String] = []
var current_quest_filter: String = "active"
var default_menu_panel_style: StyleBox
var empty_menu_panel_style := StyleBoxEmpty.new()


func _ready() -> void:
	default_menu_panel_style = menu_panel.get_theme_stylebox("panel")
	quest_menu_button.pressed.connect(_on_quest_menu_button_pressed)
	player_menu_button.pressed.connect(_on_player_menu_button_pressed)
	inventory_menu_button.pressed.connect(_on_inventory_menu_button_pressed)
	save_menu_button.pressed.connect(_on_save_menu_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	quest_list.item_selected.connect(_on_quest_list_item_selected)
	quest_active_tab_button.pressed.connect(_on_quest_active_tab_button_pressed)
	quest_completed_tab_button.pressed.connect(_on_quest_completed_tab_button_pressed)
	track_quest_button.pressed.connect(_on_track_quest_button_pressed)
	if player_view.has_signal("inventory_changed"):
		player_view.connect("inventory_changed", Callable(self, "_on_inventory_view_changed"))
	if player_view.has_signal("stat_increase_requested"):
		player_view.connect("stat_increase_requested", Callable(self, "_on_stat_increase_requested"))
	if inventory_view.has_signal("inventory_changed"):
		inventory_view.connect("inventory_changed", Callable(self, "_on_inventory_view_changed"))
	if inventory_view.has_signal("use_item_requested"):
		inventory_view.connect("use_item_requested", Callable(self, "_on_inventory_use_requested"))
	if inventory_view.has_signal("quick_item_assigned"):
		inventory_view.connect("quick_item_assigned", Callable(self, "_on_quick_item_assigned"))
	menu_dimmer.gui_input.connect(_on_menu_dimmer_gui_input)
	combat_label.modulate.a = 0.0
	menu_dimmer.visible = false
	menu_panel.visible = false
	player_window.visible = false
	character_spacer.visible = false
	inventory_window.visible = false
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_show_menu_tab(current_tab)
	_update_top_menu_buttons()
	call_deferred("_apply_responsive_layout")


func set_quest(title: String, body: String) -> void:
	set_quest_journal(
		[
			{
				"id": "active",
				"title": title,
				"status": "Active",
				"summary": body,
				"details": body,
				"trackable": true
			}
		],
		["active"]
	)


func set_header(_helper_text: String, location_text: String) -> void:
	location_label.text = location_text


func set_status(health_value: int, max_health: int, xp_value: int, combat_text: String, low_health: bool, xp_max_value: int = XP_BAR_STEP, level_value: int = 1) -> void:
	health_bar.max_value = max_health
	health_bar.value = health_value
	health_label.text = "HP %d/%d" % [health_value, max_health]
	_update_xp_bar(xp_value, xp_max_value, level_value)
	_show_info_text(combat_text)

	if low_health:
		health_label.modulate = Color(0.949, 0.494, 0.415, 1.0)
	else:
		health_label.modulate = Color(1.0, 1.0, 1.0, 1.0)


func set_inventory_state(bag_slots: Variant, equipment_slots: Variant, gold_amount: int = 0) -> void:
	if player_view.has_method("set_inventory_state"):
		player_view.call("set_inventory_state", bag_slots, equipment_slots, gold_amount)
	if inventory_view.has_method("set_inventory_state"):
		inventory_view.call("set_inventory_state", bag_slots, equipment_slots, gold_amount)


func set_progression_state(level: int, unspent_points: int, allocations: Dictionary, attack_value: int, defense_value: int, max_health_value: int) -> void:
	if player_view.has_method("set_progression_state"):
		player_view.call("set_progression_state", level, unspent_points, allocations, attack_value, defense_value, max_health_value)


func set_save_status(text: String) -> void:
	save_status_label.text = text


func set_dungeon_map_state(map_data: Dictionary) -> void:
	if dungeon_map != null and dungeon_map.has_method("set_map_state"):
		dungeon_map.call("set_map_state", map_data)
	_apply_responsive_layout()


func set_dungeon_map_player_position(player_map_position: Vector2, player_cell: Vector2i) -> void:
	if dungeon_map != null and dungeon_map.has_method("set_player_tracking"):
		dungeon_map.call("set_player_tracking", player_map_position, player_cell)


func set_quest_journal(entries: Array, next_tracked_quest_ids: Array = []) -> void:
	quest_entries.clear()
	for entry_variant in entries:
		if typeof(entry_variant) == TYPE_DICTIONARY:
			quest_entries.append((entry_variant as Dictionary).duplicate(true))

	tracked_quest_ids.clear()
	for quest_id_variant in next_tracked_quest_ids:
		tracked_quest_ids.append(str(quest_id_variant))

	if quest_entries.is_empty():
		selected_quest_id = ""
	else:
		if _find_quest_index_by_id(selected_quest_id) < 0:
			selected_quest_id = tracked_quest_ids[0] if not tracked_quest_ids.is_empty() else ""
		if _find_quest_index_by_id(selected_quest_id) < 0:
			selected_quest_id = str(quest_entries[0].get("id", ""))

	_refresh_quest_journal()


func set_menu_locked(value: bool) -> void:
	menu_locked = value
	if menu_locked and _is_any_menu_open():
		_close_all_menus()

	quest_menu_button.disabled = menu_locked
	player_menu_button.disabled = menu_locked
	inventory_menu_button.disabled = menu_locked
	save_menu_button.disabled = menu_locked


func _on_save_button_pressed() -> void:
	save_requested.emit()


func _on_load_button_pressed() -> void:
	load_requested.emit()


func _on_quest_list_item_selected(index: int) -> void:
	if index < 0 or index >= visible_quest_ids.size():
		return

	selected_quest_id = visible_quest_ids[index]
	_refresh_quest_details()


func _on_quest_active_tab_button_pressed() -> void:
	current_quest_filter = "active"
	_refresh_quest_journal()


func _on_quest_completed_tab_button_pressed() -> void:
	current_quest_filter = "completed"
	_refresh_quest_journal()


func _on_track_quest_button_pressed() -> void:
	var selected_entry: Dictionary = _get_selected_quest_entry()
	if selected_entry.is_empty():
		return

	tracked_quest_toggled.emit(str(selected_entry.get("id", "")))


func _on_inventory_view_changed(bag_slots: Array, equipment_slots: Dictionary) -> void:
	inventory_changed.emit(bag_slots, equipment_slots)


func _on_inventory_use_requested(item_name: String) -> void:
	use_item_requested.emit(item_name)


func _on_quick_item_assigned(item_name: String, item_kind: String) -> void:
	quick_item_assigned.emit(item_name, item_kind)


func _on_stat_increase_requested(stat_name: String) -> void:
	stat_increase_requested.emit(stat_name)


func _on_quest_menu_button_pressed() -> void:
	_toggle_menu_tab("quest")


func _on_inventory_menu_button_pressed() -> void:
	_toggle_inventory_window()


func _on_player_menu_button_pressed() -> void:
	_toggle_player_window()


func _on_save_menu_button_pressed() -> void:
	_toggle_menu_tab("save")


func _on_menu_dimmer_gui_input(event: InputEvent) -> void:
	if not _is_any_menu_open() or menu_locked:
		return

	var is_click := false
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		is_click = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		is_click = touch_event.pressed

	if not is_click:
		return

	_close_all_menus()
	get_viewport().set_input_as_handled()


func _update_xp_bar(xp_value: int, xp_max_value: int, level_value: int) -> void:
	var safe_max: int = maxi(1, xp_max_value)
	xp_bar.max_value = safe_max
	xp_bar.value = clampi(xp_value, 0, safe_max)
	xp_label.text = "Lv %d  XP %d/%d" % [level_value, xp_value, safe_max]


func _show_info_text(text: String) -> void:
	combat_label.text = text

	if info_fade_tween != null:
		info_fade_tween.kill()

	if text.is_empty():
		combat_label.modulate.a = 0.0
		return

	combat_label.modulate.a = 1.0
	info_fade_tween = create_tween()
	info_fade_tween.tween_interval(INFO_DISPLAY_SECONDS)
	info_fade_tween.tween_property(combat_label, "modulate:a", 0.0, INFO_FADE_SECONDS)


func _show_menu_tab(tab_name: String) -> void:
	current_tab = tab_name
	quest_page.visible = tab_name == "quest"
	character_pages.visible = tab_name == "character" and (player_window.visible or inventory_window.visible)
	save_page.visible = tab_name == "save"
	if tab_name == "character":
		menu_panel.add_theme_stylebox_override("panel", empty_menu_panel_style)
	else:
		menu_panel.add_theme_stylebox_override("panel", default_menu_panel_style)
	_apply_menu_layout(tab_name)
	_update_top_menu_buttons()


func _open_menu_for_tab(tab_name: String) -> void:
	player_window.visible = false
	inventory_window.visible = false
	_show_menu_tab(tab_name)
	_set_menu_open(true)


func _set_menu_open(is_open: bool) -> void:
	var state_changed: bool = _is_any_menu_open() != is_open
	menu_panel.visible = is_open
	menu_dimmer.visible = is_open
	_update_top_menu_buttons()

	if state_changed:
		menu_toggled.emit(is_open)


func _toggle_menu_tab(tab_name: String) -> void:
	if menu_locked:
		return

	if menu_panel.visible and current_tab == tab_name:
		_set_menu_open(false)
		return

	_open_menu_for_tab(tab_name)


func _toggle_player_window() -> void:
	if menu_locked:
		return

	player_window.visible = not player_window.visible
	current_tab = "character"
	_refresh_character_pages()
	_show_menu_tab("character")
	_update_menu_open_state()


func _toggle_inventory_window() -> void:
	if menu_locked:
		return

	inventory_window.visible = not inventory_window.visible
	current_tab = "character"
	_refresh_character_pages()
	_show_menu_tab("character")
	_update_menu_open_state()


func _refresh_character_pages() -> void:
	character_pages.visible = player_window.visible or inventory_window.visible
	character_spacer.visible = player_window.visible or inventory_window.visible

	if player_window.visible and inventory_window.visible:
		player_window.size_flags_horizontal = Control.SIZE_FILL
		character_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inventory_window.size_flags_horizontal = Control.SIZE_FILL
		player_window.custom_minimum_size = Vector2(300, 0)
		inventory_window.custom_minimum_size = Vector2(440, 0)
	elif player_window.visible:
		player_window.size_flags_horizontal = Control.SIZE_FILL
		character_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inventory_window.size_flags_horizontal = Control.SIZE_FILL
		player_window.custom_minimum_size = Vector2(300, 0)
		inventory_window.custom_minimum_size = Vector2(440, 0)
	elif inventory_window.visible:
		player_window.size_flags_horizontal = Control.SIZE_FILL
		character_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inventory_window.size_flags_horizontal = Control.SIZE_FILL
		player_window.custom_minimum_size = Vector2(300, 0)
		inventory_window.custom_minimum_size = Vector2(440, 0)
	else:
		player_window.custom_minimum_size = Vector2(300, 0)
		inventory_window.custom_minimum_size = Vector2(440, 0)


func _update_menu_open_state() -> void:
	var was_open: bool = _is_any_menu_open()
	var any_open: bool = quest_page.visible or save_page.visible or player_window.visible or inventory_window.visible
	menu_panel.visible = any_open
	menu_dimmer.visible = any_open
	_update_top_menu_buttons()
	if was_open != any_open:
		menu_toggled.emit(any_open)


func _close_all_menus() -> void:
	var was_open: bool = _is_any_menu_open()
	menu_panel.visible = false
	player_window.visible = false
	character_spacer.visible = false
	inventory_window.visible = false
	character_pages.visible = false
	menu_dimmer.visible = false
	_update_top_menu_buttons()
	if was_open:
		menu_toggled.emit(false)


func _is_any_menu_open() -> bool:
	return menu_panel.visible or player_window.visible or inventory_window.visible


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var compact: bool = viewport_size.x <= COMPACT_LAYOUT_WIDTH
	var side_margin: float = 10.0 if compact else HUD_SIDE_MARGIN
	var top_margin: float = 10.0 if compact else HUD_TOP_MARGIN
	var top_button_width: float = 48.0 if compact else 58.0
	var top_button_height: float = 30.0 if compact else 34.0
	var top_button_font_size: int = 11 if compact else 12
	var vitals_width: float = clampf(viewport_size.x * (0.24 if compact else 0.21), 136.0, 220.0)
	var bar_height: float = 16.0 if compact else 18.0
	var info_top: float = -82.0 if compact else -54.0
	var vitals_height: float = 54.0
	var center_x: float = viewport_size.x * 0.5

	for button in [quest_menu_button, player_menu_button, inventory_menu_button, save_menu_button]:
		button.custom_minimum_size = Vector2(top_button_width, top_button_height)
		button.add_theme_font_size_override("font_size", top_button_font_size)

	var top_menu_width: float = top_button_width * 4.0 + HUD_GAP * 3.0
	top_menu_bar.anchor_left = 1.0
	top_menu_bar.anchor_right = 1.0
	top_menu_bar.offset_left = -side_margin - top_menu_width
	top_menu_bar.offset_top = top_margin
	top_menu_bar.offset_right = -side_margin
	top_menu_bar.offset_bottom = top_margin + top_button_height

	vitals_panel.offset_left = side_margin
	vitals_panel.offset_top = top_margin
	vitals_panel.offset_right = side_margin + vitals_width
	vitals_panel.offset_bottom = top_margin + vitals_height
	health_bar.custom_minimum_size = Vector2(0.0, bar_height)
	xp_bar.custom_minimum_size = Vector2(0.0, maxf(10.0, bar_height * 0.72))
	health_label.add_theme_font_size_override("font_size", 10 if compact else 11)
	xp_label.add_theme_font_size_override("font_size", 10 if compact else 11)

	location_label.anchor_left = 0.5
	location_label.anchor_right = 0.5
	location_label.add_theme_font_size_override("font_size", 15 if compact else 18)
	var location_width: float = minf(viewport_size.x - side_margin * 2.0, 360.0 if compact else 420.0)
	if compact:
		location_label.offset_left = -location_width * 0.5
		location_label.offset_right = location_width * 0.5
		location_label.offset_top = top_margin + vitals_height + 2.0
		location_label.offset_bottom = location_label.offset_top + 24.0
	else:
		location_label.offset_left = -location_width * 0.5
		location_label.offset_right = location_width * 0.5
		location_label.offset_top = top_margin + 2.0
		location_label.offset_bottom = location_label.offset_top + 26.0

	tracked_quest_title_label.add_theme_font_size_override("font_size", 11 if compact else 12)
	tracked_quest_body_label.add_theme_font_size_override("font_size", 10 if compact else 11)
	var tracker_width: float = clampf(viewport_size.x * (0.30 if compact else 0.24), 210.0, 280.0)
	var tracker_top: float = top_margin + vitals_height + 10.0
	tracked_quest_panel.anchor_left = 0.0
	tracked_quest_panel.anchor_right = 0.0
	tracked_quest_panel.offset_left = side_margin
	tracked_quest_panel.offset_top = tracker_top
	tracked_quest_panel.offset_right = side_margin + tracker_width
	tracked_quest_panel.offset_bottom = tracker_top + (58.0 if compact else 64.0)

	combat_label.anchor_left = 0.0
	combat_label.anchor_right = 1.0
	combat_label.offset_left = 24.0
	combat_label.offset_top = info_top
	combat_label.offset_right = -24.0
	combat_label.offset_bottom = -20.0
	combat_label.add_theme_font_size_override("font_size", 10 if compact else 11)

	_apply_menu_layout(current_tab)


func _apply_menu_layout(tab_name: String) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var compact: bool = viewport_size.x <= COMPACT_LAYOUT_WIDTH
	menu_panel.anchor_left = 0.0
	menu_panel.anchor_top = 0.0
	menu_panel.anchor_right = 1.0
	menu_panel.anchor_bottom = 1.0

	var side_margin: float = 14.0 if compact else (62.0 if tab_name == "character" else 48.0)
	var top_margin: float = 84.0 if compact else (92.0 if tab_name == "character" else 88.0)
	var bottom_margin: float = 14.0 if compact else 24.0
	if compact and tab_name == "character":
		top_margin = 90.0

	menu_panel.offset_left = side_margin
	menu_panel.offset_top = top_margin
	menu_panel.offset_right = -side_margin
	menu_panel.offset_bottom = -bottom_margin


func _update_top_menu_buttons() -> void:
	_set_top_button_state(quest_menu_button, menu_panel.visible and current_tab == "quest")
	_set_top_button_state(player_menu_button, player_window.visible)
	_set_top_button_state(inventory_menu_button, inventory_window.visible)
	_set_top_button_state(save_menu_button, menu_panel.visible and current_tab == "save")


func _set_top_button_state(button: Button, is_active: bool) -> void:
	button.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_active else Color(0.84, 0.9, 0.82, 0.88)


func _refresh_quest_journal() -> void:
	quest_list.clear()
	visible_quest_ids.clear()

	var filtered_entries: Array[Dictionary] = _get_filtered_quest_entries()
	for entry in filtered_entries:
		var item_title: String = str(entry.get("title", "Quest"))
		visible_quest_ids.append(str(entry.get("id", "")))
		quest_list.add_item(item_title)

	if _find_visible_quest_index_by_id(selected_quest_id) < 0:
		if not filtered_entries.is_empty():
			selected_quest_id = str(filtered_entries[0].get("id", ""))
		else:
			selected_quest_id = ""

	var selected_index: int = _find_visible_quest_index_by_id(selected_quest_id)
	if selected_index >= 0:
		quest_list.select(selected_index)

	_update_quest_tab_buttons()
	_refresh_quest_details()
	_refresh_tracked_quest_panel()


func _refresh_quest_details() -> void:
	var selected_entry: Dictionary = _get_selected_quest_entry()
	if selected_entry.is_empty():
		quest_title_label.text = "No Quest Selected"
		quest_status_label.text = "Select a quest to view details."
		quest_body_label.text = "Quest details"
		track_quest_button.disabled = true
		track_quest_button.text = "Track Quest"
		return

	quest_title_label.text = str(selected_entry.get("title", "Quest"))
	quest_status_label.text = str(selected_entry.get("status_text", selected_entry.get("status", "Active")))
	quest_body_label.text = str(selected_entry.get("details", selected_entry.get("summary", "")))
	var selected_id: String = str(selected_entry.get("id", ""))
	var is_trackable: bool = bool(selected_entry.get("trackable", true))
	track_quest_button.disabled = not is_trackable
	track_quest_button.text = "Untrack Quest" if tracked_quest_ids.has(selected_id) else "Track Quest"


func _refresh_tracked_quest_panel() -> void:
	if tracked_quest_ids.is_empty():
		tracked_quest_title_label.text = "Tracked Quests"
		tracked_quest_body_label.text = "No quests tracked."
		return

	var lines: Array[String] = []
	for quest_id in tracked_quest_ids:
		var tracked_entry: Dictionary = _get_quest_entry_by_id(quest_id)
		if tracked_entry.is_empty():
			continue
		lines.append(_format_tracked_quest_summary(tracked_entry))

	tracked_quest_title_label.text = "Tracked Quests"
	tracked_quest_body_label.text = "\n\n---\n\n".join(lines)


func _get_selected_quest_entry() -> Dictionary:
	return _get_quest_entry_by_id(selected_quest_id)


func _get_quest_entry_by_id(quest_id: String) -> Dictionary:
	for entry in quest_entries:
		if str(entry.get("id", "")) == quest_id:
			return entry
	return {}


func _find_quest_index_by_id(quest_id: String) -> int:
	for index in range(quest_entries.size()):
		if str(quest_entries[index].get("id", "")) == quest_id:
			return index
	return -1


func _find_visible_quest_index_by_id(quest_id: String) -> int:
	for index in range(visible_quest_ids.size()):
		if visible_quest_ids[index] == quest_id:
			return index
	return -1


func _get_filtered_quest_entries() -> Array[Dictionary]:
	var filtered_entries: Array[Dictionary] = []
	for entry in quest_entries:
		var is_completed: bool = str(entry.get("status", "")) == "Complete"
		if current_quest_filter == "completed":
			if is_completed:
				filtered_entries.append(entry)
		else:
			if not is_completed:
				filtered_entries.append(entry)
	return filtered_entries


func _update_quest_tab_buttons() -> void:
	_set_top_button_state(quest_active_tab_button, current_quest_filter == "active")
	_set_top_button_state(quest_completed_tab_button, current_quest_filter == "completed")


func _format_tracked_quest_summary(entry: Dictionary) -> String:
	var title_text: String = str(entry.get("title", "Quest")).strip_edges()
	var summary_text: String = str(entry.get("summary", "")).strip_edges()
	if summary_text.begins_with("%s:" % title_text):
		summary_text = summary_text.trim_prefix("%s:" % title_text).strip_edges()
	elif summary_text.begins_with("%s -" % title_text):
		summary_text = summary_text.trim_prefix("%s -" % title_text).strip_edges()
	if summary_text.is_empty():
		summary_text = str(entry.get("details", "")).strip_edges()
	if not summary_text.is_empty() and not summary_text.begins_with("- "):
		summary_text = "- %s" % summary_text
	return "%s\n%s" % [title_text, summary_text]
