extends StaticBody2D

@export var npc_id: String = "villager"
@export var npc_name: String = "Villager"
@export_multiline var dialogue_text: String = "Welcome to the village.\nThis is the start of our RPG."
@export_enum("auto", "male", "female") var visual_gender: String = "auto"
@export_range(-1, 5, 1) var hair_color_index: int = -1
@export_range(-1, 7, 1) var clothing_color_index: int = -1

@onready var body: Sprite2D = $Body
@onready var quest_marker: Label = $QuestMarker

const SPRITE_SIZE := Vector2i(64, 64)
const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)
const SHADOW := Color(0.04, 0.04, 0.035, 0.32)
const OUTLINE := Color(0.055, 0.045, 0.037)
const SKIN_DARK := Color(0.50, 0.32, 0.21)
const SKIN := Color(0.68, 0.45, 0.29)
const SKIN_LIGHT := Color(0.86, 0.62, 0.42)
const EYE := Color(0.11, 0.09, 0.08)
const BELT := Color(0.22, 0.14, 0.08)
const BOOT := Color(0.08, 0.06, 0.045)

const HAIR_COLORS: Array[Color] = [
	Color(0.16, 0.11, 0.08),
	Color(0.28, 0.18, 0.10),
	Color(0.46, 0.29, 0.12),
	Color(0.68, 0.50, 0.24),
	Color(0.58, 0.55, 0.48),
	Color(0.10, 0.09, 0.08),
]

const CLOTHING_COLORS: Array[Color] = [
	Color(0.40, 0.34, 0.24),
	Color(0.30, 0.43, 0.34),
	Color(0.42, 0.34, 0.50),
	Color(0.55, 0.32, 0.24),
	Color(0.24, 0.36, 0.50),
	Color(0.52, 0.46, 0.28),
	Color(0.48, 0.28, 0.37),
	Color(0.32, 0.40, 0.28),
]


func _ready() -> void:
	_apply_visual_identity()


func get_dialogue_lines() -> PackedStringArray:
	var lines := PackedStringArray()

	for line in dialogue_text.split("\n", false):
		var trimmed := line.strip_edges()

		if not trimmed.is_empty():
			lines.append(trimmed)

	return lines


func set_quest_marker_visible(value: bool) -> void:
	if quest_marker != null:
		quest_marker.visible = value


func _apply_visual_identity() -> void:
	if body == null:
		return

	var identity_hash := _stable_hash(npc_id if not npc_id.is_empty() else npc_name)
	var gender := _resolve_gender(identity_hash)
	var selected_hair_color := _select_color(HAIR_COLORS, hair_color_index, identity_hash / 7)
	var selected_clothing_color := _select_color(CLOTHING_COLORS, clothing_color_index, identity_hash / 17)

	body.texture = _create_npc_texture(gender, selected_hair_color, selected_clothing_color, identity_hash)


func _resolve_gender(identity_hash: int) -> String:
	if visual_gender != "auto":
		return visual_gender

	return "female" if identity_hash % 2 == 0 else "male"


func _select_color(colors: Array[Color], selected_index: int, seed: int) -> Color:
	if selected_index >= 0 and selected_index < colors.size():
		return colors[selected_index]

	return colors[seed % colors.size()]


func _create_npc_texture(gender: String, hair_color: Color, clothing_color: Color, identity_hash: int) -> Texture2D:
	var image := Image.create(SPRITE_SIZE.x, SPRITE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(TRANSPARENT)

	_draw_rect(image, Rect2i(24, 57, 16, 3), SHADOW)
	_draw_rect(image, Rect2i(21, 58, 22, 2), SHADOW)

	if gender == "female":
		_draw_female_body(image, hair_color, clothing_color, identity_hash)
	else:
		_draw_male_body(image, hair_color, clothing_color, identity_hash)

	return ImageTexture.create_from_image(image)


func _draw_male_body(image: Image, hair_color: Color, clothing_color: Color, identity_hash: int) -> void:
	var clothing_dark := clothing_color.darkened(0.32)
	var clothing_light := clothing_color.lightened(0.20)
	var hair_dark := hair_color.darkened(0.35)
	var patch_color := _select_color(CLOTHING_COLORS, -1, identity_hash / 31).darkened(0.05)

	_draw_rect(image, Rect2i(25, 53, 7, 5), BOOT)
	_draw_rect(image, Rect2i(32, 53, 7, 5), BOOT)
	_draw_rect(image, Rect2i(26, 39, 5, 16), OUTLINE)
	_draw_rect(image, Rect2i(33, 39, 5, 16), OUTLINE)
	_draw_rect(image, Rect2i(27, 39, 3, 15), clothing_dark.darkened(0.30))
	_draw_rect(image, Rect2i(34, 39, 3, 15), clothing_dark.darkened(0.30))

	_draw_rect(image, Rect2i(25, 23, 14, 4), OUTLINE)
	_draw_rect(image, Rect2i(24, 27, 16, 12), OUTLINE)
	_draw_rect(image, Rect2i(26, 39, 12, 6), OUTLINE)
	_draw_rect(image, Rect2i(27, 24, 10, 4), clothing_dark)
	_draw_rect(image, Rect2i(26, 28, 12, 11), clothing_dark)
	_draw_rect(image, Rect2i(28, 39, 8, 5), clothing_dark)
	_draw_rect(image, Rect2i(28, 24, 8, 4), clothing_color.darkened(0.08))
	_draw_rect(image, Rect2i(27, 28, 10, 10), clothing_color.darkened(0.08))
	_draw_rect(image, Rect2i(28, 25, 6, 2), clothing_light)
	_draw_rect(image, Rect2i(34, 30, 3, 7), patch_color)
	_draw_rect(image, Rect2i(25, 39, 15, 2), BELT)

	_draw_rect(image, Rect2i(19, 27, 4, 18), OUTLINE)
	_draw_rect(image, Rect2i(41, 27, 4, 18), OUTLINE)
	_draw_rect(image, Rect2i(20, 28, 2, 12), clothing_dark)
	_draw_rect(image, Rect2i(42, 28, 2, 12), clothing_dark)
	_draw_rect(image, Rect2i(20, 40, 2, 5), SKIN_DARK)
	_draw_rect(image, Rect2i(42, 40, 2, 5), SKIN_DARK)

	_draw_face(image, hair_color, hair_dark)


func _draw_female_body(image: Image, hair_color: Color, clothing_color: Color, identity_hash: int) -> void:
	var clothing_dark := clothing_color.darkened(0.34)
	var clothing_light := clothing_color.lightened(0.23)
	var hair_dark := hair_color.darkened(0.35)
	var apron_color := _select_color(CLOTHING_COLORS, -1, identity_hash / 29).lightened(0.12)

	_draw_rect(image, Rect2i(25, 53, 7, 5), BOOT)
	_draw_rect(image, Rect2i(32, 53, 7, 5), BOOT)
	_draw_rect(image, Rect2i(26, 40, 5, 15), OUTLINE)
	_draw_rect(image, Rect2i(33, 40, 5, 15), OUTLINE)
	_draw_rect(image, Rect2i(27, 40, 3, 14), clothing_dark.darkened(0.25))
	_draw_rect(image, Rect2i(34, 40, 3, 14), clothing_dark.darkened(0.25))

	_draw_rect(image, Rect2i(25, 23, 14, 4), OUTLINE)
	_draw_rect(image, Rect2i(24, 27, 16, 13), OUTLINE)
	_draw_rect(image, Rect2i(26, 40, 12, 7), OUTLINE)
	_draw_rect(image, Rect2i(27, 24, 10, 4), clothing_dark)
	_draw_rect(image, Rect2i(26, 28, 12, 12), clothing_dark)
	_draw_rect(image, Rect2i(28, 40, 8, 6), clothing_dark)
	_draw_rect(image, Rect2i(27, 28, 10, 11), clothing_color.darkened(0.08))
	_draw_rect(image, Rect2i(28, 26, 6, 2), clothing_light)
	_draw_rect(image, Rect2i(28, 32, 8, 13), apron_color.darkened(0.08))
	_draw_rect(image, Rect2i(24, 44, 16, 2), OUTLINE)

	_draw_rect(image, Rect2i(19, 27, 4, 18), OUTLINE)
	_draw_rect(image, Rect2i(41, 27, 4, 18), OUTLINE)
	_draw_rect(image, Rect2i(20, 28, 2, 12), clothing_dark)
	_draw_rect(image, Rect2i(42, 28, 2, 12), clothing_dark)
	_draw_rect(image, Rect2i(20, 40, 2, 5), SKIN_DARK)
	_draw_rect(image, Rect2i(42, 40, 2, 5), SKIN_DARK)

	_draw_face(image, hair_color, hair_dark)
	_draw_rect(image, Rect2i(22, 12, 3, 17), hair_dark)
	_draw_rect(image, Rect2i(39, 12, 3, 17), hair_dark)
	_draw_rect(image, Rect2i(23, 15, 2, 12), hair_color)
	_draw_rect(image, Rect2i(39, 15, 2, 12), hair_color)


func _draw_face(image: Image, hair_color: Color, hair_dark: Color) -> void:
	_draw_rect(image, Rect2i(28, 22, 8, 4), OUTLINE)
	_draw_rect(image, Rect2i(29, 22, 6, 4), SKIN_DARK)
	_draw_rect(image, Rect2i(30, 22, 4, 3), SKIN)
	_draw_rect(image, Rect2i(28, 19, 8, 5), OUTLINE)
	_draw_rect(image, Rect2i(29, 19, 6, 5), SKIN_DARK)
	_draw_rect(image, Rect2i(30, 19, 5, 4), SKIN)
	_draw_rect(image, Rect2i(25, 7, 14, 16), OUTLINE)
	_draw_rect(image, Rect2i(26, 8, 12, 14), SKIN_DARK)
	_draw_rect(image, Rect2i(27, 8, 10, 13), SKIN)
	_draw_rect(image, Rect2i(28, 9, 6, 2), SKIN_LIGHT)
	_draw_rect(image, Rect2i(28, 15, 2, 2), EYE)
	_draw_rect(image, Rect2i(35, 15, 2, 2), EYE)
	_draw_rect(image, Rect2i(31, 20, 3, 1), SKIN_DARK)
	_draw_rect(image, Rect2i(25, 4, 14, 7), hair_dark)
	_draw_rect(image, Rect2i(26, 4, 12, 6), hair_color)
	_draw_rect(image, Rect2i(24, 8, 5, 6), hair_color)
	_draw_rect(image, Rect2i(37, 8, 4, 6), hair_color)
	_draw_rect(image, Rect2i(27, 4, 5, 2), hair_dark)
	_draw_rect(image, Rect2i(33, 5, 4, 2), hair_dark)


func _draw_rect(image: Image, rect: Rect2i, color: Color) -> void:
	image.fill_rect(rect, color)


func _stable_hash(value: String) -> int:
	var hash_value := value.hash()

	if hash_value < 0:
		hash_value = -hash_value

	return hash_value
