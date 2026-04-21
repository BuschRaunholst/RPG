extends SceneTree

const BASE_SHEET_PATH := "res://assets/art/characters/player_human_base_4dir_64.png"
const TUNIC_SHEET_PATH := "res://assets/art/characters/player_clothes_village_tunic_4dir_64.png"
const BOOTS_SHEET_PATH := "res://assets/art/characters/player_boots_worn_4dir_64.png"
const PREVIEW_PATH := "res://assets/art/characters/player_layered_preview_4x.png"
const FRAME_SIZE := Vector2i(64, 64)
const COLUMNS := 3
const ROWS := 4

const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)
const SHADOW := Color(0.0, 0.0, 0.0, 0.28)
const OUTLINE := Color(0.045, 0.036, 0.030, 1.0)
const HAIR := Color(0.10, 0.065, 0.035, 1.0)
const SKIN_DARK := Color(0.48, 0.30, 0.20, 1.0)
const SKIN := Color(0.66, 0.43, 0.28, 1.0)
const SKIN_LIGHT := Color(0.82, 0.58, 0.38, 1.0)
const FOOT_DARK := Color(0.50, 0.31, 0.20, 1.0)
const FOOT_LIGHT := Color(0.70, 0.45, 0.29, 1.0)
const TUNIC_DARK := Color(0.17, 0.20, 0.16, 1.0)
const TUNIC := Color(0.28, 0.33, 0.25, 1.0)
const TUNIC_LIGHT := Color(0.42, 0.46, 0.34, 1.0)
const LEATHER := Color(0.25, 0.15, 0.08, 1.0)
const BOOTS := Color(0.085, 0.065, 0.050, 1.0)


func _initialize() -> void:
	var base_sheet: Image = Image.create(FRAME_SIZE.x * COLUMNS, FRAME_SIZE.y * ROWS, false, Image.FORMAT_RGBA8)
	var tunic_sheet: Image = Image.create(FRAME_SIZE.x * COLUMNS, FRAME_SIZE.y * ROWS, false, Image.FORMAT_RGBA8)
	var boots_sheet: Image = Image.create(FRAME_SIZE.x * COLUMNS, FRAME_SIZE.y * ROWS, false, Image.FORMAT_RGBA8)
	base_sheet.fill(TRANSPARENT)
	tunic_sheet.fill(TRANSPARENT)
	boots_sheet.fill(TRANSPARENT)

	_draw_direction_row(base_sheet, tunic_sheet, boots_sheet, 0, "down")
	_draw_direction_row(base_sheet, tunic_sheet, boots_sheet, 1, "left")
	_draw_direction_row(base_sheet, tunic_sheet, boots_sheet, 2, "right")
	_draw_direction_row(base_sheet, tunic_sheet, boots_sheet, 3, "up")

	_save_sheet(base_sheet, BASE_SHEET_PATH)
	_save_sheet(tunic_sheet, TUNIC_SHEET_PATH)
	_save_sheet(boots_sheet, BOOTS_SHEET_PATH)
	_save_preview(base_sheet, tunic_sheet, boots_sheet)
	quit()


func _save_sheet(image: Image, path: String) -> void:
	var save_error: Error = image.save_png(path)
	if save_error != OK:
		push_error("Could not save sheet: %s" % path)
		quit(1)


func _save_preview(base_sheet: Image, tunic_sheet: Image, boots_sheet: Image) -> void:
	var preview_source: Image = Image.create(base_sheet.get_width(), base_sheet.get_height(), false, Image.FORMAT_RGBA8)
	preview_source.fill(TRANSPARENT)
	preview_source.blit_rect(base_sheet, Rect2i(Vector2i.ZERO, base_sheet.get_size()), Vector2i.ZERO)
	preview_source.blend_rect(tunic_sheet, Rect2i(Vector2i.ZERO, tunic_sheet.get_size()), Vector2i.ZERO)
	preview_source.blend_rect(boots_sheet, Rect2i(Vector2i.ZERO, boots_sheet.get_size()), Vector2i.ZERO)
	var preview: Image = Image.create(preview_source.get_width() * 4, preview_source.get_height() * 4, false, Image.FORMAT_RGBA8)
	preview.fill(TRANSPARENT)
	preview.blit_rect(preview_source, Rect2i(Vector2i.ZERO, preview_source.get_size()), Vector2i.ZERO)
	preview.resize(preview_source.get_width() * 4, preview_source.get_height() * 4, Image.INTERPOLATE_NEAREST)
	preview.save_png(PREVIEW_PATH)


func _draw_direction_row(base_sheet: Image, tunic_sheet: Image, boots_sheet: Image, row: int, direction: String) -> void:
	_draw_frame(base_sheet, tunic_sheet, boots_sheet, Vector2i(0, row * FRAME_SIZE.y), direction, 0)
	_draw_frame(base_sheet, tunic_sheet, boots_sheet, Vector2i(FRAME_SIZE.x, row * FRAME_SIZE.y), direction, -1)
	_draw_frame(base_sheet, tunic_sheet, boots_sheet, Vector2i(FRAME_SIZE.x * 2, row * FRAME_SIZE.y), direction, 1)


func _draw_frame(base_sheet: Image, tunic_sheet: Image, boots_sheet: Image, origin: Vector2i, direction: String, stride: int) -> void:
	_draw_shadow(base_sheet, origin)
	match direction:
		"left":
			_draw_side_human(base_sheet, tunic_sheet, boots_sheet, origin, -1, stride)
		"right":
			_draw_side_human(base_sheet, tunic_sheet, boots_sheet, origin, 1, stride)
		"up":
			_draw_back_human(base_sheet, tunic_sheet, boots_sheet, origin, stride)
		_:
			_draw_front_human(base_sheet, tunic_sheet, boots_sheet, origin, stride)


func _draw_shadow(sheet: Image, origin: Vector2i) -> void:
	_draw_rect(sheet, origin + Vector2i(22, 56), Vector2i(20, 4), SHADOW)
	_draw_rect(sheet, origin + Vector2i(25, 55), Vector2i(14, 1), SHADOW)


func _draw_front_human(base_sheet: Image, tunic_sheet: Image, boots_sheet: Image, origin: Vector2i, stride: int) -> void:
	var left_leg_offset: int = -stride
	var right_leg_offset: int = stride
	_draw_base_leg(base_sheet, origin + Vector2i(26 + left_leg_offset, 39), false)
	_draw_base_leg(base_sheet, origin + Vector2i(33 + right_leg_offset, 39), false)
	_draw_base_torso(base_sheet, origin)
	_draw_head_front(base_sheet, origin)
	_draw_tunic_front(tunic_sheet, origin)
	_draw_boots(boots_sheet, origin + Vector2i(26 + left_leg_offset, 53), origin + Vector2i(33 + right_leg_offset, 53))


func _draw_back_human(base_sheet: Image, tunic_sheet: Image, boots_sheet: Image, origin: Vector2i, stride: int) -> void:
	var left_leg_offset: int = -stride
	var right_leg_offset: int = stride
	_draw_base_leg(base_sheet, origin + Vector2i(26 + left_leg_offset, 39), true)
	_draw_base_leg(base_sheet, origin + Vector2i(33 + right_leg_offset, 39), true)
	_draw_base_torso(base_sheet, origin)
	_draw_head_back(base_sheet, origin)
	_draw_tunic_back(tunic_sheet, origin)
	_draw_boots(boots_sheet, origin + Vector2i(26 + left_leg_offset, 53), origin + Vector2i(33 + right_leg_offset, 53))


func _draw_side_human(base_sheet: Image, tunic_sheet: Image, boots_sheet: Image, origin: Vector2i, facing: int, stride: int) -> void:
	var rear_offset: int = -stride
	var front_offset: int = stride
	_draw_base_leg(base_sheet, origin + Vector2i(28 + rear_offset, 39), false)
	_draw_base_leg(base_sheet, origin + Vector2i(33 + front_offset, 39), false)
	_draw_base_torso_side(base_sheet, origin)
	_draw_head_side(base_sheet, origin, facing)
	_draw_tunic_side(tunic_sheet, origin, facing, stride)
	_draw_boots(boots_sheet, origin + Vector2i(28 + rear_offset, 53), origin + Vector2i(33 + front_offset, 53))


func _draw_base_torso(sheet: Image, origin: Vector2i) -> void:
	_draw_rect(sheet, origin + Vector2i(25, 27), Vector2i(14, 4), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(24, 31), Vector2i(16, 11), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(26, 42), Vector2i(12, 6), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(27, 28), Vector2i(10, 4), SKIN_DARK)
	_draw_rect(sheet, origin + Vector2i(26, 32), Vector2i(12, 10), SKIN_DARK)
	_draw_rect(sheet, origin + Vector2i(28, 42), Vector2i(8, 5), SKIN_DARK)
	_draw_rect(sheet, origin + Vector2i(28, 28), Vector2i(8, 4), SKIN)
	_draw_rect(sheet, origin + Vector2i(27, 32), Vector2i(10, 9), SKIN)
	_draw_rect(sheet, origin + Vector2i(29, 42), Vector2i(6, 3), Color(0.55, 0.47, 0.36, 1.0))


func _draw_base_torso_side(sheet: Image, origin: Vector2i) -> void:
	_draw_rect(sheet, origin + Vector2i(27, 27), Vector2i(10, 4), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(26, 31), Vector2i(12, 11), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(28, 42), Vector2i(8, 6), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(29, 28), Vector2i(6, 4), SKIN_DARK)
	_draw_rect(sheet, origin + Vector2i(28, 32), Vector2i(8, 10), SKIN_DARK)
	_draw_rect(sheet, origin + Vector2i(30, 42), Vector2i(5, 5), SKIN_DARK)
	_draw_rect(sheet, origin + Vector2i(29, 32), Vector2i(6, 9), SKIN)
	_draw_rect(sheet, origin + Vector2i(30, 44), Vector2i(4, 3), Color(0.55, 0.47, 0.36, 1.0))


func _draw_base_leg(sheet: Image, origin: Vector2i, back: bool) -> void:
	var leg_color: Color = SKIN_DARK if back else SKIN
	_draw_rect(sheet, origin, Vector2i(5, 16), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(1, 0), Vector2i(3, 15), leg_color)
	_draw_rect(sheet, origin + Vector2i(-1, 14), Vector2i(7, 4), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(0, 14), Vector2i(5, 3), FOOT_DARK)
	_draw_rect(sheet, origin + Vector2i(1, 14), Vector2i(3, 1), FOOT_LIGHT)


func _draw_base_arm(sheet: Image, origin: Vector2i, is_left_arm: bool) -> void:
	var inner_offset: int = 1 if is_left_arm else 0
	_draw_rect(sheet, origin, Vector2i(4, 17), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(1, 1), Vector2i(2, 15), SKIN_DARK)
	_draw_rect(sheet, origin + Vector2i(1 + inner_offset, 1), Vector2i(1, 14), SKIN)


func _draw_base_side_arm(sheet: Image, origin: Vector2i, facing: int, stride: int) -> void:
	var x: int = 26 if facing > 0 else 36
	var arm_stride: int = stride if facing > 0 else -stride
	_draw_rect(sheet, origin + Vector2i(x + arm_stride, 31), Vector2i(3, 15), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(x + arm_stride + 1, 32), Vector2i(1, 12), SKIN_DARK)
	_draw_rect(sheet, origin + Vector2i(x + arm_stride, 44), Vector2i(3, 3), SKIN_DARK.darkened(0.10))


func _draw_tunic_front(sheet: Image, origin: Vector2i) -> void:
	_draw_rect(sheet, origin + Vector2i(25, 27), Vector2i(14, 4), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(24, 31), Vector2i(16, 12), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(26, 43), Vector2i(12, 6), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(27, 28), Vector2i(10, 4), TUNIC_DARK)
	_draw_rect(sheet, origin + Vector2i(26, 32), Vector2i(12, 11), TUNIC_DARK)
	_draw_rect(sheet, origin + Vector2i(28, 43), Vector2i(8, 5), TUNIC_DARK)
	_draw_rect(sheet, origin + Vector2i(28, 28), Vector2i(8, 4), TUNIC)
	_draw_rect(sheet, origin + Vector2i(27, 32), Vector2i(10, 10), TUNIC)
	_draw_rect(sheet, origin + Vector2i(28, 29), Vector2i(5, 2), TUNIC_LIGHT)
	_draw_rect(sheet, origin + Vector2i(34, 34), Vector2i(3, 7), TUNIC_DARK.darkened(0.15))
	_draw_rect(sheet, origin + Vector2i(25, 44), Vector2i(14, 2), LEATHER)


func _draw_tunic_back(sheet: Image, origin: Vector2i) -> void:
	_draw_rect(sheet, origin + Vector2i(25, 27), Vector2i(14, 4), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(24, 31), Vector2i(16, 12), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(26, 43), Vector2i(12, 6), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(27, 28), Vector2i(10, 4), TUNIC_DARK)
	_draw_rect(sheet, origin + Vector2i(26, 32), Vector2i(12, 11), TUNIC_DARK)
	_draw_rect(sheet, origin + Vector2i(28, 43), Vector2i(8, 5), TUNIC_DARK)
	_draw_rect(sheet, origin + Vector2i(27, 32), Vector2i(10, 10), TUNIC.darkened(0.05))
	_draw_rect(sheet, origin + Vector2i(25, 44), Vector2i(14, 2), LEATHER)


func _draw_sleeves(sheet: Image, origin: Vector2i) -> void:
	_draw_rect(sheet, origin + Vector2i(20, 29), Vector2i(5, 12), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(39, 29), Vector2i(5, 12), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(21, 30), Vector2i(3, 10), TUNIC_DARK.darkened(0.05))
	_draw_rect(sheet, origin + Vector2i(40, 30), Vector2i(3, 10), TUNIC_DARK.darkened(0.05))


func _draw_tunic_side(sheet: Image, origin: Vector2i, facing: int, stride: int) -> void:
	_draw_rect(sheet, origin + Vector2i(27, 27), Vector2i(10, 4), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(26, 31), Vector2i(12, 12), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(28, 43), Vector2i(8, 6), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(29, 28), Vector2i(6, 4), TUNIC_DARK)
	_draw_rect(sheet, origin + Vector2i(28, 32), Vector2i(8, 11), TUNIC_DARK)
	_draw_rect(sheet, origin + Vector2i(30, 43), Vector2i(5, 5), TUNIC_DARK)
	_draw_rect(sheet, origin + Vector2i(29, 32), Vector2i(6, 10), TUNIC)
	_draw_rect(sheet, origin + Vector2i(29, 29), Vector2i(4, 2), TUNIC_LIGHT)
	_draw_rect(sheet, origin + Vector2i(27, 44), Vector2i(10, 2), LEATHER)


func _draw_boots(sheet: Image, left_origin: Vector2i, right_origin: Vector2i) -> void:
	_draw_rect(sheet, left_origin + Vector2i(-1, -1), Vector2i(7, 7), OUTLINE)
	_draw_rect(sheet, right_origin + Vector2i(-1, -1), Vector2i(7, 7), OUTLINE)
	_draw_rect(sheet, left_origin + Vector2i(0, -1), Vector2i(5, 6), BOOTS)
	_draw_rect(sheet, right_origin + Vector2i(0, -1), Vector2i(5, 6), BOOTS)


func _draw_head_front(sheet: Image, origin: Vector2i) -> void:
	_draw_rect(sheet, origin + Vector2i(28, 24), Vector2i(8, 5), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(29, 24), Vector2i(6, 5), SKIN_DARK)
	_draw_rect(sheet, origin + Vector2i(30, 24), Vector2i(4, 4), SKIN)
	_draw_rect(sheet, origin + Vector2i(25, 10), Vector2i(14, 16), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(26, 11), Vector2i(12, 14), SKIN_DARK)
	_draw_rect(sheet, origin + Vector2i(27, 11), Vector2i(10, 13), SKIN)
	_draw_rect(sheet, origin + Vector2i(28, 12), Vector2i(6, 2), SKIN_LIGHT)
	_draw_rect(sheet, origin + Vector2i(25, 7), Vector2i(14, 7), HAIR)
	_draw_rect(sheet, origin + Vector2i(24, 11), Vector2i(5, 6), HAIR.darkened(0.25))
	_draw_rect(sheet, origin + Vector2i(36, 11), Vector2i(4, 6), HAIR.darkened(0.25))
	_draw_rect(sheet, origin + Vector2i(28, 17), Vector2i(2, 2), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(34, 17), Vector2i(2, 2), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(31, 22), Vector2i(3, 1), SKIN_DARK)


func _draw_head_back(sheet: Image, origin: Vector2i) -> void:
	_draw_rect(sheet, origin + Vector2i(28, 24), Vector2i(8, 5), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(29, 24), Vector2i(6, 5), SKIN_DARK)
	_draw_rect(sheet, origin + Vector2i(25, 10), Vector2i(14, 16), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(26, 11), Vector2i(12, 14), HAIR.darkened(0.10))
	_draw_rect(sheet, origin + Vector2i(27, 9), Vector2i(10, 9), HAIR)
	_draw_rect(sheet, origin + Vector2i(28, 20), Vector2i(8, 5), SKIN_DARK)


func _draw_head_side(sheet: Image, origin: Vector2i, facing: int) -> void:
	var offset_x: int = 1 if facing > 0 else -1
	_draw_rect(sheet, origin + Vector2i(28 + offset_x, 24), Vector2i(8, 5), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(29 + offset_x, 24), Vector2i(6, 5), SKIN_DARK)
	_draw_rect(sheet, origin + Vector2i(30 + offset_x, 24), Vector2i(4, 4), SKIN)
	_draw_rect(sheet, origin + Vector2i(25 + offset_x, 10), Vector2i(14, 16), OUTLINE)
	_draw_rect(sheet, origin + Vector2i(26 + offset_x, 11), Vector2i(12, 14), SKIN_DARK)
	_draw_rect(sheet, origin + Vector2i(27 + offset_x, 11), Vector2i(9, 13), SKIN)
	_draw_rect(sheet, origin + Vector2i(25 + offset_x, 7), Vector2i(14, 7), HAIR)
	if facing > 0:
		_draw_rect(sheet, origin + Vector2i(25 + offset_x, 11), Vector2i(6, 7), HAIR.darkened(0.22))
	else:
		_draw_rect(sheet, origin + Vector2i(33 + offset_x, 11), Vector2i(6, 7), HAIR.darkened(0.22))
	var eye_x: int = 36 + offset_x if facing > 0 else 28 + offset_x
	_draw_rect(sheet, origin + Vector2i(eye_x, 17), Vector2i(2, 2), OUTLINE)


func _draw_rect(sheet: Image, position: Vector2i, size: Vector2i, color: Color) -> void:
	sheet.fill_rect(Rect2i(position, size), color)
