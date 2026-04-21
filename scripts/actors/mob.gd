extends CharacterBody2D

@export var enemy_id: String = ""
@export var enemy_name: String = "Mob"
@export var enemy_type: String = ""
@export_enum("beast", "humanoid", "boss") var mob_category: String = "beast"
@export_enum("normal", "rare", "epic") var enemy_rarity: String = "normal"
@export var move_speed: float = 74.0
@export var max_health: int = 3
@export var contact_damage: int = 1
@export var chase_radius: float = 150.0
@export var attack_range: float = 28.0
@export var attack_cooldown: float = 1.0
@export var faction: String = "wild"
@export var is_boss: bool = false
@export var xp_reward: int = 4
@export var gold_reward: int = 0
@export var loot_drop_name: String = ""
@export var loot_drop_kind: String = "consumable"
@export var loot_table_id: String = ""
@export var dialogue_id: String = ""

signal defeated(enemy_id: String, enemy_name: String, xp_reward: int, gold_reward: int, loot_drop_name: String, loot_drop_kind: String, faction: String, is_boss: bool)
signal attacked_player(damage: int, enemy_name: String)

var current_health: int = 0
var attack_cooldown_remaining: float = 0.0
var player: Node2D = null
var spawn_position: Vector2 = Vector2.ZERO
var defeated_state: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var name_label: Label = null
var attack_feedback_remaining: float = 0.0
var attack_feedback_duration: float = 0.18
var attack_feedback_direction: Vector2 = Vector2.RIGHT
var attack_visual_base_position: Vector2 = Vector2.ZERO
var attack_visual_node: Node2D = null
var facing_direction: Vector2 = Vector2.DOWN
var facing_name: String = "down"

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar_root: Control = $HealthBarRoot
@onready var health_bar: ProgressBar = $HealthBarRoot/HealthBar

const RARITY_NAME_COLORS := {
	"normal": Color(0.96, 0.96, 0.90, 1.0),
	"rare": Color(1.0, 0.86, 0.24, 1.0),
	"epic": Color(1.0, 0.48, 0.14, 1.0)
}


func _ready() -> void:
	current_health = max_health
	spawn_position = global_position
	add_to_group("enemies")
	_configure_name_label()
	_configure_health_bar()
	_configure_attack_visual()
	_on_facing_direction_changed(facing_name)
	set_defeated(false)


func _physics_process(delta: float) -> void:
	if defeated_state:
		velocity = Vector2.ZERO
		return

	if attack_cooldown_remaining > 0.0:
		attack_cooldown_remaining = maxf(0.0, attack_cooldown_remaining - delta)
	if attack_feedback_remaining > 0.0:
		attack_feedback_remaining = maxf(0.0, attack_feedback_remaining - delta)

	if player == null:
		velocity = Vector2.ZERO
		_update_attack_feedback()
		return

	var offset: Vector2 = player.global_position - global_position
	var distance: float = offset.length()
	if offset.length_squared() > 0.01:
		attack_feedback_direction = offset.normalized()
		_set_facing_direction(attack_feedback_direction)

	if distance <= chase_radius:
		if distance > attack_range:
			velocity = offset.normalized() * move_speed
		else:
			velocity = Vector2.ZERO
			if attack_cooldown_remaining <= 0.0:
				attack_cooldown_remaining = attack_cooldown
				_trigger_attack_feedback(attack_feedback_direction)
				attacked_player.emit(contact_damage, enemy_name)
	else:
		velocity = Vector2.ZERO

	if knockback_velocity.length_squared() > 0.1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 420.0 * delta)
	else:
		knockback_velocity = Vector2.ZERO

	move_and_slide()
	_update_attack_feedback()


func set_player(target: Node2D) -> void:
	player = target


func take_damage(amount: int, hit_origin: Vector2 = Vector2.ZERO, has_hit_origin: bool = false) -> void:
	if amount <= 0 or current_health <= 0 or defeated_state:
		return

	current_health = maxi(0, current_health - amount)
	_update_health_bar()
	modulate = Color(1.0, 0.78, 0.78, 1.0)
	scale = Vector2(1.08, 0.92)

	if has_hit_origin:
		var knockback_direction: Vector2 = global_position - hit_origin
		if knockback_direction.length_squared() > 0.01:
			knockback_velocity = knockback_direction.normalized() * 135.0

	if current_health <= 0:
		set_defeated(true)
		defeated.emit(enemy_id, enemy_name, xp_reward, gold_reward, loot_drop_name, loot_drop_kind, faction, is_boss)
		return

	var flash_timer := get_tree().create_timer(0.12)
	flash_timer.timeout.connect(_clear_hit_flash)


func _clear_hit_flash() -> void:
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	scale = Vector2.ONE


func set_defeated(value: bool) -> void:
	defeated_state = value
	visible = not value
	set_physics_process(not value)

	if collision_shape != null:
		collision_shape.disabled = value

	if health_bar_root != null:
		health_bar_root.visible = not value
	if name_label != null:
		name_label.visible = not value

	if not value:
		current_health = max_health
		knockback_velocity = Vector2.ZERO
		attack_feedback_remaining = 0.0
		_reset_attack_visual()
		_update_health_bar()
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		scale = Vector2.ONE


func _configure_name_label() -> void:
	name_label = get_node_or_null("NameLabel") as Label
	if name_label == null:
		name_label = Label.new()
		name_label.name = "NameLabel"
		name_label.position = Vector2(-56, -52)
		name_label.size = Vector2(112, 20)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(name_label)

	name_label.text = enemy_name
	name_label.add_theme_color_override("font_color", RARITY_NAME_COLORS.get(enemy_rarity, RARITY_NAME_COLORS["normal"]))
	name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.add_theme_font_size_override("font_size", 11)


func _configure_health_bar() -> void:
	if health_bar_root == null or health_bar == null:
		return

	health_bar_root.visible = true
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.visible = false


func _configure_attack_visual() -> void:
	attack_visual_node = get_node_or_null("Body") as Node2D
	if attack_visual_node == null:
		return

	attack_visual_base_position = attack_visual_node.position


func _trigger_attack_feedback(direction: Vector2) -> void:
	attack_feedback_direction = direction
	attack_feedback_remaining = attack_feedback_duration
	_on_attack_feedback_started(facing_name)


func _update_attack_feedback() -> void:
	if attack_visual_node == null:
		return

	if attack_feedback_remaining <= 0.0:
		_reset_attack_visual()
		return

	var progress: float = 1.0 - (attack_feedback_remaining / attack_feedback_duration)
	var arc: float = sin(progress * PI)
	var lunge_distance: float = 5.0
	var squash: float = 0.0

	match mob_category:
		"beast":
			lunge_distance = 9.0
			squash = 0.10
		"humanoid":
			lunge_distance = 6.0
			squash = 0.04
		"boss":
			lunge_distance = 11.0
			squash = 0.07
		_:
			lunge_distance = 5.0

	attack_visual_node.position = attack_visual_base_position + attack_feedback_direction * (arc * lunge_distance)
	attack_visual_node.scale = Vector2(1.0 + arc * squash, 1.0 - arc * squash * 0.55)


func _reset_attack_visual() -> void:
	if attack_visual_node == null:
		return

	attack_visual_node.position = attack_visual_base_position
	attack_visual_node.scale = Vector2.ONE
	_on_attack_feedback_finished(facing_name)


func _set_facing_direction(direction: Vector2) -> void:
	if direction.length_squared() <= 0.01:
		return

	facing_direction = direction.normalized()
	var next_facing_name: String = _direction_to_name(facing_direction)
	if next_facing_name == facing_name:
		return

	facing_name = next_facing_name
	_on_facing_direction_changed(facing_name)


func _direction_to_name(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "left" if direction.x < 0.0 else "right"

	return "up" if direction.y < 0.0 else "down"


func _on_facing_direction_changed(_direction_name: String) -> void:
	pass


func _on_attack_feedback_started(_direction_name: String) -> void:
	pass


func _on_attack_feedback_finished(_direction_name: String) -> void:
	pass


func _update_health_bar() -> void:
	if health_bar == null:
		return

	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.visible = current_health < max_health and current_health > 0
