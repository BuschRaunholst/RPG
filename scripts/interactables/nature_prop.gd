extends StaticBody2D

@export_enum("flower_patch", "bush", "sapling", "grass_clump", "tree", "forest_wall") var prop_kind: String = "bush"
@export_range(-1, 4, 1) var color_index: int = -1
@export var blocks_player: bool = false

const SPRITE_SIZE: Vector2i = Vector2i(56, 48)
const TREE_SPRITE_SIZE: Vector2i = Vector2i(96, 120)
const FOREST_WALL_SPRITE_SIZE: Vector2i = Vector2i(192, 136)
const LEAF_COLORS: Array[Color] = [
	Color(0.34, 0.66, 0.30, 1.0),
	Color(0.25, 0.56, 0.28, 1.0),
	Color(0.45, 0.71, 0.31, 1.0),
	Color(0.29, 0.63, 0.43, 1.0),
	Color(0.52, 0.69, 0.26, 1.0),
]
const LEAF_DARK_COLORS: Array[Color] = [
	Color(0.15, 0.34, 0.14, 1.0),
	Color(0.11, 0.29, 0.15, 1.0),
	Color(0.23, 0.39, 0.14, 1.0),
	Color(0.12, 0.32, 0.24, 1.0),
	Color(0.25, 0.34, 0.10, 1.0),
]
const FLOWER_COLORS: Array[Color] = [
	Color(0.96, 0.55, 0.74, 1.0),
	Color(0.94, 0.86, 0.34, 1.0),
	Color(0.72, 0.58, 0.96, 1.0),
	Color(0.96, 0.72, 0.42, 1.0),
	Color(0.95, 0.95, 0.82, 1.0),
]
const TRUNK_COLOR: Color = Color(0.39, 0.24, 0.13, 1.0)
const TRUNK_DARK_COLOR: Color = Color(0.20, 0.12, 0.07, 1.0)

@onready var body: Sprite2D = $Body
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if collision_shape != null and collision_shape.shape != null:
		collision_shape.shape = collision_shape.shape.duplicate()
	_apply_visual()
	if collision_shape != null:
		collision_shape.disabled = not blocks_player


func _apply_visual() -> void:
	if body == null:
		return

	var palette_index: int = color_index
	if palette_index < 0:
		palette_index = _stable_hash(name + prop_kind) % LEAF_COLORS.size()

	body.texture = _create_nature_texture(
		prop_kind,
		LEAF_COLORS[palette_index],
		LEAF_DARK_COLORS[palette_index],
		FLOWER_COLORS[palette_index]
	)
	body.position = _get_body_offset()

	if collision_shape != null:
		if prop_kind == "forest_wall":
			var wall_shape := RectangleShape2D.new()
			wall_shape.size = Vector2(174.0, 104.0)
			collision_shape.shape = wall_shape
			collision_shape.position = Vector2(0, -48)
		elif collision_shape.shape is CircleShape2D:
			var circle_shape: CircleShape2D = collision_shape.shape
			circle_shape.radius = 22.0 if prop_kind == "tree" else 18.0
			collision_shape.position = Vector2(0, 8)


func _create_nature_texture(kind: String, leaf: Color, leaf_dark: Color, flower: Color) -> ImageTexture:
	var texture_size: Vector2i = _get_texture_size(kind)
	var image: Image = Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	match kind:
		"flower_patch":
			_draw_flower_patch(image, leaf, leaf_dark, flower)
		"sapling":
			_draw_sapling(image, leaf, leaf_dark)
		"grass_clump":
			_draw_grass_clump(image, leaf, leaf_dark)
		"tree":
			_draw_tree(image, leaf, leaf_dark)
		"forest_wall":
			_draw_forest_wall(image, leaf, leaf_dark)
		_:
			_draw_bush(image, leaf, leaf_dark, flower)

	return ImageTexture.create_from_image(image)


func _get_texture_size(kind: String) -> Vector2i:
	if kind == "forest_wall":
		return FOREST_WALL_SPRITE_SIZE
	if kind == "tree":
		return TREE_SPRITE_SIZE
	return SPRITE_SIZE


func _get_body_offset() -> Vector2:
	if prop_kind == "forest_wall":
		return Vector2(0, -64)
	if prop_kind == "tree":
		return Vector2(0, -56)
	return Vector2(0, -8)


func _draw_bush(image: Image, leaf: Color, leaf_dark: Color, flower: Color) -> void:
	_draw_shadow(image, Rect2i(11, 34, 34, 6))
	_draw_leaf_blob(image, Vector2i(15, 25), 10, leaf_dark.lerp(leaf, 0.35))
	_draw_leaf_blob(image, Vector2i(27, 20), 14, leaf)
	_draw_leaf_blob(image, Vector2i(39, 27), 10, leaf_dark.lerp(leaf, 0.50))
	_draw_leaf_blob(image, Vector2i(26, 31), 13, leaf_dark.lerp(leaf, 0.70))
	_draw_rect(image, Rect2i(21, 17, 7, 2), leaf.lerp(Color.WHITE, 0.20))
	_draw_rect(image, Rect2i(36, 24, 3, 3), flower)
	_draw_rect(image, Rect2i(17, 28, 3, 3), flower)


func _draw_flower_patch(image: Image, leaf: Color, leaf_dark: Color, flower: Color) -> void:
	_draw_shadow(image, Rect2i(13, 34, 30, 4))
	for point in [Vector2i(18, 31), Vector2i(25, 28), Vector2i(32, 30), Vector2i(39, 32), Vector2i(28, 35)]:
		_draw_rect(image, Rect2i(point.x, point.y, 10, 2), leaf_dark.lerp(leaf, 0.50))
		_draw_rect(image, Rect2i(point.x + 3, point.y - 7, 2, 8), leaf)
		_draw_rect(image, Rect2i(point.x + 1, point.y - 9, 5, 4), flower)


func _draw_sapling(image: Image, leaf: Color, leaf_dark: Color) -> void:
	_draw_shadow(image, Rect2i(16, 38, 24, 5))
	_draw_rect(image, Rect2i(26, 22, 5, 18), TRUNK_COLOR)
	_draw_rect(image, Rect2i(29, 23, 2, 17), TRUNK_DARK_COLOR)
	_draw_leaf_blob(image, Vector2i(19, 20), 10, leaf_dark.lerp(leaf, 0.40))
	_draw_leaf_blob(image, Vector2i(29, 14), 13, leaf)
	_draw_leaf_blob(image, Vector2i(38, 21), 10, leaf_dark.lerp(leaf, 0.55))
	_draw_rect(image, Rect2i(25, 10, 7, 2), leaf.lerp(Color.WHITE, 0.18))


func _draw_grass_clump(image: Image, leaf: Color, leaf_dark: Color) -> void:
	_draw_shadow(image, Rect2i(15, 36, 26, 3))
	for index in range(7):
		var x: int = 17 + index * 4
		var height: int = 7 + (index % 3) * 3
		_draw_diag(image, Vector2i(x, 36), Vector2i(x - 3, 36 - height), leaf_dark.lerp(leaf, 0.30))
		_draw_diag(image, Vector2i(x + 1, 36), Vector2i(x + 4, 35 - height), leaf)


func _draw_tree(image: Image, leaf: Color, leaf_dark: Color) -> void:
	_draw_tree_at(image, Vector2i.ZERO, leaf, leaf_dark)


func _draw_forest_wall(image: Image, leaf: Color, leaf_dark: Color) -> void:
	var muted_leaf: Color = leaf_dark.lerp(leaf, 0.45)
	_draw_tree_at(image, Vector2i(-4, 14), muted_leaf, leaf_dark)
	_draw_tree_at(image, Vector2i(46, 2), leaf, leaf_dark.lerp(leaf, 0.18))
	_draw_tree_at(image, Vector2i(96, 12), leaf_dark.lerp(leaf, 0.58), leaf_dark)
	_draw_leaf_blob(image, Vector2i(84, 24), 16, leaf.lerp(Color(0.92, 0.98, 0.74, 1.0), 0.18))
	_draw_leaf_blob(image, Vector2i(119, 45), 14, leaf_dark.lerp(leaf, 0.65))


func _draw_tree_at(image: Image, origin: Vector2i, leaf: Color, leaf_dark: Color) -> void:
	var leaf_mid: Color = leaf_dark.lerp(leaf, 0.55)
	var leaf_light: Color = leaf.lerp(Color(0.92, 0.98, 0.74, 1.0), 0.34)
	var bark_light: Color = TRUNK_COLOR.lerp(Color(0.74, 0.50, 0.25, 1.0), 0.38)

	_draw_shadow(image, _offset_rect(Rect2i(20, 102, 56, 8), origin))

	_draw_rect(image, _offset_rect(Rect2i(42, 68, 17, 39), origin), TRUNK_COLOR)
	_draw_rect(image, _offset_rect(Rect2i(53, 70, 5, 36), origin), TRUNK_DARK_COLOR)
	_draw_rect(image, _offset_rect(Rect2i(45, 72, 4, 30), origin), bark_light)
	_draw_rect(image, _offset_rect(Rect2i(34, 99, 16, 6), origin), TRUNK_COLOR)
	_draw_rect(image, _offset_rect(Rect2i(56, 98, 17, 6), origin), TRUNK_DARK_COLOR.lerp(TRUNK_COLOR, 0.45))
	_draw_rect(image, _offset_rect(Rect2i(40, 87, 5, 2), origin), TRUNK_DARK_COLOR)
	_draw_rect(image, _offset_rect(Rect2i(51, 78, 4, 2), origin), bark_light)
	_draw_rect(image, _offset_rect(Rect2i(46, 96, 4, 2), origin), bark_light)

	_draw_leaf_blob(image, origin + Vector2i(31, 48), 24, leaf_dark)
	_draw_leaf_blob(image, origin + Vector2i(48, 31), 28, leaf_mid)
	_draw_leaf_blob(image, origin + Vector2i(65, 45), 24, leaf)
	_draw_leaf_blob(image, origin + Vector2i(43, 62), 27, leaf_mid)
	_draw_leaf_blob(image, origin + Vector2i(62, 65), 22, leaf_dark.lerp(leaf, 0.45))
	_draw_leaf_blob(image, origin + Vector2i(48, 48), 28, leaf)
	_draw_leaf_blob(image, origin + Vector2i(26, 62), 15, leaf_dark.lerp(leaf, 0.30))
	_draw_leaf_blob(image, origin + Vector2i(75, 58), 15, leaf_dark.lerp(leaf, 0.42))

	_draw_rect(image, _offset_rect(Rect2i(34, 19, 16, 3), origin), leaf_light)
	_draw_rect(image, _offset_rect(Rect2i(22, 42, 13, 3), origin), leaf_light.lerp(leaf, 0.25))
	_draw_rect(image, _offset_rect(Rect2i(57, 28, 17, 3), origin), leaf_light)
	_draw_rect(image, _offset_rect(Rect2i(50, 58, 18, 3), origin), leaf_light.lerp(leaf, 0.16))
	_draw_rect(image, _offset_rect(Rect2i(25, 73, 12, 3), origin), leaf_dark)
	_draw_rect(image, _offset_rect(Rect2i(67, 74, 13, 3), origin), leaf_dark)

	for point in [Vector2i(39, 42), Vector2i(55, 34), Vector2i(70, 52), Vector2i(44, 70), Vector2i(25, 55)]:
		_draw_rect(image, _offset_rect(Rect2i(point.x, point.y, 4, 4), origin), leaf_light.lerp(leaf, 0.2))


func _offset_rect(rect: Rect2i, offset: Vector2i) -> Rect2i:
	return Rect2i(rect.position + offset, rect.size)


func _draw_leaf_blob(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var offset := Vector2(float(x - center.x) / float(radius), float(y - center.y) / float(radius))
			if offset.length_squared() <= 1.0:
				image.set_pixel(x, y, color)


func _draw_shadow(image: Image, rect: Rect2i) -> void:
	_draw_rect(image, rect, Color(0.0, 0.0, 0.0, 0.14))


func _draw_diag(image: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	for step in range(steps + 1):
		var point := Vector2i(
			roundi(lerpf(from.x, to.x, float(step) / float(steps))),
			roundi(lerpf(from.y, to.y, float(step) / float(steps)))
		)
		_draw_rect(image, Rect2i(point.x, point.y, 2, 2), color)


func _draw_rect(image: Image, rect: Rect2i, color: Color) -> void:
	var clipped_rect := rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if clipped_rect.size.x <= 0 or clipped_rect.size.y <= 0:
		return
	image.fill_rect(clipped_rect, color)


func _stable_hash(value: String) -> int:
	var result: int = 0
	for character_index in value.length():
		result = int((result * 31 + value.unicode_at(character_index)) & 0x7fffffff)
	return result
