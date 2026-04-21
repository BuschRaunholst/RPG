extends "res://scripts/actors/beast_mob.gd"

@export_range(-1, 4, 1) var fur_color_index: int = -1

const SPRITE_SIZE: Vector2i = Vector2i(40, 28)
const FUR_COLORS: Array[Color] = [
	Color(0.36, 0.32, 0.27, 1.0),
	Color(0.45, 0.38, 0.30, 1.0),
	Color(0.30, 0.29, 0.28, 1.0),
	Color(0.50, 0.43, 0.35, 1.0),
	Color(0.40, 0.33, 0.38, 1.0),
]
const FUR_DARK_COLORS: Array[Color] = [
	Color(0.16, 0.14, 0.12, 1.0),
	Color(0.22, 0.17, 0.12, 1.0),
	Color(0.12, 0.12, 0.12, 1.0),
	Color(0.25, 0.18, 0.12, 1.0),
	Color(0.18, 0.13, 0.17, 1.0),
]
const EAR_COLOR: Color = Color(0.68, 0.42, 0.40, 1.0)
const TAIL_COLOR: Color = Color(0.58, 0.34, 0.34, 1.0)
const EYE_COLOR: Color = Color(0.06, 0.05, 0.04, 1.0)

var scurry_time: float = 0.0
var rat_textures: Dictionary = {}

@onready var body: Sprite2D = $Body


func _ready() -> void:
	super._ready()
	_apply_rat_visual()


func _process(delta: float) -> void:
	if body == null or defeated_state:
		return

	scurry_time += delta
	if attack_feedback_remaining > 0.0:
		return

	var scurry: float = sin(scurry_time * 8.0) * 0.02
	body.scale = Vector2(1.0 + scurry, 1.0 - scurry)


func _apply_rat_visual() -> void:
	if body == null:
		return

	var index: int = fur_color_index
	if index < 0:
		index = _stable_hash(enemy_id + enemy_name) % FUR_COLORS.size()

	_build_rat_textures(FUR_COLORS[index], FUR_DARK_COLORS[index])
	_set_rat_frame(facing_name, false)
	body.centered = true


func _on_facing_direction_changed(direction_name: String) -> void:
	_set_rat_frame(direction_name, attack_feedback_remaining > 0.0)


func _on_attack_feedback_started(direction_name: String) -> void:
	_set_rat_frame(direction_name, true)


func _on_attack_feedback_finished(direction_name: String) -> void:
	_set_rat_frame(direction_name, false)


func _build_rat_textures(fur: Color, fur_dark: Color) -> void:
	rat_textures.clear()
	for direction_name in ["right", "up", "down"]:
		rat_textures["%s_idle" % direction_name] = _create_rat_texture(fur, fur_dark, direction_name, false)
		rat_textures["%s_bite" % direction_name] = _create_rat_texture(fur, fur_dark, direction_name, true)


func _set_rat_frame(direction_name: String, is_biting: bool) -> void:
	if body == null or rat_textures.is_empty():
		return

	var texture_direction: String = direction_name
	body.flip_h = false
	if direction_name == "left":
		texture_direction = "right"
		body.flip_h = true

	var key: String = "%s_%s" % [texture_direction, "bite" if is_biting else "idle"]
	body.texture = rat_textures.get(key, rat_textures.get("%s_idle" % texture_direction, null))


func _create_rat_texture(fur: Color, fur_dark: Color, direction_name: String, is_biting: bool) -> ImageTexture:
	var image: Image = Image.create(SPRITE_SIZE.x, SPRITE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	match direction_name:
		"up":
			_draw_body_up(image, fur, fur_dark, is_biting)
		"down":
			_draw_body_down(image, fur, fur_dark, is_biting)
		_:
			_draw_tail(image, fur_dark)
			_draw_body(image, fur, fur_dark)
			_draw_face(image, is_biting)

	return ImageTexture.create_from_image(image)


func _draw_tail(image: Image, fur_dark: Color) -> void:
	_draw_diag(image, Vector2i(7, 19), Vector2i(1, 17), TAIL_COLOR.lerp(fur_dark, 0.20))
	_draw_diag(image, Vector2i(2, 17), Vector2i(0, 15), TAIL_COLOR)


func _draw_body(image: Image, fur: Color, fur_dark: Color) -> void:
	_draw_ellipse(image, Vector2i(19, 17), Vector2i(14, 8), fur)
	_draw_ellipse(image, Vector2i(28, 15), Vector2i(8, 6), fur.lerp(Color.WHITE, 0.06))
	_draw_ellipse(image, Vector2i(14, 20), Vector2i(8, 5), fur_dark.lerp(fur, 0.42))
	_draw_rect(image, Rect2i(10, 23, 20, 2), fur_dark)
	_draw_ellipse(image, Vector2i(25, 9), Vector2i(4, 5), EAR_COLOR)
	_draw_ellipse(image, Vector2i(31, 10), Vector2i(4, 4), EAR_COLOR.lerp(fur, 0.15))
	_draw_rect(image, Rect2i(26, 22, 4, 2), fur_dark)
	_draw_rect(image, Rect2i(16, 23, 4, 2), fur_dark)


func _draw_face(image: Image, is_biting: bool) -> void:
	_draw_rect(image, Rect2i(30, 14, 2, 2), EYE_COLOR)
	_draw_rect(image, Rect2i(35, 16, 2, 2), Color(0.10, 0.07, 0.06, 1.0))
	if is_biting:
		_draw_rect(image, Rect2i(34, 18, 5, 3), Color(0.12, 0.03, 0.02, 1.0))
		_draw_rect(image, Rect2i(35, 18, 1, 1), Color(0.92, 0.86, 0.68, 1.0))
		_draw_rect(image, Rect2i(37, 20, 1, 1), Color(0.92, 0.86, 0.68, 1.0))
	else:
		_draw_rect(image, Rect2i(34, 18, 3, 1), Color(0.84, 0.78, 0.64, 1.0))


func _draw_body_down(image: Image, fur: Color, fur_dark: Color, is_biting: bool) -> void:
	_draw_diag(image, Vector2i(20, 23), Vector2i(20, 27), TAIL_COLOR.lerp(fur_dark, 0.25))
	_draw_ellipse(image, Vector2i(20, 17), Vector2i(11, 8), fur)
	_draw_ellipse(image, Vector2i(20, 12), Vector2i(8, 6), fur.lerp(Color.WHITE, 0.05))
	_draw_ellipse(image, Vector2i(14, 10), Vector2i(3, 4), EAR_COLOR)
	_draw_ellipse(image, Vector2i(26, 10), Vector2i(3, 4), EAR_COLOR)
	_draw_rect(image, Rect2i(12, 22, 4, 2), fur_dark)
	_draw_rect(image, Rect2i(24, 22, 4, 2), fur_dark)
	_draw_rect(image, Rect2i(15, 14, 2, 2), EYE_COLOR)
	_draw_rect(image, Rect2i(24, 14, 2, 2), EYE_COLOR)
	if is_biting:
		_draw_rect(image, Rect2i(17, 17, 7, 4), Color(0.12, 0.03, 0.02, 1.0))
		_draw_rect(image, Rect2i(18, 17, 1, 1), Color(0.92, 0.86, 0.68, 1.0))
		_draw_rect(image, Rect2i(22, 20, 1, 1), Color(0.92, 0.86, 0.68, 1.0))
	else:
		_draw_rect(image, Rect2i(18, 18, 5, 1), Color(0.84, 0.78, 0.64, 1.0))


func _draw_body_up(image: Image, fur: Color, fur_dark: Color, is_biting: bool) -> void:
	_draw_diag(image, Vector2i(20, 7), Vector2i(20, 2), TAIL_COLOR.lerp(fur_dark, 0.25))
	_draw_ellipse(image, Vector2i(20, 17), Vector2i(11, 8), fur_dark.lerp(fur, 0.45))
	_draw_ellipse(image, Vector2i(20, 12), Vector2i(8, 6), fur)
	_draw_ellipse(image, Vector2i(14, 10), Vector2i(3, 4), EAR_COLOR.lerp(fur, 0.25))
	_draw_ellipse(image, Vector2i(26, 10), Vector2i(3, 4), EAR_COLOR.lerp(fur, 0.25))
	_draw_rect(image, Rect2i(12, 22, 4, 2), fur_dark)
	_draw_rect(image, Rect2i(24, 22, 4, 2), fur_dark)
	if is_biting:
		_draw_rect(image, Rect2i(17, 8, 7, 2), fur_dark)


func _draw_ellipse(image: Image, center: Vector2i, radius: Vector2i, color: Color) -> void:
	for y in range(center.y - radius.y, center.y + radius.y + 1):
		for x in range(center.x - radius.x, center.x + radius.x + 1):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var offset := Vector2(float(x - center.x) / float(radius.x), float(y - center.y) / float(radius.y))
			if offset.length_squared() <= 1.0:
				image.set_pixel(x, y, color)


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
