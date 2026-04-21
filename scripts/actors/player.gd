extends CharacterBody2D

@export var move_speed: float = 180.0
@export var attack_range: float = 58.0
@export var attack_cooldown: float = 0.35

signal interacted(target: Node)
signal attack_requested(origin: Vector2, direction: Vector2, attack_distance: float)
signal context_action_requested

@onready var body: AnimatedSprite2D = $Body
@onready var clothing_layer: AnimatedSprite2D = $ClothingLayer
@onready var boots_layer: AnimatedSprite2D = $BootsLayer
@onready var left_arm_pivot: Node2D = $LeftArmPivot
@onready var left_arm_sprite: Sprite2D = $LeftArmPivot/LeftArmSprite
@onready var shield_socket: Node2D = $LeftArmPivot/ShieldSocket
@onready var shield_pivot: Node2D = $LeftArmPivot/ShieldSocket/ShieldPivot
@onready var shield_sprite: Sprite2D = $LeftArmPivot/ShieldSocket/ShieldPivot/ShieldSprite
@onready var back_shield_pivot: Node2D = $BackShieldPivot
@onready var back_shield_sprite: Sprite2D = $BackShieldPivot/BackShieldSprite
@onready var right_arm_pivot: Node2D = $RightArmPivot
@onready var right_arm_sprite: Sprite2D = $RightArmPivot/RightArmSprite
@onready var weapon_socket: Node2D = $RightArmPivot/WeaponSocket
@onready var weapon_pivot: Node2D = $RightArmPivot/WeaponSocket/WeaponPivot
@onready var weapon_sprite: Sprite2D = $RightArmPivot/WeaponSocket/WeaponPivot/WeaponSprite

const TUNIC_FRAMES = preload("res://assets/art/characters/player_clothes_village_tunic_4dir_64_frames.tres")
const BOOTS_FRAMES = preload("res://assets/art/characters/player_boots_worn_4dir_64_frames.tres")
const ARM_SKIN_DARK := Color(0.48, 0.30, 0.20, 1.0)
const ARM_SKIN := Color(0.66, 0.43, 0.28, 1.0)
const ARM_TUNIC_DARK := Color(0.17, 0.20, 0.16, 1.0)

var can_move: bool = true
var nearby_interactable: Node = null
var tap_interaction_range: float = 56.0
var facing_direction: Vector2 = Vector2.DOWN
var attack_cooldown_remaining: float = 0.0
var attack_feedback_remaining: float = 0.0
var hurt_feedback_remaining: float = 0.0
var body_base_position: Vector2 = Vector2.ZERO
var highlighted_interactable: Node = null
var animated_layers: Array[AnimatedSprite2D] = []
var equipped_weapon_name: String = ""
var equipped_offhand_name: String = ""
var equipped_body_name: String = ""
var weapon_textures: Dictionary = {}
var shield_textures: Dictionary = {}
var arm_texture: Texture2D


func _ready() -> void:
	body_base_position = body.position
	animated_layers = [body, clothing_layer, boots_layer]
	body.z_index = 2
	clothing_layer.z_index = 2
	boots_layer.z_index = 2
	back_shield_pivot.z_index = 1
	_build_weapon_textures()
	_build_shield_textures()
	arm_texture = _create_arm_texture(ARM_TUNIC_DARK)
	left_arm_sprite.texture = arm_texture
	right_arm_sprite.texture = arm_texture
	left_arm_sprite.offset = Vector2(-3.0, 0.0)
	right_arm_sprite.offset = Vector2(-3.0, 0.0)
	_update_weapon_visual()


func _physics_process(delta: float) -> void:
	if attack_cooldown_remaining > 0.0:
		attack_cooldown_remaining = maxf(0.0, attack_cooldown_remaining - delta)
	if attack_feedback_remaining > 0.0:
		attack_feedback_remaining = maxf(0.0, attack_feedback_remaining - delta)
	if hurt_feedback_remaining > 0.0:
		hurt_feedback_remaining = maxf(0.0, hurt_feedback_remaining - delta)
	_update_feedback_visuals()

	if Input.is_action_just_pressed("interact"):
		context_action_requested.emit()

	if Input.is_action_just_pressed("attack"):
		try_attack()

	if not can_move:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_vector.length() > 0.0:
		facing_direction = input_vector.normalized()

	velocity = input_vector * move_speed
	_update_animation(input_vector)
	move_and_slide()


func set_can_move(value: bool) -> void:
	can_move = value

	if not can_move:
		velocity = Vector2.ZERO


func _on_interaction_detector_area_entered(area: Area2D) -> void:
	_set_nearby_interactable(area.get_parent())


func _on_interaction_detector_area_exited(area: Area2D) -> void:
	if nearby_interactable == area.get_parent():
		_set_nearby_interactable(null)


func can_interact_with(target: Node) -> bool:
	if target == nearby_interactable:
		return true

	if target is Node2D:
		return global_position.distance_to(target.global_position) <= tap_interaction_range

	return false


func get_nearby_interactable() -> Node:
	return nearby_interactable


func _set_nearby_interactable(target: Node) -> void:
	if highlighted_interactable != null and highlighted_interactable.has_method("set_interaction_highlight"):
		highlighted_interactable.call("set_interaction_highlight", false)

	nearby_interactable = target
	highlighted_interactable = target

	if highlighted_interactable != null and highlighted_interactable.has_method("set_interaction_highlight"):
		highlighted_interactable.call("set_interaction_highlight", true)


func try_interact() -> bool:
	if nearby_interactable == null:
		return false

	interacted.emit(nearby_interactable)
	return true


func can_attack_now() -> bool:
	return can_move and attack_cooldown_remaining <= 0.0


func try_attack() -> bool:
	if not can_attack_now():
		return false

	attack_cooldown_remaining = attack_cooldown
	attack_feedback_remaining = 0.12
	attack_requested.emit(global_position, facing_direction, attack_range)
	return true


func show_hurt_feedback() -> void:
	hurt_feedback_remaining = 0.16
	_update_feedback_visuals()


func set_equipment_visuals(equipment_slots: Dictionary) -> void:
	var weapon_item: Dictionary = equipment_slots.get("weapon", {})
	var offhand_item: Dictionary = equipment_slots.get("offhand", {})
	var body_item: Dictionary = equipment_slots.get("body", {})
	var boots_item: Dictionary = equipment_slots.get("boots", {})
	equipped_weapon_name = str(weapon_item.get("name", ""))
	equipped_offhand_name = str(offhand_item.get("name", ""))
	var body_name: String = str(body_item.get("name", ""))
	equipped_body_name = body_name
	var boots_name: String = str(boots_item.get("name", ""))

	clothing_layer.visible = body_name == "Village Tunic"
	if clothing_layer.visible:
		clothing_layer.sprite_frames = TUNIC_FRAMES

	boots_layer.visible = boots_name == "Worn Boots"
	if boots_layer.visible:
		boots_layer.sprite_frames = BOOTS_FRAMES

	_update_attack_arm_texture()
	_update_weapon_visual()
	_sync_layer_animation(body.animation)


func _update_animation(input_vector: Vector2) -> void:
	var direction_name := _get_animation_direction_name()
	var animation_name := "walk_%s" % direction_name if input_vector.length() > 0.0 else "idle_%s" % direction_name

	if body.animation != animation_name:
		_sync_layer_animation(animation_name)


func _get_animation_direction_name() -> String:
	if absf(facing_direction.x) > absf(facing_direction.y):
		return "left" if facing_direction.x < 0.0 else "right"

	return "up" if facing_direction.y < 0.0 else "down"


func _update_feedback_visuals() -> void:
	var attack_progress: float = attack_feedback_remaining / 0.12 if attack_feedback_remaining > 0.0 else 0.0
	var attack_offset: Vector2 = facing_direction.normalized() * (sin(attack_progress * PI) * 5.0)
	for layer in animated_layers:
		if layer == null:
			continue
		layer.position = body_base_position + attack_offset

	if hurt_feedback_remaining > 0.0:
		for layer in animated_layers:
			if layer != null:
				layer.modulate = Color(1.0, 0.68, 0.68, 1.0)
	else:
		for layer in animated_layers:
			if layer != null:
				layer.modulate = Color(1.0, 1.0, 1.0, 1.0)

	_update_weapon_pose(attack_progress, attack_offset)


func _sync_layer_animation(animation_name: StringName) -> void:
	for layer in animated_layers:
		if layer == null or layer.sprite_frames == null:
			continue
		if not layer.sprite_frames.has_animation(animation_name):
			continue
		if layer.animation != animation_name:
			layer.play(animation_name)


func _build_weapon_textures() -> void:
	weapon_textures["Traveler Knife"] = _create_knife_texture()


func _build_shield_textures() -> void:
	shield_textures["Oak Buckler"] = _create_oak_buckler_texture()
	shield_textures["Oak Buckler Edge"] = _create_oak_buckler_edge_texture()


func _update_weapon_visual() -> void:
	if right_arm_pivot == null or left_arm_pivot == null or weapon_sprite == null or shield_sprite == null or back_shield_sprite == null:
		return

	if equipped_weapon_name.is_empty() or not weapon_textures.has(equipped_weapon_name):
		right_arm_pivot.visible = true
		left_arm_pivot.visible = true
		weapon_sprite.visible = false
	else:
		weapon_sprite.texture = weapon_textures[equipped_weapon_name]
		weapon_sprite.visible = true

	if equipped_offhand_name.is_empty() or not shield_textures.has(equipped_offhand_name):
		shield_sprite.visible = false
		back_shield_sprite.visible = false
	else:
		shield_sprite.texture = shield_textures[equipped_offhand_name]
		back_shield_sprite.texture = shield_textures[equipped_offhand_name]
		shield_sprite.visible = true

	right_arm_pivot.visible = true
	left_arm_pivot.visible = true
	_update_weapon_pose(0.0, Vector2.ZERO)


func _update_weapon_pose(attack_progress: float, attack_offset: Vector2) -> void:
	if left_arm_pivot == null or right_arm_pivot == null or weapon_socket == null or weapon_pivot == null or weapon_sprite == null or shield_socket == null or shield_pivot == null or shield_sprite == null or back_shield_pivot == null or back_shield_sprite == null:
		return

	var direction_name: String = _get_animation_direction_name()
	var has_weapon: bool = not equipped_weapon_name.is_empty() and weapon_textures.has(equipped_weapon_name)
	var has_shield: bool = not equipped_offhand_name.is_empty() and shield_textures.has(equipped_offhand_name)
	var weapon_profile: Dictionary = _get_weapon_visual_profile(equipped_weapon_name)
	var right_pose: Dictionary = _get_right_arm_pose(direction_name)
	var left_pose: Dictionary = _get_left_arm_pose(direction_name)
	var is_attacking: bool = attack_progress > 0.0
	var attack_phase: float = clampf(1.0 - attack_progress, 0.0, 1.0) if attack_progress > 0.0 else 0.0
	var swing_degrees: float = 0.0
	if is_attacking:
		swing_degrees = lerpf(float(right_pose.get("windup_degrees", -25.0)), float(right_pose.get("follow_degrees", 35.0)), _smooth_attack_phase(attack_phase)) * 1.3

	var show_left_arm: bool = _should_show_left_arm(direction_name, is_attacking)
	var show_front_shield: bool = has_shield and _should_show_front_shield(direction_name)
	var show_back_shield: bool = has_shield and _should_show_back_shield(direction_name)
	left_arm_pivot.visible = show_left_arm or show_front_shield
	left_arm_pivot.position = (left_pose.get("shoulder", Vector2.ZERO) as Vector2) + attack_offset
	left_arm_pivot.rotation = deg_to_rad(float(left_pose.get("arm_degrees", 0.0)))
	left_arm_pivot.z_index = int(left_pose.get("z_index", 4))
	left_arm_sprite.visible = show_left_arm
	left_arm_sprite.flip_h = false
	shield_sprite.visible = show_front_shield
	if show_front_shield:
		shield_sprite.texture = _get_shield_texture(direction_name)
	shield_socket.position = left_pose.get("shield_socket", Vector2(0.0, 16.0)) as Vector2
	shield_pivot.position = Vector2.ZERO
	shield_pivot.rotation = deg_to_rad(float(left_pose.get("shield_degrees", 0.0)))
	shield_sprite.offset = left_pose.get("shield_offset", Vector2(-7.0, -8.0)) as Vector2
	shield_sprite.z_index = 0
	back_shield_pivot.visible = show_back_shield
	back_shield_sprite.visible = show_back_shield
	if show_back_shield:
		back_shield_sprite.texture = shield_textures.get("Oak Buckler", null)
	var back_shield_pose: Dictionary = _get_back_shield_pose(direction_name)
	back_shield_pivot.position = (back_shield_pose.get("position", Vector2.ZERO) as Vector2) + attack_offset
	back_shield_pivot.rotation = deg_to_rad(float(back_shield_pose.get("degrees", 0.0)))
	back_shield_pivot.z_index = int(back_shield_pose.get("z_index", -1))
	back_shield_sprite.offset = back_shield_pose.get("offset", Vector2(-8.0, -9.0)) as Vector2

	var show_right_arm: bool = _should_show_right_arm(direction_name, is_attacking)
	var show_weapon: bool = has_weapon and _should_show_right_weapon(direction_name, is_attacking)
	right_arm_pivot.visible = show_right_arm or show_weapon
	right_arm_pivot.position = (right_pose.get("shoulder", Vector2.ZERO) as Vector2) + attack_offset
	right_arm_pivot.rotation = deg_to_rad(float(right_pose.get("arm_degrees", 0.0)) + swing_degrees)
	right_arm_pivot.z_index = -1 if show_weapon and not show_right_arm else int(right_pose.get("z_index", 5))
	right_arm_sprite.visible = show_right_arm
	right_arm_sprite.flip_h = false

	weapon_sprite.visible = show_weapon
	weapon_socket.position = right_pose.get("socket", weapon_profile.get("socket", Vector2(0.0, 17.0))) as Vector2
	weapon_pivot.position = Vector2.ZERO
	weapon_pivot.rotation = deg_to_rad(float(right_pose.get("weapon_degrees", weapon_profile.get("rotation_degrees", 0.0))))
	weapon_sprite.flip_h = bool(right_pose.get("weapon_flip_h", weapon_profile.get("flip_h", false)))


func _get_right_arm_pose(direction_name: String) -> Dictionary:
	match direction_name:
		"left":
			return {
				"shoulder": Vector2(2.0, -18.0),
				"socket": Vector2(0.0, 13.0),
				"arm_degrees": 0.0,
				"windup_degrees": 76.0,
				"follow_degrees": -22.0,
				"weapon_degrees": 180.0,
				"z_index": 5
			}
		"right":
			return {
				"shoulder": Vector2(3.0, -18.0),
				"socket": Vector2(0.0, 17.0),
				"arm_degrees": 0.0,
				"windup_degrees": -76.0,
				"follow_degrees": 22.0,
				"weapon_degrees": 0.0,
				"z_index": 5
			}
		"up":
			return {
				"shoulder": Vector2(8.0, -18.0),
				"socket": Vector2(0.0, 17.0),
				"arm_degrees": 0.0,
				"windup_degrees": -34.0,
				"follow_degrees": 18.0,
				"weapon_degrees": -12.0,
				"z_index": 3
			}
		_:
			return {
				"shoulder": Vector2(-10.0, -19.0),
				"socket": Vector2(0.0, 16.0),
				"arm_degrees": 0.0,
				"windup_degrees": 58.0,
				"follow_degrees": -30.0,
				"weapon_degrees": 180.0,
				"z_index": 5
			}


func _get_left_arm_pose(direction_name: String) -> Dictionary:
	match direction_name:
		"left":
			return {
				"shoulder": Vector2(-5.0, -18.0),
				"arm_degrees": 0.0,
				"shield_socket": Vector2(0.0, 13.0),
				"shield_degrees": 3.0,
				"shield_offset": Vector2(-3.0, -9.0),
				"z_index": 4
			}
		"right":
			return {
				"shoulder": Vector2(2.0, -18.0),
				"arm_degrees": 0.0,
				"shield_socket": Vector2(0.0, 13.0),
				"shield_degrees": 0.0,
				"shield_offset": Vector2(-13.0, -9.0),
				"z_index": 4
			}
		"up":
			return {
				"shoulder": Vector2(-8.0, -18.0),
				"arm_degrees": 0.0,
				"shield_socket": Vector2(0.0, 11.0),
				"shield_degrees": -8.0,
				"shield_offset": Vector2(-9.0, -9.0),
				"z_index": 3
			}
		_:
			return {
				"shoulder": Vector2(10.0, -19.0),
				"arm_degrees": 0.0,
				"shield_socket": Vector2(0.0, 14.0),
				"shield_degrees": 0.0,
				"shield_offset": Vector2(-5.0, -9.0),
				"z_index": 5
			}


func _should_show_left_arm(direction_name: String, is_attacking: bool) -> bool:
	if direction_name == "right":
		return false
	if direction_name == "left":
		return not is_attacking
	return true


func _should_show_front_shield(direction_name: String) -> bool:
	return direction_name == "left" or direction_name == "down"


func _should_show_back_shield(direction_name: String) -> bool:
	return direction_name == "right" or direction_name == "up"


func _get_back_shield_pose(direction_name: String) -> Dictionary:
	match direction_name:
		"right":
			return {
				"position": Vector2(-5.0, -6.0),
				"offset": Vector2(-7.0, -10.0),
				"degrees": 0.0,
				"z_index": 1
			}
		"up":
			return {
				"position": Vector2(-8.0, -7.0),
				"offset": Vector2(-8.0, -10.0),
				"degrees": -8.0,
				"z_index": 1
			}
		_:
			return {
				"position": Vector2(6.0, -5.0),
				"offset": Vector2(-8.0, -10.0),
				"degrees": 0.0,
				"z_index": 4
			}


func _get_shield_texture(direction_name: String) -> Texture2D:
	return shield_textures.get("Oak Buckler", null)


func _should_show_right_arm(direction_name: String, is_attacking: bool) -> bool:
	if direction_name == "left":
		return is_attacking
	if direction_name == "right":
		return true
	return true


func _should_show_right_weapon(direction_name: String, _is_attacking: bool) -> bool:
	if direction_name == "left":
		return true
	return _should_show_right_arm(direction_name, _is_attacking)


func _smooth_attack_phase(phase: float) -> float:
	return phase * phase * (3.0 - 2.0 * phase)


func _get_weapon_visual_profile(weapon_name: String) -> Dictionary:
	match weapon_name:
		"Traveler Knife":
			return {
				"type": "short_blade",
				"socket": Vector2(0.0, 17.0),
				"rotation_degrees": 0.0,
				"flip_h": false
			}
		_:
			return {
				"type": "short_blade",
				"socket": Vector2(0.0, 17.0),
				"rotation_degrees": 0.0,
				"flip_h": false
			}


func _update_attack_arm_texture() -> void:
	if left_arm_sprite == null or right_arm_sprite == null:
		return

	var sleeve_color: Color = ARM_TUNIC_DARK if equipped_body_name == "Village Tunic" else ARM_SKIN_DARK
	arm_texture = _create_arm_texture(sleeve_color)
	left_arm_sprite.texture = arm_texture
	right_arm_sprite.texture = arm_texture


func _create_knife_texture() -> Texture2D:
	var image: Image = Image.create(20, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var outline: Color = Color(0.045, 0.040, 0.035, 1.0)
	var steel_dark: Color = Color(0.45, 0.48, 0.48, 1.0)
	var steel_light: Color = Color(0.78, 0.82, 0.78, 1.0)
	var leather: Color = Color(0.24, 0.13, 0.07, 1.0)

	image.fill_rect(Rect2i(1, 5, 6, 3), outline)
	image.fill_rect(Rect2i(2, 6, 4, 1), leather)
	image.fill_rect(Rect2i(6, 4, 3, 5), outline)
	image.fill_rect(Rect2i(9, 3, 8, 3), outline)
	image.fill_rect(Rect2i(9, 4, 7, 1), steel_light)
	image.fill_rect(Rect2i(10, 5, 6, 1), steel_dark)
	image.fill_rect(Rect2i(16, 4, 2, 1), steel_light)
	return ImageTexture.create_from_image(image)


func _create_oak_buckler_texture() -> Texture2D:
	var image: Image = Image.create(17, 19, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var outline: Color = Color(0.040, 0.032, 0.026, 1.0)
	var rim: Color = Color(0.35, 0.24, 0.12, 1.0)
	var wood_dark: Color = Color(0.24, 0.14, 0.07, 1.0)
	var wood: Color = Color(0.46, 0.29, 0.13, 1.0)
	var wood_light: Color = Color(0.62, 0.42, 0.20, 1.0)
	var boss: Color = Color(0.58, 0.52, 0.43, 1.0)

	image.fill_rect(Rect2i(5, 0, 7, 1), outline)
	image.fill_rect(Rect2i(3, 1, 11, 2), outline)
	image.fill_rect(Rect2i(1, 3, 15, 12), outline)
	image.fill_rect(Rect2i(3, 15, 11, 3), outline)
	image.fill_rect(Rect2i(5, 1, 7, 1), rim)
	image.fill_rect(Rect2i(4, 2, 9, 2), rim)
	image.fill_rect(Rect2i(2, 4, 13, 10), rim)
	image.fill_rect(Rect2i(4, 14, 9, 2), rim)
	image.fill_rect(Rect2i(4, 3, 4, 13), wood_dark)
	image.fill_rect(Rect2i(8, 3, 4, 13), wood)
	image.fill_rect(Rect2i(12, 4, 2, 10), wood_light)
	image.fill_rect(Rect2i(7, 8, 4, 4), outline)
	image.fill_rect(Rect2i(8, 9, 2, 2), boss)
	return ImageTexture.create_from_image(image)


func _create_oak_buckler_edge_texture() -> Texture2D:
	var image: Image = Image.create(7, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var outline: Color = Color(0.040, 0.032, 0.026, 1.0)
	var rim: Color = Color(0.35, 0.24, 0.12, 1.0)
	var wood: Color = Color(0.46, 0.29, 0.13, 1.0)
	var wood_light: Color = Color(0.62, 0.42, 0.20, 1.0)

	image.fill_rect(Rect2i(2, 0, 3, 1), outline)
	image.fill_rect(Rect2i(1, 1, 5, 2), outline)
	image.fill_rect(Rect2i(0, 3, 7, 10), outline)
	image.fill_rect(Rect2i(1, 13, 5, 2), outline)
	image.fill_rect(Rect2i(2, 1, 3, 1), rim)
	image.fill_rect(Rect2i(1, 3, 5, 10), rim)
	image.fill_rect(Rect2i(2, 3, 2, 10), wood)
	image.fill_rect(Rect2i(4, 4, 1, 8), wood_light)
	return ImageTexture.create_from_image(image)


func _create_arm_texture(sleeve: Color) -> Texture2D:
	var image: Image = Image.create(7, 21, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var outline: Color = Color(0.045, 0.036, 0.030, 1.0)
	var skin_dark: Color = ARM_SKIN_DARK
	var skin: Color = ARM_SKIN

	image.fill_rect(Rect2i(1, 0, 5, 14), outline)
	image.fill_rect(Rect2i(2, 1, 3, 11), sleeve)
	image.fill_rect(Rect2i(1, 12, 5, 8), outline)
	image.fill_rect(Rect2i(2, 13, 3, 6), skin_dark)
	image.fill_rect(Rect2i(3, 13, 1, 4), skin)
	return ImageTexture.create_from_image(image)
