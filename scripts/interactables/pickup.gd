extends StaticBody2D

@export var pickup_id: String = "pickup"
@export var item_name: String = "Healer's Herbs"
@export var item_kind: String = "consumable"
@export var item_count: int = 1
@export var speaker_name: String = "Gathering Spot"
@export var available_message: String = "Fresh herbs grow here."
@export var interaction_outline_size: Vector2 = Vector2(38.0, 34.0)

const GLOW_COLOR: Color = Color(0.82, 0.96, 1.0, 1.0)
const GLOW_RADIUS: int = 4
const PLANT_GLOW_SIZE: Vector2i = Vector2i(52, 42)

@onready var interaction_shape: CollisionShape2D = $InteractionArea/CollisionShape2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite_root: Node2D = $SpriteRoot
@onready var interaction_glow: Sprite2D = $SpriteRoot/InteractionGlow

var is_collected: bool = false
var interaction_highlighted: bool = false
var highlight_time: float = 0.0


func _ready() -> void:
	add_to_group("pickups")
	_update_glow_texture()
	_update_visual_state()
	_update_glow_visual()


func _process(delta: float) -> void:
	if sprite_root == null:
		return

	if not interaction_highlighted or is_collected:
		sprite_root.position = Vector2.ZERO
		sprite_root.scale = Vector2.ONE
		sprite_root.modulate = Color.WHITE
		_update_glow_visual()
		return

	highlight_time += delta
	var glow: float = 0.32 + sin(highlight_time * 2.8) * 0.08
	sprite_root.position = Vector2.ZERO
	sprite_root.scale = Vector2.ONE
	sprite_root.modulate = Color.WHITE
	if interaction_glow != null:
		interaction_glow.visible = true
		interaction_glow.modulate = Color(1.0, 1.0, 1.0, glow)


func get_dialogue_lines() -> PackedStringArray:
	if is_collected:
		return PackedStringArray(["There is nothing left to gather here."])

	return PackedStringArray([available_message])


func collect_pickup() -> Dictionary:
	if is_collected:
		return {}

	is_collected = true
	_update_visual_state()
	return {
		"id": pickup_id,
		"name": item_name,
		"kind": item_kind,
		"count": maxi(1, item_count)
	}


func set_collected(value: bool) -> void:
	is_collected = value
	_update_visual_state()


func set_interaction_highlight(value: bool) -> void:
	interaction_highlighted = value and not is_collected
	_update_glow_visual()
	if not interaction_highlighted and sprite_root != null:
		sprite_root.position = Vector2.ZERO
		sprite_root.scale = Vector2.ONE
		sprite_root.modulate = Color.WHITE


func _update_glow_visual() -> void:
	if interaction_glow == null:
		return

	interaction_glow.visible = interaction_highlighted and not is_collected
	interaction_glow.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _update_glow_texture() -> void:
	if interaction_glow == null:
		return

	interaction_glow.texture = _create_alpha_glow_texture(_create_plant_glow_source(), GLOW_RADIUS)


func _update_visual_state() -> void:
	visible = not is_collected
	input_pickable = not is_collected
	if collision_shape != null:
		collision_shape.disabled = is_collected
	if interaction_shape != null:
		interaction_shape.disabled = is_collected
	if sprite_root != null:
		sprite_root.visible = not is_collected
	set_interaction_highlight(interaction_highlighted)


func _create_plant_glow_source() -> Image:
	var source: Image = Image.create(PLANT_GLOW_SIZE.x, PLANT_GLOW_SIZE.y, false, Image.FORMAT_RGBA8)
	source.fill(Color(0.0, 0.0, 0.0, 0.0))
	_draw_rect(source, Rect2i(25, 10, 4, 26), Color.WHITE)
	_draw_rect(source, Rect2i(8, 18, 20, 9), Color.WHITE)
	_draw_rect(source, Rect2i(24, 16, 20, 9), Color.WHITE)
	_draw_rect(source, Rect2i(12, 26, 28, 10), Color.WHITE)
	return source


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
