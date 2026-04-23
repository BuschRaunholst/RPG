extends CharacterBody2D

const InventoryStateScript = preload("res://scripts/world/inventory_state.gd")
const TUNIC_FRAMES = preload("res://assets/art/characters/player_clothes_village_tunic_4dir_64_frames.tres")
const BOOTS_FRAMES = preload("res://assets/art/characters/player_boots_worn_4dir_64_frames.tres")
const ARM_SKIN_DARK := Color(0.48, 0.30, 0.20, 1.0)
const ARM_SKIN := Color(0.66, 0.43, 0.28, 1.0)
const ARM_TUNIC_DARK := Color(0.17, 0.20, 0.16, 1.0)

@export var move_speed: float = 180.0
@export var attack_range: float = 58.0
@export var attack_cooldown: float = 0.35

signal interacted(target: Node)
signal attack_requested(attack_data: Dictionary)
signal context_action_requested

@onready var body: AnimatedSprite2D = $Body
@onready var clothing_layer: AnimatedSprite2D = $ClothingLayer
@onready var boots_layer: AnimatedSprite2D = $BootsLayer
@onready var left_arm_pivot: Node2D = $LeftArmPivot
@onready var left_arm_sprite: Sprite2D = $LeftArmPivot/LeftArmSprite
@onready var shield_socket: Node2D = $LeftArmPivot/ShieldSocket
@onready var left_weapon_socket: Node2D = $LeftArmPivot/LeftWeaponSocket
@onready var left_weapon_pivot: Node2D = $LeftArmPivot/LeftWeaponSocket/LeftWeaponPivot
@onready var left_weapon_sprite: Sprite2D = $LeftArmPivot/LeftWeaponSocket/LeftWeaponPivot/LeftWeaponSprite
@onready var shield_pivot: Node2D = $LeftArmPivot/ShieldSocket/ShieldPivot
@onready var shield_sprite: Sprite2D = $LeftArmPivot/ShieldSocket/ShieldPivot/ShieldSprite
@onready var back_shield_pivot: Node2D = $BackShieldPivot
@onready var back_shield_sprite: Sprite2D = $BackShieldPivot/BackShieldSprite
@onready var right_arm_pivot: Node2D = $RightArmPivot
@onready var right_arm_sprite: Sprite2D = $RightArmPivot/RightArmSprite
@onready var weapon_socket: Node2D = $RightArmPivot/WeaponSocket
@onready var weapon_pivot: Node2D = $RightArmPivot/WeaponSocket/WeaponPivot
@onready var weapon_sprite: Sprite2D = $RightArmPivot/WeaponSocket/WeaponPivot/WeaponSprite
@onready var weapon_rig: Node2D = $WeaponRig
@onready var weapon_rig_sprite: Sprite2D = $WeaponRig/WeaponSprite
@onready var interaction_detector: Area2D = $InteractionDetector

var can_move: bool = true
var nearby_interactable: Node = null
var tap_interaction_range: float = 56.0
var facing_direction: Vector2 = Vector2.DOWN
var attack_cooldown_remaining: float = 0.0
var attack_feedback_remaining: float = 0.0
var attack_feedback_duration: float = 0.12
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
var equipped_weapon_profile: Dictionary = InventoryStateScript.DEFAULT_WEAPON_DATA.duplicate(true)
const ARM_REACH := 17.0


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
	left_weapon_sprite.visible = false
	weapon_sprite.visible = false
	weapon_rig.visible = false
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


func _on_interaction_detector_area_entered(_area: Area2D) -> void:
	refresh_nearby_interactable()


func _on_interaction_detector_area_exited(_area: Area2D) -> void:
	refresh_nearby_interactable()


func can_interact_with(target: Node) -> bool:
	if target == nearby_interactable:
		return true

	if target is Node2D:
		return global_position.distance_to(target.global_position) <= tap_interaction_range

	return false


func get_nearby_interactable() -> Node:
	return nearby_interactable


func refresh_nearby_interactable() -> void:
	if interaction_detector == null:
		_set_nearby_interactable(null)
		return

	var best_target: Node = null
	var best_distance: float = INF
	for area in interaction_detector.get_overlapping_areas():
		if area == null or not is_instance_valid(area):
			continue
		var candidate: Node = area.get_parent()
		if not _is_valid_interactable(candidate):
			continue
		if candidate is Node2D:
			var candidate_distance: float = global_position.distance_squared_to((candidate as Node2D).global_position)
			if candidate_distance < best_distance:
				best_distance = candidate_distance
				best_target = candidate
		elif best_target == null:
			best_target = candidate

	_set_nearby_interactable(best_target)


func _set_nearby_interactable(target: Node) -> void:
	if highlighted_interactable != null and highlighted_interactable.has_method("set_interaction_highlight"):
		highlighted_interactable.call("set_interaction_highlight", false)

	nearby_interactable = target
	highlighted_interactable = target

	if highlighted_interactable != null and highlighted_interactable.has_method("set_interaction_highlight"):
		highlighted_interactable.call("set_interaction_highlight", true)


func try_interact() -> bool:
	if not _is_valid_interactable(nearby_interactable):
		refresh_nearby_interactable()
	if nearby_interactable == null:
		return false

	interacted.emit(nearby_interactable)
	return true


func _is_valid_interactable(target: Node) -> bool:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return false
	if target.has_method("collect_pickup") and bool(target.get("is_collected")):
		return false
	return true


func can_attack_now() -> bool:
	return can_move and attack_cooldown_remaining <= 0.0


func try_attack() -> bool:
	if not can_attack_now():
		return false

	var attack_profile: Dictionary = _get_current_attack_profile()
	attack_feedback_duration = float(attack_profile.get("animation_duration", 0.12))
	attack_cooldown_remaining = float(attack_profile.get("cooldown", attack_cooldown))
	attack_feedback_remaining = attack_feedback_duration

	var aim_direction: Vector2 = facing_direction.normalized()
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.DOWN

	attack_requested.emit({
		"origin": global_position,
		"direction": aim_direction,
		"weapon_name": equipped_weapon_name,
		"attack_kind": str(attack_profile.get("attack_kind", "melee_arc")),
		"range": float(attack_profile.get("range", attack_range)),
		"arc_dot": float(attack_profile.get("arc_dot", 0.15)),
		"thickness": float(attack_profile.get("thickness", 18.0)),
		"targeting": str(attack_profile.get("targeting", "forward")),
		"max_targets": int(attack_profile.get("max_targets", 1)),
		"damage_scale": float(attack_profile.get("damage_scale", 1.0)),
		"ranged": bool(attack_profile.get("ranged", false))
	})
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
	equipped_weapon_profile = _get_current_attack_profile()

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
	var attack_progress_remaining: float = attack_feedback_remaining / attack_feedback_duration if attack_feedback_remaining > 0.0 else 0.0
	var attack_t: float = 1.0 - attack_progress_remaining if attack_feedback_remaining > 0.0 else 0.0
	var attack_offset: Vector2 = facing_direction.normalized() * (sin(attack_progress_remaining * PI) * 5.0)
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

	_update_weapon_pose(attack_t, attack_offset)


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
	weapon_textures["Hunter Bow"] = _create_bow_texture()
	weapon_textures["Ash Staff"] = _create_staff_texture()
	weapon_textures["Willow Wand"] = _create_wand_texture()
	weapon_textures["Iron Greatsword"] = _create_greatsword_texture()
	weapon_textures["Woodsman Axe"] = _create_axe_texture()


func _build_shield_textures() -> void:
	shield_textures["Oak Buckler"] = _create_oak_buckler_texture()
	shield_textures["Oak Buckler Edge"] = _create_oak_buckler_edge_texture()


func _update_weapon_visual() -> void:
	if weapon_rig_sprite == null or shield_sprite == null or back_shield_sprite == null:
		return

	if weapon_textures.has(equipped_weapon_name):
		var weapon_texture: Texture2D = weapon_textures[equipped_weapon_name]
		weapon_rig_sprite.texture = weapon_texture
		weapon_rig.visible = true
	else:
		weapon_rig_sprite.texture = null
		weapon_rig.visible = false

	if shield_textures.has(equipped_offhand_name):
		shield_sprite.texture = shield_textures[equipped_offhand_name]
		back_shield_sprite.texture = shield_textures.get("%s Edge" % equipped_offhand_name, shield_textures[equipped_offhand_name])
	else:
		shield_sprite.texture = null
		back_shield_sprite.texture = null

	weapon_sprite.visible = false
	left_weapon_sprite.visible = false
	right_arm_pivot.visible = true
	left_arm_pivot.visible = true
	_update_weapon_pose(0.0, Vector2.ZERO)




func _get_swing_angles(direction_name: String, scale: float) -> Dictionary:
	match direction_name:
		"left":
			return {"windup": 76.0 * scale, "follow": -22.0 * scale}
		"right":
			return {"windup": -76.0 * scale, "follow": 22.0 * scale}
		"up":
			return {"windup": -34.0 * scale, "follow": 18.0 * scale}
		_:
			return {"windup": 58.0 * scale, "follow": -30.0 * scale}


func _update_weapon_pose(attack_t: float, attack_offset: Vector2) -> void:
	if left_arm_pivot == null or right_arm_pivot == null or weapon_rig == null:
		return

	var direction_name: String = _get_animation_direction_name()
	var weapon_profile: Dictionary = _get_weapon_visual_profile(equipped_weapon_name)
	var style: String = str(weapon_profile.get("hold_style", "one_hand"))
	var has_weapon: bool = weapon_textures.has(equipped_weapon_name)
	var can_show_shield: bool = shield_textures.has(equipped_offhand_name) and not bool(weapon_profile.get("two_handed", false))
	var direction_rig: Dictionary = _get_direction_rig(direction_name)
	var pose: Dictionary = _sample_pose(style, direction_name, attack_t)
	pose = _apply_pose_layer_defaults(pose, style, direction_name)
	pose["weapon_rotation"] = _get_weapon_facing_rotation(style, direction_name, attack_t, float(pose.get("weapon_rotation", 0.0))) + _get_weapon_rotation_offset(weapon_profile, direction_name)

	var left_shoulder: Vector2 = (direction_rig.get("left_shoulder", Vector2.ZERO) as Vector2) + attack_offset
	var right_shoulder: Vector2 = (direction_rig.get("right_shoulder", Vector2.ZERO) as Vector2) + attack_offset
	var weapon_position: Vector2 = (pose.get("weapon_position", Vector2.ZERO) as Vector2) + attack_offset
	var weapon_rotation_degrees: float = float(pose.get("weapon_rotation", 0.0))

	weapon_rig.visible = has_weapon and bool(pose.get("show_weapon", true))
	weapon_rig.position = weapon_position
	weapon_rig.rotation = deg_to_rad(weapon_rotation_degrees)
	weapon_rig.z_index = int(pose.get("weapon_z", direction_rig.get("weapon_z", 6)))
	weapon_rig_sprite.offset = pose.get("weapon_offset", weapon_profile.get("offset", Vector2(-3.0, -7.0))) as Vector2
	weapon_rig_sprite.flip_h = bool(pose.get("weapon_flip_h", false))

	var grip_offset: Vector2 = weapon_profile.get("grip_offset", weapon_rig_sprite.offset) as Vector2
	var right_target: Vector2 = _weapon_local_to_player(weapon_position, weapon_rotation_degrees, pose.get("right_hand_grip", Vector2.ZERO) as Vector2, grip_offset)
	var left_target_variant: Variant = pose.get("left_hand_grip", null)
	var left_target: Vector2 = _free_hand_target(direction_name, "left") + attack_offset
	if left_target_variant is Vector2:
		left_target = _weapon_local_to_player(weapon_position, weapon_rotation_degrees, left_target_variant as Vector2, grip_offset)

	var uses_relaxed_offhand: bool = _uses_one_hand_shield_stance(style) and not left_target_variant is Vector2
	var uses_relaxed_shield: bool = can_show_shield and uses_relaxed_offhand
	if uses_relaxed_offhand:
		left_target = _relaxed_offhand_target(direction_name) + attack_offset
		pose["show_left_arm"] = direction_name != "right"
		if direction_name == "up":
			pose["show_right_arm"] = true

	var show_left_arm: bool = bool(pose.get("show_left_arm", true))
	var show_right_arm: bool = bool(pose.get("show_right_arm", true))
	_apply_arm_pose(left_arm_pivot, left_arm_sprite, left_shoulder, left_target, show_left_arm, int(pose.get("left_arm_z", direction_rig.get("left_arm_z", 4))))
	_apply_arm_pose(right_arm_pivot, right_arm_sprite, right_shoulder, right_target, show_right_arm, int(pose.get("right_arm_z", direction_rig.get("right_arm_z", 5))))

	shield_socket.position = _get_shield_socket_position(direction_rig, direction_name, uses_relaxed_shield)
	shield_pivot.rotation = deg_to_rad(_get_shield_rotation(direction_rig, direction_name, uses_relaxed_shield))
	shield_sprite.offset = _get_shield_offset(direction_rig, direction_name, uses_relaxed_shield)
	shield_sprite.visible = can_show_shield and bool(direction_rig.get("show_shield_front", false))

	var back_shield_pose: Dictionary = _get_back_shield_pose(direction_name)
	back_shield_pivot.position = (back_shield_pose.get("position", Vector2.ZERO) as Vector2) + attack_offset
	back_shield_pivot.rotation = deg_to_rad(float(back_shield_pose.get("degrees", 0.0)))
	back_shield_pivot.z_index = int(back_shield_pose.get("z_index", -1))
	back_shield_sprite.offset = back_shield_pose.get("offset", Vector2(-8.0, -9.0)) as Vector2
	back_shield_pivot.visible = can_show_shield and bool(direction_rig.get("show_shield_back", false))
	back_shield_sprite.visible = back_shield_pivot.visible


func _sample_pose(style: String, direction_name: String, attack_t: float) -> Dictionary:
	var poses: Dictionary = _get_pose_set(style, direction_name)
	if attack_t <= 0.0:
		return (poses.get("idle", {}) as Dictionary).duplicate(true)
	if attack_t < 0.24:
		return _blend_pose_dicts(poses.get("idle", {}), poses.get("windup", {}), attack_t / 0.24)
	if attack_t < 0.56:
		return _blend_pose_dicts(poses.get("windup", {}), poses.get("strike", {}), (attack_t - 0.24) / 0.32)
	if attack_t < 0.80:
		return _blend_pose_dicts(poses.get("strike", {}), poses.get("recover", {}), (attack_t - 0.56) / 0.24)
	return _blend_pose_dicts(poses.get("recover", {}), poses.get("idle", {}), (attack_t - 0.80) / 0.20)


func _get_weapon_facing_rotation(style: String, direction_name: String, attack_t: float, fallback_degrees: float) -> float:
	var rotations: Dictionary = _get_weapon_rotation_profile(style, direction_name)
	if rotations.is_empty():
		return fallback_degrees
	if attack_t <= 0.0:
		return float(rotations.get("idle", fallback_degrees))
	if attack_t < 0.24:
		return _lerp_degrees(float(rotations.get("idle", fallback_degrees)), float(rotations.get("windup", fallback_degrees)), attack_t / 0.24)
	if attack_t < 0.56:
		return _lerp_degrees(float(rotations.get("windup", fallback_degrees)), float(rotations.get("strike", fallback_degrees)), (attack_t - 0.24) / 0.32)
	if attack_t < 0.80:
		return _lerp_degrees(float(rotations.get("strike", fallback_degrees)), float(rotations.get("recover", fallback_degrees)), (attack_t - 0.56) / 0.24)
	return _lerp_degrees(float(rotations.get("recover", fallback_degrees)), float(rotations.get("idle", fallback_degrees)), (attack_t - 0.80) / 0.20)


func _get_weapon_rotation_profile(style: String, direction_name: String) -> Dictionary:
	match style:
		"bow":
			return _bow_rotation_profile(direction_name)
		"staff":
			return _staff_vertical_rotation_profile()
		"greatsword":
			return _heavy_swing_rotation_profile(direction_name)
		"wand":
			return _short_blade_rotation_profile(direction_name)
		"axe":
			return _short_blade_rotation_profile(direction_name)
		_:
			return _short_blade_rotation_profile(direction_name)


func _point_out_rotation_profile(direction_name: String, windup_degrees: float) -> Dictionary:
	var idle: float = _point_out_degrees(direction_name)
	var windup_sign: float = -1.0 if direction_name in ["right", "down"] else 1.0
	return {
		"idle": idle,
		"windup": idle + windup_degrees * windup_sign,
		"strike": idle,
		"recover": idle
	}


func _short_blade_rotation_profile(direction_name: String) -> Dictionary:
	match direction_name:
		"left":
			return {"idle": 210.0, "windup": 268.0, "strike": 152.0, "recover": 206.0}
		"right":
			return {"idle": -30.0, "windup": -88.0, "strike": 28.0, "recover": -26.0}
		"up":
			return {"idle": -52.0, "windup": -76.0, "strike": -30.0, "recover": -52.0}
		_:
			return {"idle": 210.0, "windup": 246.0, "strike": 174.0, "recover": 210.0}


func _heavy_swing_rotation_profile(direction_name: String) -> Dictionary:
	match direction_name:
		"left":
			return {"idle": -90.0, "windup": -26.0, "strike": -152.0, "recover": -96.0}
		"right":
			return {"idle": 90.0, "windup": 26.0, "strike": 152.0, "recover": 96.0}
		"up":
			return {"idle": 0.0, "windup": 58.0, "strike": -48.0, "recover": 4.0}
		_:
			return {"idle": 180.0, "windup": 238.0, "strike": 128.0, "recover": 176.0}


func _staff_vertical_rotation_profile() -> Dictionary:
	return {"idle": 0.0, "windup": 0.0, "strike": 0.0, "recover": 0.0}


func _bow_rotation_profile(direction_name: String) -> Dictionary:
	match direction_name:
		"up", "down":
			return {"idle": 90.0, "windup": 90.0, "strike": 90.0, "recover": 90.0}
		_:
			return {"idle": 0.0, "windup": 0.0, "strike": 0.0, "recover": 0.0}


func _point_out_degrees(direction_name: String) -> float:
	match direction_name:
		"left":
			return -90.0
		"right":
			return 90.0
		"up":
			return 0.0
		_:
			return 180.0


func _lerp_degrees(from_degrees: float, to_degrees: float, weight: float) -> float:
	return rad_to_deg(lerp_angle(deg_to_rad(from_degrees), deg_to_rad(to_degrees), weight))


func _get_weapon_rotation_offset(weapon_profile: Dictionary, direction_name: String) -> float:
	var offsets: Variant = weapon_profile.get("rotation_offsets", {})
	if offsets is Dictionary:
		return float((offsets as Dictionary).get(direction_name, (offsets as Dictionary).get("default", 0.0)))
	return 0.0


func _get_pose_set(style: String, direction_name: String) -> Dictionary:
	match style:
		"bow":
			return _get_bow_pose_set(direction_name)
		"staff":
			return _get_staff_pose_set(direction_name)
		"greatsword":
			return _get_greatsword_pose_set(direction_name)
		"wand":
			return _get_wand_pose_set(direction_name)
		"axe":
			return _get_axe_pose_set(direction_name)
		_:
			return _get_one_hand_pose_set(direction_name)


func _get_direction_rig(direction_name: String) -> Dictionary:
	match direction_name:
		"left":
			return {
				"left_shoulder": Vector2(-5.0, -18.0),
				"right_shoulder": Vector2(2.0, -18.0),
				"left_arm_z": 4,
				"right_arm_z": 5,
				"shield_socket": Vector2(0.0, 13.0),
				"shield_rotation": 3.0,
				"shield_offset": Vector2(-3.0, -9.0),
				"show_shield_front": true,
				"show_shield_back": false,
				"weapon_z": 6
			}
		"right":
			return {
				"left_shoulder": Vector2(2.0, -18.0),
				"right_shoulder": Vector2(3.0, -18.0),
				"left_arm_z": 4,
				"right_arm_z": 5,
				"shield_socket": Vector2(0.0, 13.0),
				"shield_rotation": 0.0,
				"shield_offset": Vector2(-13.0, -9.0),
				"show_shield_front": false,
				"show_shield_back": true,
				"weapon_z": 6
			}
		"up":
			return {
				"left_shoulder": Vector2(-8.0, -18.0),
				"right_shoulder": Vector2(8.0, -18.0),
				"left_arm_z": 3,
				"right_arm_z": 3,
				"shield_socket": Vector2(0.0, 11.0),
				"shield_rotation": -8.0,
				"shield_offset": Vector2(-9.0, -9.0),
				"show_shield_front": false,
				"show_shield_back": true,
				"weapon_z": 2
			}
		_:
			return {
				"left_shoulder": Vector2(10.0, -19.0),
				"right_shoulder": Vector2(-10.0, -19.0),
				"left_arm_z": 5,
				"right_arm_z": 5,
				"shield_socket": Vector2(0.0, 14.0),
				"shield_rotation": 0.0,
				"shield_offset": Vector2(-5.0, -9.0),
				"show_shield_front": true,
				"show_shield_back": false,
				"weapon_z": 6
			}


func _apply_pose_layer_defaults(pose: Dictionary, style: String, direction_name: String) -> Dictionary:
	var layered_pose: Dictionary = pose.duplicate(true)
	var has_left_grip: bool = layered_pose.get("left_hand_grip", null) is Vector2
	var is_two_hand_style: bool = style in ["bow", "greatsword"]
	var default_show_left: bool = has_left_grip
	var default_show_right: bool = true
	var defaults := {}

	match direction_name:
		"left":
			defaults = {
				"weapon_z": 5,
				"left_arm_z": 3,
				"right_arm_z": 5,
				"show_left_arm": default_show_left,
				"show_right_arm": default_show_right
			}
		"right":
			defaults = {
				"weapon_z": 6,
				"left_arm_z": 3,
				"right_arm_z": 6,
				"show_left_arm": default_show_left,
				"show_right_arm": default_show_right
			}
		"up":
			defaults = {
				"weapon_z": 1,
				"left_arm_z": 1,
				"right_arm_z": 1,
				"show_left_arm": is_two_hand_style and has_left_grip,
				"show_right_arm": is_two_hand_style
			}
		_:
			defaults = {
				"weapon_z": 6,
				"left_arm_z": 6,
				"right_arm_z": 6,
				"show_left_arm": default_show_left or style in ["one_hand", "axe", "wand"],
				"show_right_arm": default_show_right
			}

	for key in defaults.keys():
		if not layered_pose.has(key):
			layered_pose[key] = defaults[key]
	return layered_pose


func _get_one_hand_pose_set(direction_name: String) -> Dictionary:
	match direction_name:
		"left":
			return {
				"idle": _pose(Vector2(-1.0, -6.0), 122.0, Vector2(4.0, 6.0), null, {"weapon_z": 1, "right_arm_z": 1}),
				"windup": _pose(Vector2(-3.0, -9.0), 216.0, Vector2(4.0, 6.0), null, {"weapon_z": 1, "right_arm_z": 1}),
				"strike": _pose(Vector2(2.0, -3.0), 72.0, Vector2(4.0, 6.0)),
				"recover": _pose(Vector2(-1.0, -5.0), 110.0, Vector2(4.0, 6.0), null, {"weapon_z": 1, "right_arm_z": 1})
			}
		"right":
			return {
				"idle": _pose(Vector2(6.0, -4.0), 58.0, Vector2(4.0, 6.0)),
				"windup": _pose(Vector2(8.0, -7.0), -36.0, Vector2(4.0, 6.0)),
				"strike": _pose(Vector2(10.0, -1.0), 108.0, Vector2(4.0, 6.0)),
				"recover": _pose(Vector2(6.0, -3.0), 68.0, Vector2(4.0, 6.0))
			}
		"up":
			return {
				"idle": _pose(Vector2(13.0, -3.0), -18.0, Vector2(4.0, 6.0), null, {"weapon_z": 0, "right_arm_z": 1}),
				"windup": _pose(Vector2(15.0, -5.0), -48.0, Vector2(4.0, 6.0), null, {"weapon_z": 0, "right_arm_z": 1}),
				"strike": _pose(Vector2(11.0, -2.0), 12.0, Vector2(4.0, 6.0), null, {"weapon_z": 0, "right_arm_z": 1}),
				"recover": _pose(Vector2(13.0, -3.0), -4.0, Vector2(4.0, 6.0), null, {"weapon_z": 0, "right_arm_z": 1})
			}
		_:
			return {
				"idle": _pose(Vector2(-12.0, -3.0), 170.0, Vector2(4.0, 6.0)),
				"windup": _pose(Vector2(-13.0, -5.0), 206.0, Vector2(4.0, 6.0)),
				"strike": _pose(Vector2(-11.0, 1.0), 154.0, Vector2(4.0, 6.0)),
				"recover": _pose(Vector2(-12.0, -2.0), 170.0, Vector2(4.0, 6.0))
			}


func _get_axe_pose_set(direction_name: String) -> Dictionary:
	return _get_one_hand_pose_set(direction_name)


func _get_wand_pose_set(direction_name: String) -> Dictionary:
	return _get_one_hand_pose_set(direction_name)


func _get_bow_pose_set(direction_name: String) -> Dictionary:
	match direction_name:
		"left":
			return {
				"idle": _pose(Vector2(1.0, -8.0), 180.0, Vector2(8.0, 14.0), Vector2(8.0, 24.0)),
				"windup": _pose(Vector2(0.0, -8.0), 180.0, Vector2(2.0, 14.0), Vector2(8.0, 24.0)),
				"strike": _pose(Vector2(0.0, -8.0), 180.0, Vector2(0.0, 14.0), Vector2(8.0, 24.0)),
				"recover": _pose(Vector2(1.0, -8.0), 180.0, Vector2(4.0, 14.0), Vector2(8.0, 24.0))
			}
		"right":
			return {
				"idle": _pose(Vector2(-1.0, -8.0), 0.0, Vector2(8.0, 14.0), Vector2(8.0, 24.0)),
				"windup": _pose(Vector2(0.0, -8.0), 0.0, Vector2(14.0, 14.0), Vector2(8.0, 24.0)),
				"strike": _pose(Vector2(0.0, -8.0), 0.0, Vector2(16.0, 14.0), Vector2(8.0, 24.0)),
				"recover": _pose(Vector2(-1.0, -8.0), 0.0, Vector2(12.0, 14.0), Vector2(8.0, 24.0))
			}
		"up":
			return {
				"idle": _pose(Vector2(0.0, -10.0), -90.0, Vector2(8.0, 12.0), Vector2(8.0, 22.0)),
				"windup": _pose(Vector2(0.0, -10.0), -90.0, Vector2(2.0, 12.0), Vector2(8.0, 22.0)),
				"strike": _pose(Vector2(0.0, -10.0), -90.0, Vector2(0.0, 12.0), Vector2(8.0, 22.0)),
				"recover": _pose(Vector2(0.0, -10.0), -90.0, Vector2(4.0, 12.0), Vector2(8.0, 22.0))
			}
		_:
			return {
				"idle": _pose(Vector2(0.0, -5.0), 8.0, Vector2(8.0, 12.0), Vector2(8.0, 22.0)),
				"windup": _pose(Vector2(0.0, -5.0), 74.0, Vector2(14.0, 12.0), Vector2(8.0, 22.0)),
				"strike": _pose(Vector2(0.0, -5.0), 88.0, Vector2(16.0, 12.0), Vector2(8.0, 22.0)),
				"recover": _pose(Vector2(0.0, -5.0), 28.0, Vector2(12.0, 12.0), Vector2(8.0, 22.0))
			}


func _get_staff_pose_set(direction_name: String) -> Dictionary:
	match direction_name:
		"left":
			return {
				"idle": _pose(Vector2(-13.0, -18.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 6, "right_arm_z": 6}),
				"windup": _pose(Vector2(-15.0, -18.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 6, "right_arm_z": 6}),
				"strike": _pose(Vector2(-18.0, -18.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 6, "right_arm_z": 6}),
				"recover": _pose(Vector2(-13.0, -18.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 6, "right_arm_z": 6})
			}
		"right":
			return {
				"idle": _pose(Vector2(18.0, -18.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 6, "right_arm_z": 6}),
				"windup": _pose(Vector2(20.0, -18.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 6, "right_arm_z": 6}),
				"strike": _pose(Vector2(23.0, -18.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 6, "right_arm_z": 6}),
				"recover": _pose(Vector2(18.0, -18.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 6, "right_arm_z": 6})
			}
		"up":
			return {
				"idle": _pose(Vector2(22.0, -18.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 1, "right_arm_z": 1, "show_right_arm": true}),
				"windup": _pose(Vector2(24.0, -18.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 1, "right_arm_z": 1, "show_right_arm": true}),
				"strike": _pose(Vector2(27.0, -18.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 1, "right_arm_z": 1, "show_right_arm": true}),
				"recover": _pose(Vector2(22.0, -18.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 1, "right_arm_z": 1, "show_right_arm": true})
			}
		_:
			return {
				"idle": _pose(Vector2(-24.0, -19.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 6, "right_arm_z": 6}),
				"windup": _pose(Vector2(-26.0, -19.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 6, "right_arm_z": 6}),
				"strike": _pose(Vector2(-29.0, -19.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 6, "right_arm_z": 6}),
				"recover": _pose(Vector2(-24.0, -19.0), 90.0, Vector2(6.0, 42.0), null, {"weapon_z": 6, "right_arm_z": 6})
			}


func _get_greatsword_pose_set(direction_name: String) -> Dictionary:
	match direction_name:
		"left":
			return {
				"idle": _pose(Vector2(3.0, -10.0), 164.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0)),
				"windup": _pose(Vector2(6.0, -12.0), 236.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0)),
				"strike": _pose(Vector2(-2.0, -7.0), 94.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0)),
				"recover": _pose(Vector2(1.0, -9.0), 142.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0))
			}
		"right":
			return {
				"idle": _pose(Vector2(-3.0, -10.0), 16.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0)),
				"windup": _pose(Vector2(-6.0, -12.0), -56.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0)),
				"strike": _pose(Vector2(2.0, -7.0), 86.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0)),
				"recover": _pose(Vector2(-1.0, -9.0), 38.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0))
			}
		"up":
			return {
				"idle": _pose(Vector2(0.0, -12.0), -14.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0)),
				"windup": _pose(Vector2(2.0, -14.0), -64.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0)),
				"strike": _pose(Vector2(-1.0, -9.0), 10.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0)),
				"recover": _pose(Vector2(0.0, -11.0), -18.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0))
			}
		_:
			return {
				"idle": _pose(Vector2(0.0, -2.0), 186.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0)),
				"windup": _pose(Vector2(0.0, -5.0), 252.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0)),
				"strike": _pose(Vector2(0.0, 1.0), 138.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0)),
				"recover": _pose(Vector2(0.0, -1.0), 174.0, Vector2(7.0, 29.0), Vector2(7.0, 23.0))
			}


func _free_hand_target(direction_name: String, side: String) -> Vector2:
	match direction_name:
		"left":
			return Vector2(-2.0, -2.0) if side == "left" else Vector2(8.0, -2.0)
		"right":
			return Vector2(2.0, -2.0) if side == "left" else Vector2(-8.0, -2.0)
		"up":
			return Vector2(-5.0, -4.0) if side == "left" else Vector2(5.0, -4.0)
		_:
			return Vector2(7.0, 0.0) if side == "left" else Vector2(-7.0, 0.0)


func _relaxed_offhand_target(direction_name: String) -> Vector2:
	match direction_name:
		"left":
			return Vector2(-5.0, -2.0)
		"right":
			return Vector2(4.0, -1.0)
		"up":
			return Vector2(-8.0, -6.0)
		_:
			return Vector2(10.0, -2.0)


func _uses_one_hand_shield_stance(style: String) -> bool:
	return style in ["one_hand", "axe", "wand", "staff"]


func _get_shield_socket_position(direction_rig: Dictionary, direction_name: String, relaxed_shield: bool) -> Vector2:
	if not relaxed_shield:
		return direction_rig.get("shield_socket", Vector2(0.0, 14.0)) as Vector2
	match direction_name:
		"left", "right":
			return Vector2(0.0, 13.0)
		_:
			return Vector2(0.0, 10.0)


func _get_shield_rotation(direction_rig: Dictionary, direction_name: String, relaxed_shield: bool) -> float:
	if not relaxed_shield:
		return float(direction_rig.get("shield_rotation", 0.0))
	match direction_name:
		"left":
			return -8.0
		"right":
			return 8.0
		_:
			return 0.0


func _get_shield_offset(direction_rig: Dictionary, direction_name: String, relaxed_shield: bool) -> Vector2:
	if not relaxed_shield:
		return direction_rig.get("shield_offset", Vector2(-7.0, -8.0)) as Vector2
	match direction_name:
		"left":
			return Vector2(-3.0, -8.0)
		"right":
			return Vector2(-6.0, -8.0)
		_:
			return Vector2(-4.0, -8.0)


func _pose(position: Vector2, rotation_degrees: float, right_hand_grip: Vector2, left_hand_grip: Variant = null, extras: Dictionary = {}) -> Dictionary:
	var pose := {
		"weapon_position": position,
		"weapon_rotation": rotation_degrees,
		"right_hand_grip": right_hand_grip,
		"left_hand_grip": left_hand_grip
	}
	for key in extras.keys():
		pose[key] = extras[key]
	return pose


func _blend_pose_dicts(from_pose_variant: Variant, to_pose_variant: Variant, weight: float) -> Dictionary:
	var from_pose: Dictionary = (from_pose_variant as Dictionary).duplicate(true)
	var to_pose: Dictionary = (to_pose_variant as Dictionary).duplicate(true)
	var result: Dictionary = from_pose.duplicate(true)
	for key in to_pose.keys():
		if not result.has(key):
			result[key] = to_pose[key]
			continue
		if result[key] is Vector2 and to_pose[key] is Vector2:
			result[key] = (result[key] as Vector2).lerp(to_pose[key] as Vector2, weight)
		elif result[key] is float or result[key] is int:
			result[key] = lerpf(float(result[key]), float(to_pose[key]), weight)
		else:
			result[key] = to_pose[key] if weight >= 0.5 else result[key]
	return result


func _weapon_local_to_player(weapon_position: Vector2, weapon_rotation_degrees: float, local_point: Vector2, grip_offset: Vector2) -> Vector2:
	return weapon_position + (grip_offset + local_point).rotated(deg_to_rad(weapon_rotation_degrees))


func _apply_arm_pose(arm_pivot: Node2D, arm_sprite_node: Sprite2D, shoulder_position: Vector2, target_position: Vector2, should_show: bool, z_index: int) -> void:
	arm_pivot.position = shoulder_position
	arm_pivot.z_index = z_index
	arm_pivot.visible = should_show
	arm_sprite_node.visible = should_show
	if not should_show:
		arm_sprite_node.scale = Vector2.ONE
		return
	var vector_to_target: Vector2 = target_position - shoulder_position
	if vector_to_target.length() < 0.01:
		vector_to_target = Vector2.DOWN * ARM_REACH
	arm_pivot.rotation = Vector2.DOWN.angle_to(vector_to_target)
	arm_sprite_node.scale = Vector2(1.0, clampf(vector_to_target.length() / ARM_REACH, 0.85, 1.45))


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


func _smooth_attack_phase(phase: float) -> float:
	return phase * phase * (3.0 - 2.0 * phase)


func _get_current_attack_profile() -> Dictionary:
	if equipped_weapon_name.is_empty():
		return InventoryStateScript.DEFAULT_WEAPON_DATA.duplicate(true)
	return InventoryStateScript.get_weapon_data(equipped_weapon_name)


func _get_weapon_visual_profile(weapon_name: String) -> Dictionary:
	var profile: Dictionary = InventoryStateScript.get_weapon_data(weapon_name)
	match weapon_name:
		"Hunter Bow":
			profile["offset"] = Vector2(-6.0, -17.0)
			profile["rotation_offsets"] = {"default": 0.0}
		"Ash Staff":
			profile["offset"] = Vector2(-6.0, -42.0)
			profile["rotation_offsets"] = {"default": 0.0}
		"Willow Wand":
			profile["offset"] = Vector2(-3.0, -7.0)
			profile["rotation_offsets"] = {"default": 0.0}
		"Iron Greatsword":
			profile["offset"] = Vector2(-6.0, -17.0)
			profile["rotation_offsets"] = {"default": 0.0}
		"Woodsman Axe":
			profile["offset"] = Vector2(-3.0, -7.0)
			profile["rotation_offsets"] = {"default": 0.0}
		_:
			profile["offset"] = Vector2(-3.0, -7.0)
			profile["rotation_offsets"] = {"default": 0.0}
	return profile


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


func _create_bow_texture() -> Texture2D:
	var image: Image = Image.create(16, 30, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var outline: Color = Color(0.04, 0.03, 0.025, 1.0)
	var wood: Color = Color(0.44, 0.25, 0.12, 1.0)
	var string_color: Color = Color(0.82, 0.78, 0.68, 1.0)
	image.fill_rect(Rect2i(4, 2, 2, 26), outline)
	image.fill_rect(Rect2i(10, 2, 2, 26), outline)
	image.fill_rect(Rect2i(5, 3, 1, 24), wood)
	image.fill_rect(Rect2i(10, 3, 1, 24), wood)
	image.fill_rect(Rect2i(6, 2, 5, 1), outline)
	image.fill_rect(Rect2i(6, 27, 5, 1), outline)
	for y in range(4, 26):
		image.set_pixel(8, y, string_color)
	return ImageTexture.create_from_image(image)


func _create_staff_texture() -> Texture2D:
	var image: Image = Image.create(12, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var outline: Color = Color(0.04, 0.03, 0.025, 1.0)
	var wood: Color = Color(0.43, 0.25, 0.12, 1.0)
	var ember: Color = Color(0.88, 0.47, 0.16, 1.0)
	image.fill_rect(Rect2i(4, 5, 4, 40), outline)
	image.fill_rect(Rect2i(5, 6, 2, 38), wood)
	image.fill_rect(Rect2i(2, 0, 8, 8), outline)
	image.fill_rect(Rect2i(3, 1, 6, 6), ember)
	return ImageTexture.create_from_image(image)


func _create_wand_texture() -> Texture2D:
	var image: Image = Image.create(20, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var outline: Color = Color(0.04, 0.03, 0.025, 1.0)
	var wood: Color = Color(0.41, 0.25, 0.12, 1.0)
	var crystal: Color = Color(0.48, 0.78, 0.96, 1.0)
	image.fill_rect(Rect2i(1, 4, 13, 3), outline)
	image.fill_rect(Rect2i(2, 5, 11, 1), wood)
	image.fill_rect(Rect2i(13, 3, 6, 5), outline)
	image.fill_rect(Rect2i(14, 4, 4, 3), crystal)
	return ImageTexture.create_from_image(image)


func _create_greatsword_texture() -> Texture2D:
	var image: Image = Image.create(14, 38, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var outline: Color = Color(0.04, 0.03, 0.025, 1.0)
	var steel_dark: Color = Color(0.46, 0.47, 0.50, 1.0)
	var steel: Color = Color(0.79, 0.83, 0.80, 1.0)
	var leather: Color = Color(0.25, 0.15, 0.08, 1.0)
	image.fill_rect(Rect2i(4, 0, 6, 22), outline)
	image.fill_rect(Rect2i(5, 1, 4, 20), steel_dark)
	image.fill_rect(Rect2i(6, 1, 2, 18), steel)
	image.fill_rect(Rect2i(2, 22, 10, 3), outline)
	image.fill_rect(Rect2i(3, 23, 8, 1), steel_dark)
	image.fill_rect(Rect2i(5, 25, 4, 10), outline)
	image.fill_rect(Rect2i(6, 26, 2, 8), leather)
	return ImageTexture.create_from_image(image)


func _create_axe_texture() -> Texture2D:
	var image: Image = Image.create(24, 14, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var outline: Color = Color(0.04, 0.03, 0.025, 1.0)
	var wood: Color = Color(0.43, 0.25, 0.12, 1.0)
	var steel: Color = Color(0.74, 0.78, 0.80, 1.0)
	image.fill_rect(Rect2i(1, 6, 15, 3), outline)
	image.fill_rect(Rect2i(2, 7, 13, 1), wood)
	image.fill_rect(Rect2i(14, 2, 8, 10), outline)
	image.fill_rect(Rect2i(15, 3, 5, 8), steel)
	image.fill_rect(Rect2i(20, 5, 2, 4), steel)
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
