extends "res://scripts/actors/beast_mob.gd"

@export_range(-1, 4, 1) var slime_color_index: int = -1

const SPRITE_SIZE: int = 32
const SLIME_COLORS: Array[Color] = [
	Color(0.34, 0.70, 0.39, 1.0),
	Color(0.43, 0.78, 0.48, 1.0),
	Color(0.32, 0.64, 0.52, 1.0),
	Color(0.52, 0.74, 0.36, 1.0),
	Color(0.39, 0.68, 0.30, 1.0),
]
const SLIME_DARK_COLORS: Array[Color] = [
	Color(0.15, 0.34, 0.18, 1.0),
	Color(0.18, 0.39, 0.22, 1.0),
	Color(0.13, 0.31, 0.28, 1.0),
	Color(0.28, 0.37, 0.15, 1.0),
	Color(0.18, 0.32, 0.14, 1.0),
]
const HIGHLIGHT: Color = Color(0.78, 0.96, 0.70, 0.72)
const EYE_COLOR: Color = Color(0.10, 0.16, 0.10, 1.0)

var idle_time: float = 0.0

@onready var body: Sprite2D = $Body


func _ready() -> void:
	super._ready()
	_apply_slime_visual()


func _process(delta: float) -> void:
	if body == null or defeated_state:
		return

	idle_time += delta
	if attack_feedback_remaining > 0.0:
		return

	var pulse: float = sin(idle_time * 4.0) * 0.035
	body.scale = Vector2(1.0 + pulse, 1.0 - pulse)


func _apply_slime_visual() -> void:
	if body == null:
		return

	var index: int = slime_color_index
	if index < 0:
		index = _stable_hash(enemy_id + enemy_name) % SLIME_COLORS.size()

	body.texture = _create_slime_texture(SLIME_COLORS[index], SLIME_DARK_COLORS[index])
	body.centered = true


func _create_slime_texture(main_color: Color, dark_color: Color) -> ImageTexture:
	var image: Image = Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	_draw_slime_blob(image, main_color, dark_color)
	_draw_highlights(image)
	_draw_face(image)

	return ImageTexture.create_from_image(image)


func _draw_slime_blob(image: Image, main_color: Color, dark_color: Color) -> void:
	for y in range(5, 29):
		for x in range(3, 30):
			var centered_x: float = (float(x) - 16.0) / 14.0
			var centered_y: float = (float(y) - 19.0) / 11.0
			var distance: float = centered_x * centered_x + centered_y * centered_y
			var dome_limit: float = 1.0
			if y < 13:
				dome_limit = 0.82
			if distance <= dome_limit:
				var shade: Color = main_color
				if y > 23:
					shade = dark_color.lerp(main_color, 0.28)
				elif x < 8 or x > 25:
					shade = dark_color.lerp(main_color, 0.50)
				image.set_pixel(x, y, shade)

	for x in range(8, 25):
		image.set_pixel(x, 28, dark_color)
	for x in range(11, 22):
		image.set_pixel(x, 29, dark_color.lerp(main_color, 0.25))


func _draw_highlights(image: Image) -> void:
	_draw_rect(image, Rect2i(10, 8, 8, 2), HIGHLIGHT)
	_draw_rect(image, Rect2i(8, 10, 5, 1), HIGHLIGHT)
	_draw_rect(image, Rect2i(20, 12, 3, 1), HIGHLIGHT.lerp(Color.TRANSPARENT, 0.25))


func _draw_face(image: Image) -> void:
	_draw_rect(image, Rect2i(10, 17, 3, 4), EYE_COLOR)
	_draw_rect(image, Rect2i(20, 17, 3, 4), EYE_COLOR)
	_draw_rect(image, Rect2i(14, 23, 5, 1), EYE_COLOR)
	_draw_rect(image, Rect2i(15, 24, 3, 1), EYE_COLOR)


func _draw_rect(image: Image, rect: Rect2i, color: Color) -> void:
	image.fill_rect(rect, color)


func _stable_hash(value: String) -> int:
	var result: int = 0
	for character_index in value.length():
		result = int((result * 31 + value.unicode_at(character_index)) & 0x7fffffff)
	return result
