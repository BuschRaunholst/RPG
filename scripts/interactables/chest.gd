extends StaticBody2D

@export var speaker_name: String = "Chest"
@export var chest_id: String = "starter_chest"
@export var item_name: String = "Trail Ration"
@export var item_kind: String = "consumable"
@export var closed_message: String = "The chest is shut tight."
@export_range(-1, 3, 1) var chest_color_index: int = -1

const SPRITE_SIZE: Vector2i = Vector2i(48, 40)
const WOOD_COLORS: Array[Color] = [
	Color(0.55, 0.34, 0.16, 1.0),
	Color(0.64, 0.40, 0.18, 1.0),
	Color(0.47, 0.29, 0.15, 1.0),
	Color(0.58, 0.28, 0.17, 1.0),
]
const WOOD_LIGHT_COLORS: Array[Color] = [
	Color(0.78, 0.56, 0.28, 1.0),
	Color(0.86, 0.62, 0.31, 1.0),
	Color(0.70, 0.48, 0.25, 1.0),
	Color(0.78, 0.42, 0.25, 1.0),
]
const WOOD_DARK_COLORS: Array[Color] = [
	Color(0.24, 0.14, 0.08, 1.0),
	Color(0.30, 0.18, 0.09, 1.0),
	Color(0.20, 0.12, 0.07, 1.0),
	Color(0.27, 0.12, 0.08, 1.0),
]
const METAL_COLOR: Color = Color(0.96, 0.78, 0.28, 1.0)
const METAL_DARK_COLOR: Color = Color(0.48, 0.34, 0.12, 1.0)
const GLOW_COLOR: Color = Color(0.82, 0.96, 1.0, 1.0)
const GLOW_RADIUS: int = 4

@onready var body: Sprite2D = $Body
@onready var interaction_glow: Sprite2D = $InteractionGlow

var is_open: bool = false
var interaction_highlighted: bool = false
var highlight_time: float = 0.0


func get_dialogue_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()

	if is_open:
		lines.append("The chest is empty.")
	else:
		lines.append(closed_message)

	return lines


func open_chest() -> void:
	is_open = true
	_update_visual_state()


func set_opened(value: bool) -> void:
	is_open = value
	_update_visual_state()


func _ready() -> void:
	_update_visual_state()
	_update_glow_visual()


func _process(delta: float) -> void:
	if body == null:
		return

	if not interaction_highlighted or is_open:
		body.scale = Vector2.ONE
		body.modulate = Color.WHITE
		_update_glow_visual()
		return

	highlight_time += delta
	var glow: float = 0.34 + sin(highlight_time * 2.6) * 0.08
	body.scale = Vector2.ONE
	body.modulate = Color.WHITE
	if interaction_glow != null:
		interaction_glow.visible = true
		interaction_glow.modulate = Color(1.0, 1.0, 1.0, glow)


func set_interaction_highlight(value: bool) -> void:
	interaction_highlighted = value and not is_open
	_update_glow_visual()
	if not interaction_highlighted and body != null:
		body.scale = Vector2.ONE
		body.modulate = Color.WHITE


func _update_glow_visual() -> void:
	if interaction_glow == null:
		return

	interaction_glow.visible = interaction_highlighted and not is_open
	interaction_glow.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _update_visual_state() -> void:
	if body == null:
		return

	var palette_index: int = chest_color_index
	if palette_index < 0:
		palette_index = _stable_hash(chest_id + speaker_name) % WOOD_COLORS.size()

	var chest_texture: ImageTexture = _create_chest_texture(
		is_open,
		WOOD_COLORS[palette_index],
		WOOD_LIGHT_COLORS[palette_index],
		WOOD_DARK_COLORS[palette_index]
	)
	body.texture = chest_texture
	if interaction_glow != null:
		interaction_glow.texture = _create_alpha_glow_texture(chest_texture.get_image(), GLOW_RADIUS)
	set_interaction_highlight(interaction_highlighted)


func _create_chest_texture(opened: bool, wood: Color, wood_light: Color, wood_dark: Color) -> ImageTexture:
	var image: Image = Image.create(SPRITE_SIZE.x, SPRITE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	if opened:
		_draw_open_chest(image, wood, wood_light, wood_dark)
	else:
		_draw_closed_chest(image, wood, wood_light, wood_dark)

	return ImageTexture.create_from_image(image)


func _draw_closed_chest(image: Image, wood: Color, wood_light: Color, wood_dark: Color) -> void:
	_draw_rect(image, Rect2i(7, 17, 34, 17), wood)
	_draw_rect(image, Rect2i(9, 14, 30, 7), wood_light)
	_draw_rect(image, Rect2i(11, 11, 26, 5), wood_light.lerp(Color.WHITE, 0.08))
	_draw_rect(image, Rect2i(7, 31, 34, 3), wood_dark)
	_draw_rect(image, Rect2i(7, 17, 3, 17), wood_dark)
	_draw_rect(image, Rect2i(38, 17, 3, 17), wood_dark)
	_draw_rect(image, Rect2i(10, 22, 28, 2), wood_dark.lerp(wood, 0.36))
	_draw_rect(image, Rect2i(14, 17, 3, 16), wood_dark)
	_draw_rect(image, Rect2i(31, 17, 3, 16), wood_dark)
	_draw_rect(image, Rect2i(21, 19, 6, 9), METAL_COLOR)
	_draw_rect(image, Rect2i(22, 20, 4, 7), METAL_DARK_COLOR)
	_draw_rect(image, Rect2i(23, 20, 2, 3), METAL_COLOR)


func _draw_open_chest(image: Image, wood: Color, wood_light: Color, wood_dark: Color) -> void:
	_draw_rect(image, Rect2i(8, 21, 32, 13), wood)
	_draw_rect(image, Rect2i(8, 31, 32, 3), wood_dark)
	_draw_rect(image, Rect2i(8, 21, 3, 13), wood_dark)
	_draw_rect(image, Rect2i(37, 21, 3, 13), wood_dark)
	_draw_rect(image, Rect2i(12, 22, 24, 4), wood_dark.lerp(Color.BLACK, 0.35))
	_draw_rect(image, Rect2i(12, 12, 28, 5), wood_light)
	_draw_rect(image, Rect2i(10, 15, 30, 5), wood)
	_draw_rect(image, Rect2i(10, 18, 30, 2), wood_dark)
	_draw_rect(image, Rect2i(15, 21, 3, 12), wood_dark)
	_draw_rect(image, Rect2i(30, 21, 3, 12), wood_dark)
	_draw_rect(image, Rect2i(21, 24, 6, 7), METAL_COLOR)
	_draw_rect(image, Rect2i(22, 25, 4, 5), METAL_DARK_COLOR)


func _draw_rect(image: Image, rect: Rect2i, color: Color) -> void:
	image.fill_rect(rect, color)


func _create_alpha_glow_texture(source: Image, radius: int) -> ImageTexture:
	var padding: int = radius + 2
	var glow_image: Image = Image.create(source.get_width() + padding * 2, source.get_height() + padding * 2, false, Image.FORMAT_RGBA8)
	glow_image.fill(Color(0.0, 0.0, 0.0, 0.0))

	for y in range(source.get_height()):
		for x in range(source.get_width()):
			if source.get_pixel(x, y).a <= 0.05:
				continue
			for offset_y in range(-radius, radius + 1):
				for offset_x in range(-radius, radius + 1):
					var distance: float = Vector2(float(offset_x), float(offset_y)).length()
					if distance > float(radius):
						continue
					var target_position := Vector2i(x + padding + offset_x, y + padding + offset_y)
					var strength: float = 1.0 - (distance / float(radius + 1))
					var next_color: Color = GLOW_COLOR
					next_color.a = maxf(glow_image.get_pixelv(target_position).a, strength)
					glow_image.set_pixelv(target_position, next_color)

	return ImageTexture.create_from_image(glow_image)


func _stable_hash(value: String) -> int:
	var result: int = 0
	for character_index in value.length():
		result = int((result * 31 + value.unicode_at(character_index)) & 0x7fffffff)
	return result
