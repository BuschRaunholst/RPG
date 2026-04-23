extends Node2D

signal impacted(target: Node, weapon_name: String, damage_value: int)
signal expired(weapon_name: String)

var direction: Vector2 = Vector2.RIGHT
var speed: float = 360.0
var max_distance: float = 160.0
var damage_value: int = 1
var weapon_name: String = ""
var hit_radius: float = 10.0
var spawn_origin: Vector2 = Vector2.ZERO
var traveled_distance: float = 0.0
var resolved: bool = false

var sprite: Sprite2D


func setup(origin: Vector2, travel_direction: Vector2, attack_distance: float, damage_amount: int, projectile_weapon_name: String) -> void:
	spawn_origin = origin
	global_position = origin
	direction = travel_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	max_distance = attack_distance
	damage_value = damage_amount
	weapon_name = projectile_weapon_name

	match weapon_name:
		"Hunter Bow":
			speed = 430.0
			hit_radius = 10.0
		"Ash Staff":
			speed = 300.0
			hit_radius = 12.0
		"Willow Wand":
			speed = 340.0
			hit_radius = 11.0
		_:
			speed = 320.0
			hit_radius = 10.0


func _ready() -> void:
	z_index = 7
	sprite = Sprite2D.new()
	sprite.texture = _build_texture()
	sprite.centered = true
	add_child(sprite)
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	var travel_step: Vector2 = direction * speed * delta
	global_position += travel_step
	traveled_distance += travel_step.length()

	var enemy: Node = _find_hit_enemy()
	if enemy != null:
		enemy.call("take_damage", damage_value, spawn_origin, true)
		resolved = true
		impacted.emit(enemy, weapon_name, damage_value)
		queue_free()
		return

	if traveled_distance >= max_distance:
		if not resolved:
			expired.emit(weapon_name)
		queue_free()


func _find_hit_enemy() -> Node:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not enemy is Node2D:
			continue
		if global_position.distance_to((enemy as Node2D).global_position) <= hit_radius:
			return enemy
	return null


func _build_texture() -> Texture2D:
	match weapon_name:
		"Hunter Bow":
			return _create_arrow_texture()
		"Ash Staff":
			return _create_orb_texture(Color(0.38, 0.78, 1.0, 1.0), Color(0.10, 0.36, 0.70, 1.0))
		"Willow Wand":
			return _create_orb_texture(Color(0.48, 1.0, 0.52, 1.0), Color(0.12, 0.52, 0.18, 1.0))
		_:
			return _create_orb_texture(Color(1.0, 1.0, 1.0, 1.0), Color(0.55, 0.55, 0.55, 1.0))


func _create_arrow_texture() -> Texture2D:
	var image: Image = Image.create(18, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var outline := Color(0.04, 0.03, 0.025, 1.0)
	var shaft := Color(0.76, 0.68, 0.42, 1.0)
	var steel := Color(0.82, 0.84, 0.86, 1.0)
	var fletch := Color(0.76, 0.22, 0.24, 1.0)
	image.fill_rect(Rect2i(2, 3, 10, 2), outline)
	image.fill_rect(Rect2i(3, 4, 8, 1), shaft)
	image.fill_rect(Rect2i(11, 2, 4, 4), outline)
	image.set_pixel(12, 3, steel)
	image.set_pixel(13, 3, steel)
	image.set_pixel(12, 4, steel)
	image.set_pixel(13, 4, steel)
	image.fill_rect(Rect2i(0, 1, 3, 3), outline)
	image.set_pixel(1, 2, fletch)
	image.set_pixel(1, 3, fletch)
	image.set_pixel(2, 2, fletch)
	image.fill_rect(Rect2i(0, 4, 3, 3), outline)
	image.set_pixel(1, 4, fletch)
	image.set_pixel(1, 5, fletch)
	image.set_pixel(2, 5, fletch)
	return ImageTexture.create_from_image(image)


func _create_orb_texture(main_color: Color, glow_color: Color) -> Texture2D:
	var image: Image = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var outline := Color(0.04, 0.03, 0.025, 0.9)
	for point in [Vector2i(4, 1), Vector2i(5, 1), Vector2i(3, 2), Vector2i(6, 2), Vector2i(2, 3), Vector2i(7, 3), Vector2i(2, 6), Vector2i(7, 6), Vector2i(3, 7), Vector2i(6, 7), Vector2i(4, 8), Vector2i(5, 8)]:
		image.set_pixelv(point, outline)
	for y in range(2, 8):
		for x in range(2, 8):
			var dist := Vector2(x - 4.5, y - 4.5).length()
			if dist <= 3.0:
				image.set_pixel(x, y, glow_color if dist > 2.0 else main_color)
	image.set_pixel(4, 3, Color(1.0, 1.0, 1.0, 0.75))
	image.set_pixel(5, 3, Color(1.0, 1.0, 1.0, 0.45))
	return ImageTexture.create_from_image(image)
