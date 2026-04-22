extends Control

const WIDGET_SIZE := Vector2(204, 204)
const MAP_DIAMETER := 156.0
const MAP_RADIUS := MAP_DIAMETER * 0.5
const MAP_CENTER := Vector2(86.0, 98.0)
const FULL_MAP_SIDE_MARGIN := 22.0
const FULL_MAP_TOP_MARGIN := 70.0
const FULL_MAP_BOTTOM_MARGIN := 22.0
const FULL_MAP_HEADER_HEIGHT := 34.0
const FULL_MAP_MARGIN := 24.0
const ZOOM_LEVELS := [14, 20, 28, 36, 44]
const DEFAULT_ZOOM_INDEX := 2

const PANEL_SHADOW := Color(0.0, 0.0, 0.0, 0.24)
const PANEL_FILL := Color(0.04, 0.05, 0.06, 0.86)
const PANEL_RING := Color(0.86, 0.77, 0.54, 0.24)
const PANEL_RING_HIGHLIGHT := Color(0.95, 0.90, 0.74, 0.08)
const MAP_BACKGROUND := Color(0.02, 0.025, 0.03, 0.94)
const EXPLORED_COLOR := Color(0.82, 0.74, 0.58, 0.98)
const PLAYER_COLOR := Color(0.97, 0.92, 0.80, 1.0)
const PLAYER_RING := Color(0.41, 0.25, 0.11, 0.96)
const STAIRS_UP_COLOR := Color(0.72, 0.78, 0.62, 1.0)
const STAIRS_DOWN_COLOR := Color(0.84, 0.56, 0.27, 1.0)
const BUTTON_FILL := Color(0.10, 0.12, 0.12, 0.95)
const BUTTON_RING := Color(0.94, 0.88, 0.72, 0.18)
const FULL_MAP_FILL := Color(0.03, 0.035, 0.04, 0.94)
const FULL_MAP_RING := Color(0.94, 0.88, 0.72, 0.18)
const FULL_MAP_SHADOW := Color(0.0, 0.0, 0.0, 0.32)
const FULL_MAP_CELL_SHADOW := Color(0.0, 0.0, 0.0, 0.12)
const FULL_MAP_PADDING := 3
const REVEAL_FADE_SPEED := 7.5
const PLAYER_TRACK_LERP := 10.0
const MINIMAP_EDGE_FADE := 10.0

var map_enabled: bool = false
var grid_size: Vector2i = Vector2i.ONE
var floor_cells: Array[Vector2i] = []
var explored_floor: Dictionary = {}
var visible_floor: Dictionary = {}
var player_cell: Vector2i = Vector2i(-1, -1)
var player_map_position: Vector2 = Vector2(-1.0, -1.0)
var stairs_up_cell: Vector2i = Vector2i(-1, -1)
var stairs_down_cell: Vector2i = Vector2i(-1, -1)
var depth_value: int = 1
var zoom_index: int = DEFAULT_ZOOM_INDEX
var is_expanded: bool = false
var reveal_progress: Dictionary = {}
var display_player_map_position: Vector2 = Vector2(-1.0, -1.0)

var title_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_create_ui()
	_apply_layout()
	set_process(true)


func set_map_state(map_data: Dictionary) -> void:
	map_enabled = bool(map_data.get("enabled", false))
	visible = map_enabled
	if not map_enabled:
		is_expanded = false
		reveal_progress.clear()
		display_player_map_position = Vector2(-1.0, -1.0)
		_apply_layout()
		return

	grid_size = _normalize_cell(map_data.get("grid_size", Vector2i.ONE))
	floor_cells = _normalize_cells(map_data.get("floor_cells", []))
	var previous_explored: Dictionary = explored_floor.duplicate()
	explored_floor = _cell_array_to_map(map_data.get("explored_cells", []))
	visible_floor = _cell_array_to_map(map_data.get("visible_cells", []))
	player_cell = _normalize_cell(map_data.get("player_cell", Vector2i(-1, -1)))
	player_map_position = _normalize_map_position(map_data.get("player_map_position", Vector2(player_cell)))
	if display_player_map_position.x < 0.0:
		display_player_map_position = player_map_position
	stairs_up_cell = _normalize_cell(map_data.get("stairs_up_cell", Vector2i(-1, -1)))
	stairs_down_cell = _normalize_cell(map_data.get("stairs_down_cell", Vector2i(-1, -1)))
	depth_value = int(map_data.get("depth", depth_value))
	_sync_reveal_progress(previous_explored)
	_apply_layout()
	queue_redraw()


func _process(delta: float) -> void:
	if not map_enabled:
		return
	var changed: bool = false
	if player_map_position.x >= 0.0:
		var next_display_position: Vector2 = display_player_map_position
		if next_display_position.x < 0.0:
			next_display_position = player_map_position
		else:
			next_display_position = next_display_position.lerp(player_map_position, clampf(delta * PLAYER_TRACK_LERP, 0.0, 1.0))
		if next_display_position.distance_squared_to(display_player_map_position) > 0.0001:
			display_player_map_position = next_display_position
			changed = true
	for cell_key_variant in reveal_progress.keys():
		var cell_key: String = str(cell_key_variant)
		var next_value: float = minf(1.0, float(reveal_progress[cell_key]) + delta * REVEAL_FADE_SPEED)
		if next_value != float(reveal_progress[cell_key]):
			reveal_progress[cell_key] = next_value
			changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	if not map_enabled:
		return

	if is_expanded:
		_draw_full_map()
	else:
		_draw_minimap()


func _draw_minimap() -> void:
	draw_circle(MAP_CENTER + Vector2(4.0, 6.0), MAP_RADIUS + 8.0, PANEL_SHADOW)
	draw_circle(MAP_CENTER, MAP_RADIUS + 10.0, PANEL_FILL)
	draw_arc(MAP_CENTER, MAP_RADIUS + 9.0, 0.0, TAU, 72, PANEL_RING, 2.0)
	draw_arc(MAP_CENTER, MAP_RADIUS + 5.0, 0.0, TAU, 72, PANEL_RING_HIGHLIGHT, 1.0)
	draw_circle(MAP_CENTER, MAP_RADIUS, MAP_BACKGROUND)
	draw_arc(MAP_CENTER, MAP_RADIUS - 5.0, 0.0, TAU, 72, Color(0.0, 0.0, 0.0, 0.22), 10.0)

	if grid_size.x <= 0 or grid_size.y <= 0 or display_player_map_position.x < 0.0 or display_player_map_position.y < 0.0:
		return

	var span: int = int(ZOOM_LEVELS[zoom_index])
	var view_origin_cells: Vector2 = _get_follow_view_origin(span)
	var cell_size: float = MAP_DIAMETER / float(span)
	var fill_size: float = cell_size + minf(1.6, cell_size * 0.18)
	var fill_offset: float = (fill_size - cell_size) * 0.5
	var view_origin: Vector2 = MAP_CENTER - Vector2(MAP_RADIUS, MAP_RADIUS)

	for cell in floor_cells:
		if not _is_cell_in_follow_view(cell, view_origin_cells, span):
			continue
		var cell_key: String = _cell_key(cell)
		if not explored_floor.has(cell_key):
			continue

		var local_position := Vector2(float(cell.x), float(cell.y)) - view_origin_cells
		var cell_center := view_origin + (local_position + Vector2(0.5, 0.5)) * cell_size
		var edge_alpha: float = _get_minimap_edge_alpha(cell_center, cell_size * 0.7)
		if edge_alpha <= 0.0:
			continue

		var rect := Rect2(
			view_origin + local_position * cell_size + Vector2(-fill_offset, -fill_offset),
			Vector2(fill_size, fill_size)
		)
		var cell_color := _get_cell_draw_color(cell_key, EXPLORED_COLOR)
		cell_color.a *= edge_alpha
		draw_rect(rect, cell_color, true)

	_draw_marker(view_origin, cell_size, view_origin_cells, span, stairs_up_cell, STAIRS_UP_COLOR)
	_draw_marker(view_origin, cell_size, view_origin_cells, span, stairs_down_cell, STAIRS_DOWN_COLOR)
	_draw_player(view_origin, cell_size, view_origin_cells, span)


func _draw_full_map() -> void:
	var panel_rect := Rect2(
		Vector2(FULL_MAP_SIDE_MARGIN, FULL_MAP_TOP_MARGIN),
		Vector2(
			maxf(0.0, size.x - FULL_MAP_SIDE_MARGIN * 2.0),
			maxf(0.0, size.y - FULL_MAP_TOP_MARGIN - FULL_MAP_BOTTOM_MARGIN)
		)
	)
	if panel_rect.size.x <= 0.0 or panel_rect.size.y <= 0.0:
		return

	draw_rect(Rect2(panel_rect.position + Vector2(8.0, 10.0), panel_rect.size), FULL_MAP_SHADOW, true)
	draw_rect(panel_rect, FULL_MAP_FILL, true)
	draw_rect(panel_rect, FULL_MAP_RING, false, 2.0)

	if explored_floor.is_empty():
		return

	var bounds: Rect2i = _expand_bounds(_make_bounds_from_keys(explored_floor.keys()), FULL_MAP_PADDING)
	var clamped_bounds: Rect2i = _clamp_rect_to_grid(bounds)
	var inner_rect := Rect2(
		panel_rect.position + Vector2(FULL_MAP_MARGIN, FULL_MAP_HEADER_HEIGHT + FULL_MAP_MARGIN * 0.5),
		Vector2(
			maxf(0.0, panel_rect.size.x - FULL_MAP_MARGIN * 2.0),
			maxf(0.0, panel_rect.size.y - FULL_MAP_HEADER_HEIGHT - FULL_MAP_MARGIN * 1.5)
		)
	)
	if inner_rect.size.x <= 0.0 or inner_rect.size.y <= 0.0:
		return
	var cell_size: float = minf(inner_rect.size.x / float(clamped_bounds.size.x), inner_rect.size.y / float(clamped_bounds.size.y))
	var draw_size := Vector2(float(clamped_bounds.size.x), float(clamped_bounds.size.y)) * cell_size
	var origin := inner_rect.position + (inner_rect.size - draw_size) * 0.5
	var fill_size: float = cell_size + minf(1.2, cell_size * 0.14)
	var fill_offset: float = (fill_size - cell_size) * 0.5

	for cell_key_variant in explored_floor.keys():
		var cell := _cell_from_key(str(cell_key_variant))
		if not clamped_bounds.has_point(cell):
			continue
		var local_position := Vector2(float(cell.x - clamped_bounds.position.x), float(cell.y - clamped_bounds.position.y))
		var rect := Rect2(
			origin + local_position * cell_size + Vector2(-fill_offset, -fill_offset),
			Vector2(fill_size, fill_size)
		)
		draw_rect(rect.grow(0.2), FULL_MAP_CELL_SHADOW, true)
		draw_rect(rect, _get_cell_draw_color(str(cell_key_variant), EXPLORED_COLOR), true)

	for cell_key_variant in visible_floor.keys():
		var visible_cell := _cell_from_key(str(cell_key_variant))
		if not clamped_bounds.has_point(visible_cell):
			continue
		var local_position := Vector2(float(visible_cell.x - clamped_bounds.position.x), float(visible_cell.y - clamped_bounds.position.y))
		var rect := Rect2(
			origin + local_position * cell_size + Vector2(-fill_offset, -fill_offset),
			Vector2(fill_size, fill_size)
		)
		draw_rect(rect, _get_cell_draw_color(str(cell_key_variant), Color(0.94, 0.87, 0.70, 1.0)), true)

	_draw_full_map_marker(origin, cell_size, clamped_bounds, stairs_up_cell, STAIRS_UP_COLOR)
	_draw_full_map_marker(origin, cell_size, clamped_bounds, stairs_down_cell, STAIRS_DOWN_COLOR)
	if display_player_map_position.x >= 0.0:
		var local_player := display_player_map_position - Vector2(clamped_bounds.position)
		var center := origin + (local_player + Vector2(0.5, 0.5)) * cell_size
		draw_circle(center, maxf(3.4, cell_size * 0.32), PLAYER_COLOR)
		draw_circle(center, maxf(1.0, cell_size * 0.12), PLAYER_RING)


func _create_ui() -> void:
	title_label = Label.new()
	title_label.visible = false
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75, 0.96))
	add_child(title_label)

func _apply_layout() -> void:
	if is_expanded:
		anchor_left = 0.0
		anchor_top = 0.0
		anchor_right = 1.0
		anchor_bottom = 1.0
		offset_left = 0.0
		offset_top = 0.0
		offset_right = 0.0
		offset_bottom = 0.0
		custom_minimum_size = Vector2.ZERO
	else:
		anchor_left = 1.0
		anchor_top = 0.0
		anchor_right = 1.0
		anchor_bottom = 0.0
		offset_left = -WIDGET_SIZE.x + 8.0
		offset_top = 54.0
		offset_right = 8.0
		offset_bottom = 54.0 + WIDGET_SIZE.y
		custom_minimum_size = WIDGET_SIZE
	size = get_viewport_rect().size if is_expanded else custom_minimum_size

	if title_label != null:
		title_label.visible = is_expanded
		title_label.text = "Dungeon Depth %d" % depth_value
		title_label.position = Vector2(FULL_MAP_SIDE_MARGIN, 18.0)
		title_label.size = Vector2(maxf(0.0, size.x - FULL_MAP_SIDE_MARGIN * 2.0), 34.0)


func _draw_marker(view_origin: Vector2, cell_size: float, view_origin_cells: Vector2, span: int, cell: Vector2i, color: Color) -> void:
	if cell.x < 0 or cell.y < 0 or not _is_cell_in_follow_view(cell, view_origin_cells, span):
		return
	var cell_key: String = _cell_key(cell)
	if not explored_floor.has(cell_key):
		return

	var local_position := Vector2(float(cell.x), float(cell.y)) - view_origin_cells
	var center := view_origin + (local_position + Vector2(0.5, 0.5)) * cell_size
	var edge_alpha: float = _get_minimap_edge_alpha(center, cell_size * 0.55)
	if edge_alpha <= 0.0:
		return

	var radius: float = maxf(2.3, cell_size * 0.24)
	var shadow_color := Color(0.0, 0.0, 0.0, 0.24 * edge_alpha)
	var marker_color := Color(color.r, color.g, color.b, color.a * edge_alpha)
	draw_circle(center + Vector2(0.0, 0.8), radius + 1.2, shadow_color)
	draw_circle(center, radius, marker_color)


func _draw_player(view_origin: Vector2, cell_size: float, view_origin_cells: Vector2, span: int) -> void:
	if display_player_map_position.x < 0.0 or display_player_map_position.y < 0.0:
		return

	var local_position := display_player_map_position - view_origin_cells
	if local_position.x < 0.0 or local_position.y < 0.0 or local_position.x > float(span) or local_position.y > float(span):
		return
	var center := view_origin + (local_position + Vector2(0.5, 0.5)) * cell_size
	var edge_alpha: float = _get_minimap_edge_alpha(center, cell_size * 0.45)
	if edge_alpha <= 0.0:
		return
	var heading: Vector2 = (center - MAP_CENTER).normalized()
	var ring_offset: Vector2 = heading * minf(8.0, cell_size * 0.25) if heading.length() > 0.0 else Vector2.ZERO
	draw_circle(center + ring_offset, maxf(3.2, cell_size * 0.33), Color(0.0, 0.0, 0.0, 0.22 * edge_alpha))
	draw_circle(center, maxf(2.8, cell_size * 0.28), Color(PLAYER_COLOR.r, PLAYER_COLOR.g, PLAYER_COLOR.b, PLAYER_COLOR.a * edge_alpha))
	draw_circle(center, maxf(1.1, cell_size * 0.13), Color(PLAYER_RING.r, PLAYER_RING.g, PLAYER_RING.b, PLAYER_RING.a * edge_alpha))


func _get_follow_view_origin(span: int) -> Vector2:
	var half_span: float = float(span) * 0.5
	var max_origin_x: float = maxf(0.0, float(grid_size.x - span))
	var max_origin_y: float = maxf(0.0, float(grid_size.y - span))
	return Vector2(
		clampf(display_player_map_position.x - half_span, 0.0, max_origin_x),
		clampf(display_player_map_position.y - half_span, 0.0, max_origin_y)
	)


func _is_cell_in_follow_view(cell: Vector2i, view_origin_cells: Vector2, span: int) -> bool:
	var cell_position := Vector2(float(cell.x), float(cell.y))
	return (
		cell_position.x >= floor(view_origin_cells.x) - 1.0
		and cell_position.y >= floor(view_origin_cells.y) - 1.0
		and cell_position.x <= ceil(view_origin_cells.x + float(span)) + 1.0
		and cell_position.y <= ceil(view_origin_cells.y + float(span)) + 1.0
	)


func _draw_full_map_marker(origin: Vector2, cell_size: float, bounds: Rect2i, cell: Vector2i, color: Color) -> void:
	if cell.x < 0 or cell.y < 0 or not bounds.has_point(cell):
		return
	var cell_key: String = _cell_key(cell)
	if not explored_floor.has(cell_key) and not visible_floor.has(cell_key):
		return
	var local_position := Vector2(float(cell.x - bounds.position.x), float(cell.y - bounds.position.y))
	var center := origin + (local_position + Vector2(0.5, 0.5)) * cell_size
	draw_circle(center, maxf(2.6, cell_size * 0.22), color)


func _make_bounds_from_keys(keys: Array) -> Rect2i:
	var cells: Array[Vector2i] = []
	for key_variant in keys:
		var cell := _cell_from_key(str(key_variant))
		if cell.x >= 0:
			cells.append(cell)
	if cells.is_empty():
		return Rect2i(Vector2i.ZERO, grid_size)
	return _make_bounds_from_cells(cells)


func _make_bounds_from_cells(cells: Array[Vector2i]) -> Rect2i:
	var min_x: int = cells[0].x
	var max_x: int = cells[0].x
	var min_y: int = cells[0].y
	var max_y: int = cells[0].y
	for cell in cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))


func _expand_bounds(bounds: Rect2i, padding: int) -> Rect2i:
	return Rect2i(
		bounds.position - Vector2i(padding, padding),
		bounds.size + Vector2i(padding * 2, padding * 2)
	)


func _gui_input(event: InputEvent) -> void:
	if not map_enabled:
		return
	var should_toggle: bool = false
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		should_toggle = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		should_toggle = touch_event.pressed
	if not should_toggle:
		return
	is_expanded = not is_expanded
	_apply_layout()
	queue_redraw()
	accept_event()


func set_player_tracking(next_player_map_position: Vector2, next_player_cell: Vector2i) -> void:
	player_map_position = next_player_map_position
	player_cell = next_player_cell
	if display_player_map_position.x < 0.0:
		display_player_map_position = player_map_position


func _cell_array_to_map(cells: Variant) -> Dictionary:
	var result: Dictionary = {}
	for cell in _normalize_cells(cells):
		result[_cell_key(cell)] = true
	return result


func _normalize_cells(cells: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if typeof(cells) != TYPE_ARRAY:
		return result
	for cell_variant in cells:
		result.append(_normalize_cell(cell_variant))
	return result


func _normalize_cell(cell_variant: Variant) -> Vector2i:
	if cell_variant is Vector2i:
		return cell_variant
	if cell_variant is Vector2:
		var vector_cell: Vector2 = cell_variant
		return Vector2i(int(round(vector_cell.x)), int(round(vector_cell.y)))
	if typeof(cell_variant) == TYPE_DICTIONARY:
		var cell_dict: Dictionary = cell_variant
		return Vector2i(int(cell_dict.get("x", -1)), int(cell_dict.get("y", -1)))
	return Vector2i(-1, -1)


func _normalize_map_position(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		var vector_cell: Vector2i = value
		return Vector2(float(vector_cell.x), float(vector_cell.y))
	if typeof(value) == TYPE_DICTIONARY:
		var value_dict: Dictionary = value
		return Vector2(float(value_dict.get("x", -1.0)), float(value_dict.get("y", -1.0)))
	return Vector2(-1.0, -1.0)


func _cell_from_key(cell_key: String) -> Vector2i:
	var parts: PackedStringArray = cell_key.split(",")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))


func _clamp_rect_to_grid(rect: Rect2i) -> Rect2i:
	var result: Rect2i = rect
	result.size.x = mini(result.size.x, grid_size.x)
	result.size.y = mini(result.size.y, grid_size.y)
	result.position.x = clampi(result.position.x, 0, maxi(0, grid_size.x - result.size.x))
	result.position.y = clampi(result.position.y, 0, maxi(0, grid_size.y - result.size.y))
	return result


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _sync_reveal_progress(previous_explored: Dictionary) -> void:
	for cell_key_variant in explored_floor.keys():
		var cell_key: String = str(cell_key_variant)
		if reveal_progress.has(cell_key):
			continue
		reveal_progress[cell_key] = 1.0 if previous_explored.has(cell_key) else 0.0

	var stale_keys: Array[String] = []
	for cell_key_variant in reveal_progress.keys():
		var cell_key: String = str(cell_key_variant)
		if not explored_floor.has(cell_key):
			stale_keys.append(cell_key)
	for cell_key in stale_keys:
		reveal_progress.erase(cell_key)


func _get_cell_draw_color(cell_key: String, base_color: Color) -> Color:
	var reveal_alpha: float = float(reveal_progress.get(cell_key, 1.0))
	return Color(base_color.r, base_color.g, base_color.b, base_color.a * reveal_alpha)


func _get_minimap_edge_alpha(point: Vector2, padding: float) -> float:
	var fade_start: float = MAP_RADIUS - MINIMAP_EDGE_FADE
	var fade_end: float = MAP_RADIUS + padding
	var distance_from_center: float = point.distance_to(MAP_CENTER)
	if distance_from_center <= fade_start:
		return 1.0
	if distance_from_center >= fade_end:
		return 0.0
	return 1.0 - inverse_lerp(fade_start, fade_end, distance_from_center)
