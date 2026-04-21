extends "res://scripts/interactables/pickup.gd"

@export_enum("jelly", "gold", "bag", "potion") var loot_visual: String = "jelly"

const SPRITE_SIZE: Vector2i = Vector2i(40, 34)
const JELLY_COLOR: Color = Color(0.46, 0.82, 0.52, 1.0)
const JELLY_DARK_COLOR: Color = Color(0.16, 0.38, 0.20, 1.0)
const JELLY_HIGHLIGHT: Color = Color(0.80, 1.00, 0.70, 0.82)
const GOLD_COLOR: Color = Color(0.96, 0.76, 0.22, 1.0)
const GOLD_DARK_COLOR: Color = Color(0.48, 0.32, 0.10, 1.0)
const BAG_COLOR: Color = Color(0.62, 0.43, 0.24, 1.0)
const BAG_DARK_COLOR: Color = Color(0.28, 0.17, 0.09, 1.0)

@onready var body: Sprite2D = $SpriteRoot/Body


func _ready() -> void:
	add_to_group("dropped_loot")
	_apply_loot_visual()
	super._ready()


func _apply_loot_visual() -> void:
	if body == null:
		return

	body.texture = _create_loot_texture(loot_visual)
	_update_glow_texture()


func _update_glow_texture() -> void:
	if interaction_glow == null or body == null or body.texture == null:
		return

	interaction_glow.texture = _create_alpha_glow_texture(body.texture.get_image(), GLOW_RADIUS)


func _create_loot_texture(kind: String) -> ImageTexture:
	var image: Image = Image.create(SPRITE_SIZE.x, SPRITE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	match kind:
		"gold":
			_draw_gold(image)
		"bag":
			_draw_bag(image)
		"potion":
			_draw_potion(image)
		_:
			_draw_jelly(image)

	return ImageTexture.create_from_image(image)


func _draw_jelly(image: Image) -> void:
	_draw_rect(image, Rect2i(11, 24, 20, 4), Color(0.0, 0.0, 0.0, 0.16))
	for y in range(9, 26):
		for x in range(8, 33):
			var centered_x: float = (float(x) - 20.0) / 12.0
			var centered_y: float = (float(y) - 18.0) / 8.0
			if centered_x * centered_x + centered_y * centered_y <= 1.0:
				var shade: Color = JELLY_COLOR
				if y > 21 or x < 11 or x > 29:
					shade = JELLY_DARK_COLOR.lerp(JELLY_COLOR, 0.46)
				image.set_pixel(x, y, shade)
	_draw_rect(image, Rect2i(14, 12, 7, 2), JELLY_HIGHLIGHT)
	_draw_rect(image, Rect2i(13, 14, 4, 1), JELLY_HIGHLIGHT)


func _draw_gold(image: Image) -> void:
	_draw_rect(image, Rect2i(10, 24, 22, 4), Color(0.0, 0.0, 0.0, 0.14))
	_draw_coin(image, Vector2i(13, 17))
	_draw_coin(image, Vector2i(20, 13))
	_draw_coin(image, Vector2i(24, 19))


func _draw_coin(image: Image, origin: Vector2i) -> void:
	_draw_rect(image, Rect2i(origin.x, origin.y + 3, 9, 5), GOLD_DARK_COLOR)
	_draw_rect(image, Rect2i(origin.x + 1, origin.y, 7, 7), GOLD_COLOR)
	_draw_rect(image, Rect2i(origin.x + 2, origin.y + 1, 4, 1), GOLD_COLOR.lerp(Color.WHITE, 0.35))


func _draw_bag(image: Image) -> void:
	_draw_rect(image, Rect2i(10, 25, 20, 4), Color(0.0, 0.0, 0.0, 0.16))
	_draw_rect(image, Rect2i(13, 14, 16, 13), BAG_COLOR)
	_draw_rect(image, Rect2i(11, 18, 20, 8), BAG_COLOR)
	_draw_rect(image, Rect2i(13, 24, 16, 3), BAG_DARK_COLOR)
	_draw_rect(image, Rect2i(17, 10, 8, 5), BAG_DARK_COLOR)
	_draw_rect(image, Rect2i(15, 15, 12, 2), BAG_DARK_COLOR.lerp(BAG_COLOR, 0.20))


func _draw_potion(image: Image) -> void:
	_draw_rect(image, Rect2i(12, 26, 18, 4), Color(0.0, 0.0, 0.0, 0.16))
	_draw_rect(image, Rect2i(17, 8, 8, 5), Color(0.30, 0.20, 0.12, 1.0))
	_draw_rect(image, Rect2i(15, 13, 12, 3), Color(0.86, 0.82, 0.62, 1.0))
	_draw_rect(image, Rect2i(13, 16, 16, 12), Color(0.28, 0.52, 0.72, 0.92))
	_draw_rect(image, Rect2i(15, 18, 12, 9), Color(0.48, 0.76, 0.94, 0.96))
	_draw_rect(image, Rect2i(17, 18, 4, 2), Color(0.88, 0.97, 1.0, 0.75))


func _draw_rect(image: Image, rect: Rect2i, color: Color) -> void:
	image.fill_rect(rect, color)
