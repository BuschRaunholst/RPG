extends StaticBody2D

@export_enum("crate", "barrel", "sack_stack", "rat_nest") var prop_kind: String = "crate"
@export_range(-1, 3, 1) var color_index: int = -1

const SPRITE_SIZE: Vector2i = Vector2i(48, 40)
const WOOD_COLORS: Array[Color] = [
	Color(0.55, 0.34, 0.17, 1.0),
	Color(0.64, 0.43, 0.21, 1.0),
	Color(0.44, 0.28, 0.15, 1.0),
	Color(0.70, 0.52, 0.30, 1.0),
]
const WOOD_DARK_COLORS: Array[Color] = [
	Color(0.25, 0.14, 0.08, 1.0),
	Color(0.32, 0.20, 0.10, 1.0),
	Color(0.20, 0.12, 0.07, 1.0),
	Color(0.35, 0.25, 0.13, 1.0),
]
const SACK_COLOR: Color = Color(0.62, 0.51, 0.34, 1.0)
const SACK_DARK_COLOR: Color = Color(0.32, 0.26, 0.17, 1.0)
const METAL_COLOR: Color = Color(0.53, 0.54, 0.49, 1.0)

@onready var body: Sprite2D = $Body


func _ready() -> void:
	_apply_visual()


func _apply_visual() -> void:
	if body == null:
		return

	var palette_index: int = color_index
	if palette_index < 0:
		palette_index = _stable_hash(name + prop_kind) % WOOD_COLORS.size()

	body.texture = _create_prop_texture(prop_kind, WOOD_COLORS[palette_index], WOOD_DARK_COLORS[palette_index])


func _create_prop_texture(kind: String, wood: Color, wood_dark: Color) -> ImageTexture:
	var image: Image = Image.create(SPRITE_SIZE.x, SPRITE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	match kind:
		"barrel":
			_draw_barrel(image, wood, wood_dark)
		"sack_stack":
			_draw_sack_stack(image)
		"rat_nest":
			_draw_rat_nest(image, wood, wood_dark)
		_:
			_draw_crate(image, wood, wood_dark)

	return ImageTexture.create_from_image(image)


func _draw_crate(image: Image, wood: Color, wood_dark: Color) -> void:
	_draw_rect(image, Rect2i(10, 11, 28, 24), wood)
	_draw_rect(image, Rect2i(10, 11, 28, 4), wood.lerp(Color.WHITE, 0.10))
	_draw_rect(image, Rect2i(10, 31, 28, 4), wood_dark)
	_draw_rect(image, Rect2i(10, 11, 4, 24), wood_dark)
	_draw_rect(image, Rect2i(34, 11, 4, 24), wood_dark)
	_draw_rect(image, Rect2i(14, 21, 20, 3), wood_dark.lerp(wood, 0.30))
	_draw_rect(image, Rect2i(22, 15, 4, 16), wood_dark.lerp(wood, 0.15))
	_draw_diag(image, Vector2i(15, 16), Vector2i(31, 30), wood_dark)
	_draw_diag(image, Vector2i(32, 16), Vector2i(16, 30), wood_dark)


func _draw_barrel(image: Image, wood: Color, wood_dark: Color) -> void:
	_draw_rect(image, Rect2i(14, 10, 20, 26), wood)
	_draw_rect(image, Rect2i(11, 14, 26, 18), wood)
	_draw_rect(image, Rect2i(14, 10, 20, 4), wood.lerp(Color.WHITE, 0.12))
	_draw_rect(image, Rect2i(14, 32, 20, 4), wood_dark)
	_draw_rect(image, Rect2i(11, 17, 26, 3), METAL_COLOR)
	_draw_rect(image, Rect2i(11, 28, 26, 3), METAL_COLOR.lerp(wood_dark, 0.20))
	_draw_rect(image, Rect2i(15, 14, 3, 18), wood_dark)
	_draw_rect(image, Rect2i(30, 14, 3, 18), wood_dark)
	_draw_rect(image, Rect2i(11, 20, 3, 8), wood_dark)
	_draw_rect(image, Rect2i(34, 20, 3, 8), wood_dark)


func _draw_sack_stack(image: Image) -> void:
	_draw_rect(image, Rect2i(10, 22, 18, 12), SACK_COLOR)
	_draw_rect(image, Rect2i(22, 18, 17, 16), SACK_COLOR.lerp(Color.WHITE, 0.06))
	_draw_rect(image, Rect2i(16, 12, 17, 13), SACK_COLOR.lerp(Color.WHITE, 0.10))
	_draw_rect(image, Rect2i(10, 31, 29, 3), SACK_DARK_COLOR)
	_draw_rect(image, Rect2i(13, 22, 2, 9), SACK_DARK_COLOR)
	_draw_rect(image, Rect2i(27, 19, 2, 12), SACK_DARK_COLOR)
	_draw_rect(image, Rect2i(20, 14, 8, 2), SACK_DARK_COLOR)


func _draw_rat_nest(image: Image, wood: Color, wood_dark: Color) -> void:
	var dirt_color: Color = Color(0.35, 0.25, 0.15, 1.0)
	var dirt_dark: Color = Color(0.13, 0.09, 0.06, 1.0)
	var straw_color: Color = Color(0.64, 0.52, 0.27, 1.0)
	_draw_rect(image, Rect2i(9, 25, 31, 7), Color(0.0, 0.0, 0.0, 0.14))
	_draw_rect(image, Rect2i(12, 18, 25, 13), dirt_color)
	_draw_rect(image, Rect2i(17, 15, 15, 8), dirt_color.lerp(wood, 0.18))
	_draw_rect(image, Rect2i(18, 21, 14, 8), dirt_dark)
	_draw_rect(image, Rect2i(21, 23, 8, 4), Color(0.03, 0.02, 0.015, 1.0))
	_draw_diag(image, Vector2i(11, 18), Vector2i(23, 14), straw_color)
	_draw_diag(image, Vector2i(34, 17), Vector2i(24, 13), straw_color.lerp(wood_dark, 0.15))
	_draw_diag(image, Vector2i(13, 31), Vector2i(35, 27), straw_color.lerp(wood, 0.15))
	_draw_rect(image, Rect2i(8, 28, 6, 2), wood_dark)
	_draw_rect(image, Rect2i(35, 25, 5, 2), wood_dark)
	_draw_rect(image, Rect2i(15, 32, 20, 2), dirt_dark.lerp(dirt_color, 0.35))


func _draw_diag(image: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	for step in range(steps + 1):
		var point := Vector2i(
			roundi(lerpf(from.x, to.x, float(step) / float(steps))),
			roundi(lerpf(from.y, to.y, float(step) / float(steps)))
		)
		_draw_rect(image, Rect2i(point.x, point.y, 2, 2), color)


func _draw_rect(image: Image, rect: Rect2i, color: Color) -> void:
	image.fill_rect(rect, color)


func _stable_hash(value: String) -> int:
	var result: int = 0
	for character_index in value.length():
		result = int((result * 31 + value.unicode_at(character_index)) & 0x7fffffff)
	return result
