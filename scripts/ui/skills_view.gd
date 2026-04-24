extends Control

signal unlock_node_requested(node_id: String)
signal equip_skill_requested(skill_family: String, slot_index: int)

const SkillTreeResolverScript = preload("res://scripts/world/skill_tree_resolver.gd")
const ClassProgressionStateScript = preload("res://scripts/world/class_progression_state.gd")
const RogueSkillTreeLayoutScript = preload("res://scripts/ui/rogue_skill_tree_layout.gd")

const NODE_SIZE := Vector2(28, 28)
const NODE_LABEL_SIZE := Vector2(104, 22)
const REGION_COLUMN_GAP := 300.0
const NODE_ROW_GAP := 80.0
const TOP_PADDING := 84.0
const LEFT_PADDING := 110.0
const CLUSTER_RADIUS := 92.0
const CLUSTER_CENTER_OFFSET := Vector2.ZERO
const LOOSE_NODE_X_PATTERN := [0.0, 24.0, -18.0, 36.0, -28.0, 16.0, -12.0]
const REGION_Y_OFFSETS := [0.0, 120.0, 42.0, 156.0, 68.0, 184.0, 96.0, 212.0]
const MIN_TREE_ZOOM := 0.32
const MAX_TREE_ZOOM := 1.45
const TREE_ZOOM_STEP := 0.1
const MOUSE_DRAG_THRESHOLD := 8.0
const POPUP_MARGIN := 18.0
const TREE_CANVAS_MARGIN := Vector2(420.0, 280.0)

@onready var class_label: Label = $MarginContainer/MainColumn/HeaderRow/ClassLabel
@onready var points_label: Label = $MarginContainer/MainColumn/HeaderRow/PointsLabel
@onready var tree_scroll: Control = $MarginContainer/MainColumn/BodyRow/TreePanel/MarginContainer/TreeColumn/TreeScroll
@onready var graph_canvas: Control = $MarginContainer/MainColumn/BodyRow/TreePanel/MarginContainer/TreeColumn/TreeScroll/GraphCanvas
@onready var info_popup: PanelContainer = $InfoPopup
@onready var close_popup_button: Button = $InfoPopup/MarginContainer/DetailColumn/PopupHeader/CloseButton
@onready var node_title_label: Label = $InfoPopup/MarginContainer/DetailColumn/PopupHeader/NodeTitle
@onready var node_meta_label: Label = $InfoPopup/MarginContainer/DetailColumn/NodeMeta
@onready var node_body_label: Label = $InfoPopup/MarginContainer/DetailColumn/NodeBody
@onready var cluster_label: Label = $InfoPopup/MarginContainer/DetailColumn/ClusterLabel
@onready var unlock_button: Button = $InfoPopup/MarginContainer/DetailColumn/ActionRow/UnlockButton

var progression_state: Dictionary = {}
var resolved_progression: Dictionary = {}
var regions: Array[Dictionary] = []
var nodes: Dictionary = {}
var clusters: Array[Dictionary] = []
var node_buttons: Dictionary = {}
var node_outer_rings: Dictionary = {}
var node_inner_cores: Dictionary = {}
var node_labels: Dictionary = {}
var connection_lines: Array[Line2D] = []
var node_positions: Dictionary = {}
var selected_node_id: String = ""
var tree_zoom: float = 1.0
var should_focus_selected: bool = false
var is_mouse_panning: bool = false
var mouse_pan_last_position: Vector2 = Vector2.ZERO
var mouse_pan_button: int = MOUSE_BUTTON_NONE
var pending_node_click_id: String = ""
var mouse_pan_total_distance: float = 0.0
var touch_points: Dictionary = {}
var last_pinch_distance: float = 0.0
var tree_pan_offset: Vector2 = Vector2.ZERO
var popup_open: bool = false
var layout_edit_mode: bool = false
var dragged_layout_node_id: String = ""
var dragged_layout_pointer_offset: Vector2 = Vector2.ZERO
var runtime_layout_overrides: Dictionary = {}
var current_layout_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	unlock_button.pressed.connect(_on_unlock_button_pressed)
	close_popup_button.pressed.connect(_on_close_popup_button_pressed)
	graph_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_canvas.resized.connect(_refresh_connection_lines)
	info_popup.hide()
	_refresh_view()


func set_skills_state(next_progression_state: Variant, next_resolved_progression: Variant) -> void:
	progression_state = next_progression_state if typeof(next_progression_state) == TYPE_DICTIONARY else {}
	resolved_progression = next_resolved_progression if typeof(next_resolved_progression) == TYPE_DICTIONARY else {}
	regions.clear()
	for region_variant in resolved_progression.get("regions", []):
		if typeof(region_variant) == TYPE_DICTIONARY:
			regions.append((region_variant as Dictionary).duplicate(true))
	clusters.clear()
	for cluster_variant in resolved_progression.get("clusters", []):
		if typeof(cluster_variant) == TYPE_DICTIONARY:
			clusters.append((cluster_variant as Dictionary).duplicate(true))
	nodes = _extract_nodes_from_resolved(resolved_progression)
	if not nodes.has(selected_node_id):
		selected_node_id = _pick_default_node()
	should_focus_selected = true
	_rebuild_graph()
	_refresh_view()


func _rebuild_graph() -> void:
	for child in graph_canvas.get_children():
		child.queue_free()
	node_buttons.clear()
	node_outer_rings.clear()
	node_inner_cores.clear()
	node_labels.clear()
	connection_lines.clear()
	node_positions.clear()

	var max_region_height: float = 0.0
	var class_id: String = str(resolved_progression.get("class_id", progression_state.get("class_id", "rogue")))
	for region_index in range(regions.size()):
		var region: Dictionary = regions[region_index]
		var x_position: float = _scaled(LEFT_PADDING) + float(region_index) * _scaled(REGION_COLUMN_GAP)
		var y_offset: float = _get_region_y_offset(region_index)

		var region_positions: Dictionary = _build_region_positions(region, x_position, y_offset)
		for node_key in region_positions.keys():
			node_positions[str(node_key)] = region_positions[node_key]
			max_region_height = maxf(max_region_height, (region_positions[node_key] as Vector2).y)

		_add_region_cluster_visuals(region)

	_apply_hand_authored_positions(class_id)
	for node_key in node_positions.keys():
		max_region_height = maxf(max_region_height, (node_positions[node_key] as Vector2).y)

	for node_id in node_positions.keys():
		var node_data: Dictionary = nodes.get(node_id, {})
		if node_data.is_empty():
			continue
		var button_size: Vector2 = _get_node_button_size(node_data)
		var button := Button.new()
		button.text = ""
		button.toggle_mode = true
		button.size = button_size
		button.position = node_positions[node_id]
		button.flat = false
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.tooltip_text = str(node_data.get("name", node_id))
		graph_canvas.add_child(button)
		node_buttons[node_id] = button
		_add_socket_visual(node_id, node_data, button)
		_add_node_label(node_id, node_data, button)

	var canvas_width: float = _scaled(LEFT_PADDING * 2.0 + maxi(1, regions.size()) * REGION_COLUMN_GAP + 220.0)
	var canvas_height: float = maxf(_scaled(760.0), max_region_height + _scaled(240.0))
	var canvas_size: Vector2 = _expand_canvas_for_layout_bounds(canvas_width, canvas_height)
	canvas_width = canvas_size.x
	canvas_height = canvas_size.y
	graph_canvas.custom_minimum_size = Vector2(canvas_width, canvas_height)
	_clamp_tree_pan_offset()
	graph_canvas.position = -tree_pan_offset
	call_deferred("_refresh_connection_lines")


func _refresh_connection_lines() -> void:
	for line in connection_lines:
		if is_instance_valid(line):
			line.queue_free()
	connection_lines.clear()

	var rendered_pairs := {}
	for node_id in node_buttons.keys():
		var node_data: Dictionary = nodes.get(node_id, {})
		for connection_variant in node_data.get("connections", []):
			var target_id: String = str(connection_variant)
			if not node_buttons.has(target_id):
				continue
			var pair_key: String = _build_pair_key(node_id, target_id)
			if rendered_pairs.has(pair_key):
				continue
			rendered_pairs[pair_key] = true
			_add_connection_line(node_id, target_id)

	for node_id in node_buttons.keys():
		var button: Button = node_buttons[node_id]
		var node_data: Dictionary = nodes.get(node_id, {})
		button.text = ""
		button.button_pressed = node_id == selected_node_id
		button.disabled = false
		button.modulate = _get_node_modulate(node_id)
		_apply_socket_visual(node_id, node_data)
		_apply_button_theme(button, node_id, node_data)


func _refresh_view() -> void:
	var class_id: String = str(resolved_progression.get("class_id", progression_state.get("class_id", "rogue")))
	class_label.text = "%s Skills%s" % [class_id.capitalize(), "  [Layout Edit]" if layout_edit_mode else ""]
	points_label.text = "Points: %d" % int(progression_state.get("available_skill_points", 0))

	var node_data: Dictionary = nodes.get(selected_node_id, {})
	if node_data.is_empty():
		info_popup.hide()
		popup_open = false
	else:
		if popup_open:
			info_popup.show()
			_update_popup_layout()
		else:
			info_popup.hide()
		node_title_label.text = str(node_data.get("name", selected_node_id))
		node_meta_label.text = _build_node_meta(selected_node_id, node_data)
		node_body_label.text = _build_node_body(node_data)
		cluster_label.text = _build_cluster_text(node_data)
		var node_unlocked: bool = _is_node_unlocked(selected_node_id)
		var node_unlockable: bool = _is_node_unlockable(selected_node_id)
		unlock_button.disabled = node_unlocked or not node_unlockable or int(progression_state.get("available_skill_points", 0)) <= 0
		unlock_button.text = "Unlocked" if node_unlocked else "Unlock Node"
	_refresh_connection_lines()
	if should_focus_selected:
		should_focus_selected = false
		call_deferred("_focus_selected_node")


func _on_graph_node_pressed(node_id: String) -> void:
	selected_node_id = node_id
	should_focus_selected = false
	popup_open = true
	_refresh_view()


func _on_unlock_button_pressed() -> void:
	if not selected_node_id.is_empty():
		unlock_node_requested.emit(selected_node_id)


func _on_close_popup_button_pressed() -> void:
	popup_open = false
	info_popup.hide()


func _pick_default_node() -> String:
	for preferred_id in resolved_progression.get("valid_unlocked_node_ids", []):
		var node_id: String = str(preferred_id)
		if nodes.has(node_id):
			return node_id
	for node_key in nodes.keys():
		return str(node_key)
	return ""


func _extract_nodes_from_resolved(next_resolved_progression: Dictionary) -> Dictionary:
	var class_id: String = str(next_resolved_progression.get("class_id", "rogue"))
	var tree: Dictionary = SkillTreeResolverScript.get_tree_for_class(class_id)
	return (tree.get("nodes", {}) as Dictionary).duplicate(true)


func _build_node_meta(node_id: String, node_data: Dictionary) -> String:
	var meta_bits: Array[String] = []
	meta_bits.append("Type: %s" % _get_node_type_label(node_data))
	if _is_node_unlocked(node_id):
		meta_bits.append("State: unlocked")
	elif _is_node_unlockable(node_id):
		meta_bits.append("State: unlockable")
	else:
		meta_bits.append("State: locked")
	return "  |  ".join(meta_bits)


func _build_node_body(node_data: Dictionary) -> String:
	var lines: Array[String] = [str(node_data.get("ui_text", ""))]
	var effects: Dictionary = node_data.get("effects", {})
	if not effects.is_empty():
		lines.append("")
		lines.append("Effects:")
		for effect_key in effects.keys():
			var effect_value: int = int(effects.get(effect_key, 0))
			var sign: String = "+" if effect_value >= 0 else ""
			lines.append("%s%d %s" % [sign, effect_value, str(effect_key).replace("_", " ")])
	return "\n".join(lines).strip_edges()


func _build_cluster_text(node_data: Dictionary) -> String:
	var cluster_id: String = str(node_data.get("cluster_id", ""))
	if cluster_id.is_empty():
		return ""
	var cluster_progress: Dictionary = resolved_progression.get("cluster_progress", {})
	var cluster_data: Dictionary = cluster_progress.get(cluster_id, {})
	if cluster_data.is_empty():
		return ""
	return "Cluster: %s (%d/%d outer nodes)" % [
		str(cluster_data.get("name", cluster_id)),
		int(cluster_data.get("outer_unlocked", 0)),
		int(cluster_data.get("outer_total", 0))
	]


func _get_node_button_text(node_id: String, node_data: Dictionary) -> String:
	var name_text: String = str(node_data.get("name", node_id))
	return name_text


func _get_node_type_label(node_data: Dictionary) -> String:
	var node_type: String = str(node_data.get("type", "passive_minor"))
	match node_type:
		"active_unlock":
			return "Skill Unlock"
		"active_upgrade":
			return "Skill Upgrade"
		"passive_minor":
			return "Passive Minor"
		"passive_notable":
			return "Passive Notable"
		"cluster_center":
			return "Cluster Center"
		_:
			return node_type.replace("_", " ").capitalize()


func _is_skill_node(node_data: Dictionary) -> bool:
	var node_type: String = str(node_data.get("type", "passive_minor"))
	return node_type == "active_unlock" or node_type == "active_upgrade"


func _is_node_unlocked(node_id: String) -> bool:
	for unlocked_variant in resolved_progression.get("valid_unlocked_node_ids", []):
		if str(unlocked_variant) == node_id:
			return true
	return false


func _is_node_unlockable(node_id: String) -> bool:
	for unlockable_variant in resolved_progression.get("unlockable_node_ids", []):
		if str(unlockable_variant) == node_id:
			return true
	return false


func _is_skill_family_unlocked(skill_family: String) -> bool:
	return (resolved_progression.get("active_skill_tiers", {}) as Dictionary).has(skill_family)


func _build_pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


func _get_button_center(node_id: String) -> Vector2:
	var button: Button = node_buttons.get(node_id, null)
	if button == null:
		return Vector2.ZERO
	return button.position + button.size * 0.5


func _get_connection_color(from_node_id: String, to_node_id: String) -> Color:
	if _is_node_unlocked(from_node_id) and _is_node_unlocked(to_node_id):
		return Color(0.92, 0.80, 0.46, 0.96)
	return Color(0.56, 0.58, 0.62, 0.72)


func _get_node_modulate(node_id: String) -> Color:
	return Color(1.0, 1.0, 1.0, 1.0)


func _build_region_positions(region: Dictionary, region_x: float, region_y_offset: float) -> Dictionary:
	var positions := {}
	var region_node_ids: Array = region.get("node_ids", [])
	var consumed := {}
	var region_cluster_ids: Array = region.get("cluster_ids", [])
	var cluster_index: int = 0

	for cluster_id_variant in region_cluster_ids:
		var cluster_data: Dictionary = _get_cluster_data(str(cluster_id_variant))
		if cluster_data.is_empty():
			continue
		var center_anchor: Vector2 = Vector2(region_x + _scaled(NODE_SIZE.x * 0.5 + 28.0), _scaled(TOP_PADDING + region_y_offset + float(cluster_index) * 250.0 + 98.0))
		var outer_nodes: Array = cluster_data.get("outer_node_ids", [])
		for outer_index in range(outer_nodes.size()):
			var node_id: String = str(outer_nodes[outer_index])
			consumed[node_id] = true
			var angle: float = (TAU / maxf(1.0, float(outer_nodes.size()))) * float(outer_index) - PI * 0.5
			var center_position: Vector2 = center_anchor + Vector2(cos(angle), sin(angle)) * _scaled(CLUSTER_RADIUS)
			var outer_size: Vector2 = _get_node_button_size(nodes.get(node_id, {}))
			positions[node_id] = center_position - outer_size * 0.5
		var center_node_id: String = str(cluster_data.get("center_node_id", ""))
		if not center_node_id.is_empty():
			consumed[center_node_id] = true
			var center_size: Vector2 = _get_node_button_size(nodes.get(center_node_id, {}))
			positions[center_node_id] = center_anchor + CLUSTER_CENTER_OFFSET * tree_zoom - center_size * 0.5
		cluster_index += 1

	var loose_index: int = 0
	var loose_start_y: float = _scaled(TOP_PADDING + region_y_offset + float(cluster_index) * 250.0 + 16.0)
	for node_variant in region_node_ids:
		var node_id: String = str(node_variant)
		if consumed.has(node_id):
			continue
		var pattern_offset: float = float(LOOSE_NODE_X_PATTERN[loose_index % LOOSE_NODE_X_PATTERN.size()])
		positions[node_id] = Vector2(region_x + _scaled(pattern_offset), loose_start_y + float(loose_index) * _scaled(NODE_ROW_GAP))
		loose_index += 1

	return positions


func _get_cluster_data(cluster_id: String) -> Dictionary:
	for cluster_data in clusters:
		if str(cluster_data.get("id", "")) == cluster_id:
			return cluster_data
	return {}


func _apply_button_theme(button: Button, node_id: String, node_data: Dictionary) -> void:
	var style := StyleBoxFlat.new()
	var radius: int = int(round(button.size.x * 0.5))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.border_width_left = 0
	style.border_width_top = style.border_width_left
	style.border_width_right = style.border_width_left
	style.border_width_bottom = style.border_width_left
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
	button.add_theme_color_override("icon_normal_color", Color.WHITE)
	button.add_theme_color_override("font_color", Color(0.97, 0.97, 0.95, 1.0))


func _get_region_label_position(class_id: String, region: Dictionary, region_x: float, region_y_offset: float) -> Vector2:
	if class_id == "rogue":
		var region_id: String = str(region.get("id", ""))
		var layout: Dictionary = RogueSkillTreeLayoutScript.get_layout()
		var label_positions: Dictionary = layout.get("region_label_positions", {})
		if label_positions.has(region_id):
			return (label_positions[region_id] as Vector2) * tree_zoom
	return Vector2(region_x - 24.0, _scaled(18.0 + region_y_offset))


func _apply_hand_authored_positions(class_id: String) -> void:
	current_layout_origin = Vector2.ZERO
	var layout_positions: Dictionary = _get_layout_positions_for_class(class_id)
	if layout_positions.is_empty():
		return
	var min_center := Vector2(INF, INF)
	for node_id in layout_positions.keys():
		var center_position: Vector2 = (layout_positions[node_id] as Vector2) * tree_zoom
		min_center.x = minf(min_center.x, center_position.x)
		min_center.y = minf(min_center.y, center_position.y)
	current_layout_origin = Vector2(
		maxf(0.0, _scaled(TREE_CANVAS_MARGIN.x) - min_center.x),
		maxf(0.0, _scaled(TREE_CANVAS_MARGIN.y) - min_center.y)
	)
	for node_id in layout_positions.keys():
		if not node_positions.has(node_id):
			continue
		var center_position: Vector2 = (layout_positions[node_id] as Vector2) * tree_zoom + current_layout_origin
		var node_size: Vector2 = _get_node_button_size(nodes.get(node_id, {}))
		node_positions[node_id] = center_position - node_size * 0.5


func _expand_canvas_for_layout_bounds(default_width: float, default_height: float) -> Vector2:
	if node_positions.is_empty():
		return Vector2(default_width, default_height)
	var max_extent := Vector2.ZERO
	for node_id in node_positions.keys():
		var node_position: Vector2 = node_positions[node_id] as Vector2
		var node_size: Vector2 = _get_node_button_size(nodes.get(node_id, {}))
		max_extent.x = maxf(max_extent.x, node_position.x + node_size.x + _scaled(TREE_CANVAS_MARGIN.x))
		max_extent.y = maxf(max_extent.y, node_position.y + node_size.y + _scaled(TREE_CANVAS_MARGIN.y))
	return Vector2(maxf(default_width, max_extent.x), maxf(default_height, max_extent.y))


func _get_region_y_offset(region_index: int) -> float:
	if region_index < REGION_Y_OFFSETS.size():
		return float(REGION_Y_OFFSETS[region_index])
	return float(region_index % 2) * 120.0 + float(region_index / 2) * 26.0


func _focus_selected_node() -> void:
	if selected_node_id.is_empty() or not node_buttons.has(selected_node_id):
		return
	var button: Button = node_buttons[selected_node_id]
	if button == null or tree_scroll == null:
		return
	var target_center: Vector2 = button.position + button.size * 0.5
	var visible_size: Vector2 = tree_scroll.size
	tree_pan_offset = target_center - visible_size * 0.5
	_clamp_tree_pan_offset()
	graph_canvas.position = -tree_pan_offset


func _zoom_tree_to(next_zoom: float, anchor_local: Vector2) -> void:
	var clamped_zoom: float = clampf(next_zoom, MIN_TREE_ZOOM, MAX_TREE_ZOOM)
	if is_equal_approx(clamped_zoom, tree_zoom):
		return
	var old_zoom: float = tree_zoom
	var world_anchor: Vector2 = (tree_pan_offset + anchor_local) / maxf(0.001, old_zoom)
	tree_zoom = clamped_zoom
	should_focus_selected = false
	_rebuild_graph()
	_refresh_view()
	call_deferred("_restore_zoom_anchor", world_anchor, anchor_local)


func _restore_zoom_anchor(world_anchor: Vector2, anchor_local: Vector2) -> void:
	tree_pan_offset = world_anchor * tree_zoom - anchor_local
	_clamp_tree_pan_offset()
	graph_canvas.position = -tree_pan_offset


func _pan_tree(delta: Vector2) -> void:
	tree_pan_offset -= delta
	_clamp_tree_pan_offset()
	graph_canvas.position = -tree_pan_offset


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_F2:
				layout_edit_mode = not layout_edit_mode
				dragged_layout_node_id = ""
				_update_layout_edit_header()
				get_viewport().set_input_as_handled()
				return
			if key_event.keycode == KEY_F3:
				_export_current_layout_positions()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if layout_edit_mode and mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				if not _is_point_inside_tree(mouse_button.position):
					return
				var drag_node_id: String = _get_node_id_at_screen_position(mouse_button.position)
				if not drag_node_id.is_empty():
					dragged_layout_node_id = drag_node_id
					var canvas_position: Vector2 = tree_pan_offset + (mouse_button.position - tree_scroll.get_global_position())
					dragged_layout_pointer_offset = canvas_position - (node_positions.get(drag_node_id, Vector2.ZERO) as Vector2)
					selected_node_id = drag_node_id
					popup_open = false
					info_popup.hide()
					_refresh_view()
					get_viewport().set_input_as_handled()
					return
			else:
				if not dragged_layout_node_id.is_empty():
					dragged_layout_node_id = ""
					get_viewport().set_input_as_handled()
					return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed and popup_open and not info_popup.get_global_rect().has_point(mouse_button.position):
			var clicked_node_id: String = _get_node_id_at_screen_position(mouse_button.position) if _is_point_inside_tree(mouse_button.position) else ""
			if clicked_node_id.is_empty():
				popup_open = false
				info_popup.hide()
				if not _is_point_inside_tree(mouse_button.position):
					return
		if not _is_point_inside_tree(mouse_button.position):
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_zoom_tree_to(tree_zoom + TREE_ZOOM_STEP, mouse_button.position)
			get_viewport().set_input_as_handled()
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_zoom_tree_to(tree_zoom - TREE_ZOOM_STEP, mouse_button.position)
			get_viewport().set_input_as_handled()
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			is_mouse_panning = mouse_button.pressed
			mouse_pan_button = MOUSE_BUTTON_LEFT if mouse_button.pressed else MOUSE_BUTTON_NONE
			mouse_pan_last_position = mouse_button.position
			if mouse_button.pressed:
				mouse_pan_total_distance = 0.0
				pending_node_click_id = _get_node_id_at_screen_position(mouse_button.position)
			else:
				var release_node_id: String = _get_node_id_at_screen_position(mouse_button.position)
				var should_select: bool = pending_node_click_id == release_node_id and mouse_pan_total_distance <= MOUSE_DRAG_THRESHOLD
				mouse_pan_total_distance = 0.0
				pending_node_click_id = ""
				if should_select and not release_node_id.is_empty():
					_on_graph_node_pressed(release_node_id)
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event
		if layout_edit_mode and not dragged_layout_node_id.is_empty():
			var canvas_position: Vector2 = tree_pan_offset + (mouse_motion.position - tree_scroll.get_global_position())
			_set_node_top_left_position(dragged_layout_node_id, canvas_position - dragged_layout_pointer_offset)
			get_viewport().set_input_as_handled()
			return
		if is_mouse_panning and mouse_pan_button == MOUSE_BUTTON_LEFT:
			var delta: Vector2 = mouse_motion.position - mouse_pan_last_position
			mouse_pan_total_distance += delta.length()
			_pan_tree(delta)
			mouse_pan_last_position = mouse_motion.position
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if not _is_point_inside_tree(touch_event.position):
			return
		if touch_event.pressed:
			touch_points[touch_event.index] = touch_event.position
			if touch_points.size() == 2:
				last_pinch_distance = _get_touch_distance()
		else:
			touch_points.erase(touch_event.index)
			if touch_points.size() < 2:
				last_pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event
		if not _is_point_inside_tree(drag_event.position):
			return
		touch_points[drag_event.index] = drag_event.position
		if touch_points.size() >= 2:
			var pinch_distance: float = _get_touch_distance()
			if last_pinch_distance > 0.0 and not is_zero_approx(pinch_distance):
				var zoom_delta: float = pinch_distance / last_pinch_distance
				if absf(zoom_delta - 1.0) > 0.015:
					_zoom_tree_to(tree_zoom * zoom_delta, _get_touch_center())
			last_pinch_distance = pinch_distance
		else:
			_pan_tree(drag_event.relative)
		get_viewport().set_input_as_handled()


func _update_popup_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var popup_width: float = minf(340.0, viewport_size.x * 0.30)
	var popup_height: float = minf(300.0, viewport_size.y - 120.0)
	var anchor_position: Vector2 = viewport_size * 0.5
	if not selected_node_id.is_empty() and node_buttons.has(selected_node_id):
		var button: Button = node_buttons[selected_node_id]
		anchor_position = tree_scroll.get_global_position() + graph_canvas.position + button.position + button.size * 0.5
	var popup_left: float = anchor_position.x + 28.0
	if popup_left + popup_width > viewport_size.x - POPUP_MARGIN:
		popup_left = anchor_position.x - popup_width - 28.0
	popup_left = clampf(popup_left, POPUP_MARGIN, viewport_size.x - popup_width - POPUP_MARGIN)
	var popup_top: float = clampf(anchor_position.y - popup_height * 0.25, 70.0, viewport_size.y - popup_height - POPUP_MARGIN)
	info_popup.offset_left = popup_left
	info_popup.offset_top = popup_top
	info_popup.offset_right = popup_left + popup_width
	info_popup.offset_bottom = popup_top + popup_height


func _get_touch_distance() -> float:
	if touch_points.size() < 2:
		return 0.0
	var positions: Array = touch_points.values()
	return (positions[0] as Vector2).distance_to(positions[1] as Vector2)


func _get_touch_center() -> Vector2:
	if touch_points.is_empty():
		return tree_scroll.size * 0.5
	var total := Vector2.ZERO
	for point in touch_points.values():
		total += point as Vector2
	return total / float(touch_points.size())


func _scaled(value: float) -> float:
	return value * tree_zoom


func _get_node_button_size(node_data: Dictionary) -> Vector2:
	var node_type: String = str(node_data.get("type", "passive_minor"))
	var base_size: float = NODE_SIZE.x
	if node_type == "start":
		base_size = 42.0
	elif node_type == "cluster_center":
		base_size = 28.0
	elif node_type == "keystone":
		base_size = 26.0
	elif node_type == "active_unlock" or node_type == "active_upgrade":
		base_size = 32.0
	elif node_type == "passive_notable":
		base_size = 20.0
	else:
		base_size = 16.0
	return Vector2(_scaled(base_size), _scaled(base_size))


func _add_node_label(node_id: String, node_data: Dictionary, button: Button) -> void:
	var label_text: String = _get_tree_label_text(node_id, node_data)
	if label_text.is_empty():
		return
	var name_label := Label.new()
	var is_skill: bool = _is_skill_node(node_data)
	name_label.text = label_text
	name_label.position = Vector2(
		button.position.x - (_scaled(NODE_LABEL_SIZE.x) - button.size.x) * 0.5,
		button.position.y + button.size.y + _scaled(6.0)
	)
	name_label.size = NODE_LABEL_SIZE * tree_zoom
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", int(round(_scaled(9.0 if is_skill else 8.2))))
	if is_skill:
		name_label.modulate = Color(0.99, 0.93, 0.74, 0.99) if node_id == selected_node_id else Color(0.92, 0.86, 0.70, 0.98)
	else:
		name_label.modulate = Color(0.96, 0.95, 0.92, 0.98) if node_id == selected_node_id else Color(0.86, 0.88, 0.86, 0.92)
	graph_canvas.add_child(name_label)
	node_labels[node_id] = name_label


func _get_tree_label_text(node_id: String, node_data: Dictionary) -> String:
	var node_type: String = str(node_data.get("type", "passive_minor"))
	if _is_skill_node(node_data):
		return str(node_data.get("name", node_id))
	if node_type == "passive_minor":
		return ""
	return str(node_data.get("name", node_id))


func _is_point_inside_tree(screen_position: Vector2) -> bool:
	return tree_scroll.get_global_rect().has_point(screen_position)


func _get_node_id_at_screen_position(screen_position: Vector2) -> String:
	var local_in_scroll: Vector2 = screen_position - tree_scroll.get_global_position()
	var canvas_position: Vector2 = tree_pan_offset + local_in_scroll
	for node_id in node_buttons.keys():
		var button: Button = node_buttons[node_id]
		if button == null:
			continue
		var rect := Rect2(button.position, button.size)
		if rect.has_point(canvas_position):
			return str(node_id)
	return ""


func _clamp_tree_pan_offset() -> void:
	var max_horizontal: float = maxf(0.0, graph_canvas.custom_minimum_size.x - tree_scroll.size.x)
	var max_vertical: float = maxf(0.0, graph_canvas.custom_minimum_size.y - tree_scroll.size.y)
	tree_pan_offset.x = clampf(tree_pan_offset.x, 0.0, max_horizontal)
	tree_pan_offset.y = clampf(tree_pan_offset.y, 0.0, max_vertical)


func _set_node_top_left_position(node_id: String, next_position: Vector2) -> void:
	if not node_buttons.has(node_id):
		return
	var button: Button = node_buttons[node_id]
	var node_data: Dictionary = nodes.get(node_id, {})
	var node_size: Vector2 = _get_node_button_size(node_data)
	var clamped_position := next_position
	clamped_position.x = clampf(clamped_position.x, 0.0, maxf(0.0, graph_canvas.custom_minimum_size.x - node_size.x))
	clamped_position.y = clampf(clamped_position.y, 0.0, maxf(0.0, graph_canvas.custom_minimum_size.y - node_size.y))
	node_positions[node_id] = clamped_position
	button.position = clamped_position
	_store_runtime_layout_position(node_id, clamped_position)

	var outer: Panel = node_outer_rings.get(node_id, null)
	if outer != null:
		outer.position = clamped_position

	var inner: Panel = node_inner_cores.get(node_id, null)
	if inner != null:
		var inner_size: Vector2 = button.size * 0.52
		inner.position = clamped_position + (button.size - inner_size) * 0.5
		inner.size = inner_size

	var label: Label = node_labels.get(node_id, null)
	if label != null:
		label.position = Vector2(
			clamped_position.x - (_scaled(NODE_LABEL_SIZE.x) - button.size.x) * 0.5,
			clamped_position.y + button.size.y + _scaled(6.0)
		)

	_refresh_connection_lines()


func _get_layout_positions_for_class(class_id: String) -> Dictionary:
	var normalized_class_id: String = str(class_id).to_lower()
	if runtime_layout_overrides.has(normalized_class_id):
		return (runtime_layout_overrides[normalized_class_id] as Dictionary).duplicate(true)
	if normalized_class_id == "rogue":
		var layout: Dictionary = RogueSkillTreeLayoutScript.get_layout()
		return (layout.get("node_positions", {}) as Dictionary).duplicate(true)
	return {}


func _store_runtime_layout_position(node_id: String, top_left_position: Vector2) -> void:
	var class_id: String = str(resolved_progression.get("class_id", progression_state.get("class_id", "rogue"))).to_lower()
	var node_data: Dictionary = nodes.get(node_id, {})
	var node_size: Vector2 = _get_node_button_size(node_data)
	var center_position: Vector2 = top_left_position + node_size * 0.5 - current_layout_origin
	if not runtime_layout_overrides.has(class_id):
		runtime_layout_overrides[class_id] = _get_layout_positions_for_class(class_id)
	var class_layout: Dictionary = runtime_layout_overrides[class_id]
	class_layout[node_id] = center_position / maxf(0.001, tree_zoom)
	runtime_layout_overrides[class_id] = class_layout


func _update_layout_edit_header() -> void:
	var class_id: String = str(resolved_progression.get("class_id", progression_state.get("class_id", "rogue")))
	class_label.text = "%s Skills%s" % [
		class_id.capitalize(),
		"  [Layout Edit]" if layout_edit_mode else ""
	]


func _export_current_layout_positions() -> void:
	var class_key: String = str(resolved_progression.get("class_id", progression_state.get("class_id", "rogue"))).to_upper()
	var lines: Array[String] = ["const %s_HAND_TUNED_POSITIONS := {" % class_key]
	var sorted_node_ids: Array[String] = []
	for node_id_variant in node_positions.keys():
		sorted_node_ids.append(str(node_id_variant))
	sorted_node_ids.sort()
	for node_id in sorted_node_ids:
		var node_data: Dictionary = nodes.get(node_id, {})
		var node_size: Vector2 = _get_node_button_size(node_data)
		var center_position: Vector2 = (node_positions[node_id] as Vector2) + node_size * 0.5 - current_layout_origin
		lines.append('\t"%s": Vector2(%.1f, %.1f),' % [
			node_id,
			center_position.x / maxf(0.001, tree_zoom),
			center_position.y / maxf(0.001, tree_zoom)
		])
	lines.append("}")
	var export_text: String = "\n".join(lines)
	DisplayServer.clipboard_set(export_text)
	print(export_text)


func _add_connection_line(from_node_id: String, to_node_id: String) -> void:
	var from_center: Vector2 = _get_button_center(from_node_id)
	var to_center: Vector2 = _get_button_center(to_node_id)
	var from_point: Vector2 = _get_node_ring_anchor_point(from_node_id, to_center)
	var to_point: Vector2 = _get_node_ring_anchor_point(to_node_id, from_center)
	var both_unlocked: bool = _is_node_unlocked(from_node_id) and _is_node_unlocked(to_node_id)
	if both_unlocked:
		var glow_line := Line2D.new()
		glow_line.width = maxf(5.0, _scaled(6.0))
		glow_line.default_color = Color(0.93, 0.80, 0.45, 0.26)
		glow_line.z_index = -2
		glow_line.add_point(from_point)
		glow_line.add_point(to_point)
		graph_canvas.add_child(glow_line)
		connection_lines.append(glow_line)

	var line := Line2D.new()
	line.width = maxf(2.0, _scaled(2.4))
	line.default_color = _get_connection_color(from_node_id, to_node_id)
	line.z_index = 0
	line.add_point(from_point)
	line.add_point(to_point)
	graph_canvas.add_child(line)
	connection_lines.append(line)


func _get_node_ring_anchor_point(node_id: String, target_point: Vector2) -> Vector2:
	var button: Button = node_buttons.get(node_id, null)
	if button == null:
		return target_point
	var center: Vector2 = button.position + button.size * 0.5
	var direction: Vector2 = target_point - center
	if direction.length_squared() <= 0.0001:
		return center
	var ring_radius: float = minf(button.size.x, button.size.y) * 0.5
	return center + direction.normalized() * ring_radius


func _add_socket_visual(node_id: String, node_data: Dictionary, button: Button) -> void:
	var outer := Panel.new()
	outer.position = button.position
	outer.size = button.size
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_canvas.add_child(outer)
	node_outer_rings[node_id] = outer

	var inner := Panel.new()
	var inner_size: Vector2 = button.size * 0.52
	inner.position = button.position + (button.size - inner_size) * 0.5
	inner.size = inner_size
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_canvas.add_child(inner)
	node_inner_cores[node_id] = inner

	_apply_socket_visual(node_id, node_data)


func _apply_socket_visual(node_id: String, node_data: Dictionary) -> void:
	var outer: Panel = node_outer_rings.get(node_id, null)
	var inner: Panel = node_inner_cores.get(node_id, null)
	if outer == null or inner == null:
		return

	var outer_style := StyleBoxFlat.new()
	var outer_radius: int = int(round(outer.size.x * 0.5))
	outer_style.corner_radius_top_left = outer_radius
	outer_style.corner_radius_top_right = outer_radius
	outer_style.corner_radius_bottom_right = outer_radius
	outer_style.corner_radius_bottom_left = outer_radius
	outer_style.border_width_left = max(2, int(round(outer.size.x * 0.07)))
	outer_style.border_width_top = outer_style.border_width_left
	outer_style.border_width_right = outer_style.border_width_left
	outer_style.border_width_bottom = outer_style.border_width_left
	outer_style.bg_color = Color(0.11, 0.12, 0.13, 0.72)
	outer_style.border_color = Color(0.55, 0.57, 0.60, 0.96)

	var inner_style := StyleBoxFlat.new()
	var inner_radius: int = int(round(inner.size.x * 0.5))
	inner_style.corner_radius_top_left = inner_radius
	inner_style.corner_radius_top_right = inner_radius
	inner_style.corner_radius_bottom_right = inner_radius
	inner_style.corner_radius_bottom_left = inner_radius
	inner_style.bg_color = Color(0.12, 0.13, 0.14, 0.92)

	var node_type: String = str(node_data.get("type", "passive_minor"))
	var is_skill_node: bool = _is_skill_node(node_data)
	if is_skill_node:
		outer_style.border_width_left = max(2, int(round(outer.size.x * 0.09)))
		outer_style.border_width_top = outer_style.border_width_left
		outer_style.border_width_right = outer_style.border_width_left
		outer_style.border_width_bottom = outer_style.border_width_left
		outer_style.border_color = Color(0.72, 0.70, 0.62, 0.98)
		var accent_size: float = inner.size.x * 0.36
		inner.size = Vector2(accent_size, accent_size)
		inner.position = outer.position + (outer.size - inner.size) * 0.5
		inner_style.bg_color = Color(0.28, 0.30, 0.32, 0.96)
	elif node_type == "passive_minor":
		outer_style.border_color = Color(0.52, 0.54, 0.58, 0.92)
	elif node_type == "passive_notable":
		outer_style.border_color = Color(0.58, 0.72, 0.96, 0.98)
		outer_style.shadow_color = Color(0.42, 0.62, 0.95, 0.22)
		outer_style.shadow_size = max(4, int(round(outer.size.x * 0.12)))
		inner_style.bg_color = Color(0.18, 0.24, 0.34, 0.94)
	elif node_type == "keystone":
		outer_style.border_width_left = max(2, int(round(outer.size.x * 0.10)))
		outer_style.border_width_top = outer_style.border_width_left
		outer_style.border_width_right = outer_style.border_width_left
		outer_style.border_width_bottom = outer_style.border_width_left
		outer_style.border_color = Color(0.88, 0.74, 0.52, 0.98)
		outer_style.shadow_color = Color(0.86, 0.58, 0.22, 0.26)
		outer_style.shadow_size = max(5, int(round(outer.size.x * 0.14)))
		inner_style.bg_color = Color(0.24, 0.18, 0.12, 0.95)
	elif node_type == "cluster_center":
		outer_style.border_width_left = max(2, int(round(outer.size.x * 0.10)))
		outer_style.border_width_top = outer_style.border_width_left
		outer_style.border_width_right = outer_style.border_width_left
		outer_style.border_width_bottom = outer_style.border_width_left
		outer_style.border_color = Color(0.66, 0.82, 0.72, 0.98)
		outer_style.shadow_color = Color(0.48, 0.78, 0.62, 0.22)
		outer_style.shadow_size = max(5, int(round(outer.size.x * 0.14)))
		inner_style.bg_color = Color(0.16, 0.22, 0.18, 0.95)

	if _is_node_unlockable(node_id):
		outer_style.border_color = Color(0.88, 0.90, 0.94, 1.0)
		outer_style.shadow_color = Color(0.90, 0.92, 0.96, 0.22)
		outer_style.shadow_size = max(5, int(round(outer.size.x * 0.14)))
		inner_style.bg_color = Color(0.72, 0.75, 0.80, 0.34)
		if is_skill_node:
			outer_style.border_color = Color(0.93, 0.88, 0.74, 1.0)
			outer_style.shadow_color = Color(0.94, 0.86, 0.66, 0.24)
			inner_style.bg_color = Color(0.86, 0.80, 0.64, 0.38)
		elif node_type == "passive_notable":
			outer_style.border_color = Color(0.76, 0.86, 1.0, 1.0)
			outer_style.shadow_color = Color(0.54, 0.74, 0.98, 0.28)
			inner_style.bg_color = Color(0.64, 0.76, 0.96, 0.32)
		elif node_type == "keystone":
			outer_style.border_color = Color(0.96, 0.82, 0.60, 1.0)
			outer_style.shadow_color = Color(0.96, 0.72, 0.34, 0.28)
			inner_style.bg_color = Color(0.66, 0.48, 0.28, 0.32)
		elif node_type == "cluster_center":
			outer_style.border_color = Color(0.78, 0.92, 0.84, 1.0)
			outer_style.shadow_color = Color(0.56, 0.86, 0.72, 0.28)
			inner_style.bg_color = Color(0.62, 0.86, 0.74, 0.30)
	elif _is_node_unlocked(node_id):
		if not _is_starter_node(node_id):
			outer_style.border_color = Color(1.0, 0.91, 0.60, 1.0)
			outer_style.shadow_color = Color(0.97, 0.84, 0.40, 0.36)
			outer_style.shadow_size = max(6, int(round(outer.size.x * 0.16)))
		else:
			outer_style.border_color = Color(0.92, 0.83, 0.52, 0.98)
			outer_style.shadow_color = Color(0.97, 0.84, 0.40, 0.24)
			outer_style.shadow_size = max(4, int(round(outer.size.x * 0.10)))
		inner_style.bg_color = Color(0.93, 0.84, 0.46, 0.96)

	if node_id == selected_node_id:
		outer_style.border_color = outer_style.border_color.lerp(Color(1.0, 0.97, 0.88, 1.0), 0.45)
		outer_style.shadow_color = outer_style.shadow_color.lerp(Color(1.0, 0.95, 0.78, 0.40), 0.40)
		outer_style.shadow_size = max(outer_style.shadow_size, max(6, int(round(outer.size.x * 0.15))))

	outer.add_theme_stylebox_override("panel", outer_style)
	inner.add_theme_stylebox_override("panel", inner_style)


func _is_starter_node(node_id: String) -> bool:
	var class_id: String = str(progression_state.get("class_id", resolved_progression.get("class_id", "rogue")))
	return ClassProgressionStateScript.get_starting_node_ids(class_id).has(node_id)


func _add_region_cluster_visuals(region: Dictionary) -> void:
	for cluster_id_variant in region.get("cluster_ids", []):
		var cluster_data: Dictionary = _get_cluster_data(str(cluster_id_variant))
		if cluster_data.is_empty():
			continue
		var center_node_id: String = str(cluster_data.get("center_node_id", ""))
		if center_node_id.is_empty() or not node_positions.has(center_node_id):
			continue

		var center_position: Vector2 = (node_positions[center_node_id] as Vector2) + _get_node_button_size(nodes.get(center_node_id, {})) * 0.5
		var ring_radius: float = _scaled(CLUSTER_RADIUS + 8.0)
		var ring := Line2D.new()
		ring.width = maxf(1.0, _scaled(1.3))
		ring.default_color = Color(0.62, 0.68, 0.54, 0.32)
		ring.z_index = -3
		for step in range(25):
			var angle: float = TAU * float(step) / 24.0 - PI * 0.5
			ring.add_point(center_position + Vector2(cos(angle), sin(angle)) * ring_radius)
		graph_canvas.add_child(ring)

		var halo := Line2D.new()
		halo.width = maxf(2.0, _scaled(2.2))
		halo.default_color = Color(0.66, 0.82, 0.72, 0.18)
		halo.z_index = -4
		for step in range(33):
			var halo_angle: float = TAU * float(step) / 32.0 - PI * 0.5
			halo.add_point(center_position + Vector2(cos(halo_angle), sin(halo_angle)) * (ring_radius + _scaled(10.0)))
		graph_canvas.add_child(halo)

		for outer_node_variant in cluster_data.get("outer_node_ids", []):
			var outer_id: String = str(outer_node_variant)
			if not node_positions.has(outer_id):
				continue
			var spoke := Line2D.new()
			spoke.width = maxf(0.8, _scaled(1.0))
			spoke.default_color = Color(0.56, 0.62, 0.50, 0.22)
			spoke.z_index = -3
			var outer_center: Vector2 = (node_positions[outer_id] as Vector2) + _get_node_button_size(nodes.get(outer_id, {})) * 0.5
			spoke.add_point(center_position)
			spoke.add_point(outer_center)
			graph_canvas.add_child(spoke)
