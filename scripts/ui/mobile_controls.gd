extends Control

const JOYSTICK_RADIUS: float = 56.0
const KNOB_RADIUS: float = 28.0
const CONTROL_SIDE_MARGIN := 18.0
const CONTROL_BOTTOM_MARGIN := 18.0
const COMPACT_CONTROL_WIDTH := 760.0
const JOYSTICK_PADDING := 12.0
const ACTION_SWORD_ICON_PATH := "res://assets/art/ui/icons/action_attack.png"
const ACTION_HAND_ICON_PATH := "res://assets/art/ui/icons/action_use.png"
const ACTION_TALK_ICON_PATH := "res://assets/art/ui/icons/action_talk.png"

signal quick_item_pressed
signal context_action_pressed

@onready var joystick_plate: Panel = $JoystickPlate
@onready var joystick_area: Control = $JoystickArea
@onready var joystick_outer_ring: Panel = $JoystickArea/OuterRing
@onready var joystick_inner_ring: Panel = $JoystickArea/InnerRing
@onready var joystick_knob_shadow: Panel = $JoystickArea/KnobShadow
@onready var joystick_knob: Panel = $JoystickArea/Knob
@onready var interact_button: Button = $InteractButton
@onready var action_icon: TextureRect = $InteractButton/ActionIcon
@onready var quick_item_button: Button = $QuickItemButton
@onready var quick_item_icon: Control = $QuickItemButton/ItemIcon
@onready var mana_potion_button: Button = $ManaPotionButton
@onready var mana_potion_icon: Control = $ManaPotionButton/ItemIcon
@onready var skill_buttons: Array[Button] = [
	$SkillButton1,
	$SkillButton2,
	$SkillButton3,
	$SkillButton4
]

var active_pointer_id: int = -1
var joystick_vector: Vector2 = Vector2.ZERO
var joystick_center: Vector2 = Vector2.ZERO
var controls_enabled: bool = true
var current_action_label: String = "Attack"
var action_icon_cache: Dictionary = {}
var hp_slot_item_name: String = ""
var hp_slot_item_count: int = 0
var mp_slot_item_name: String = ""
var mp_slot_item_count: int = 0


func _ready() -> void:
	joystick_area.gui_input.connect(_on_joystick_gui_input)
	interact_button.pressed.connect(_on_interact_button_pressed)
	quick_item_button.button_down.connect(_on_quick_item_button_down)
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_prime_action_icon_cache()
	call_deferred("_apply_layout")


func _process(_delta: float) -> void:
	if not controls_enabled:
		_release_move_actions()
		return

	Input.action_press("move_left", maxf(0.0, -joystick_vector.x))
	Input.action_press("move_right", maxf(0.0, joystick_vector.x))
	Input.action_press("move_up", maxf(0.0, -joystick_vector.y))
	Input.action_press("move_down", maxf(0.0, joystick_vector.y))


func _exit_tree() -> void:
	_release_move_actions()
	Input.action_release("interact")
	Input.action_release("attack")


func _on_joystick_gui_input(event: InputEvent) -> void:
	if not controls_enabled:
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed and active_pointer_id == -1:
			active_pointer_id = touch_event.index
			_update_joystick(touch_event.position)
			joystick_area.accept_event()
		elif not touch_event.pressed and touch_event.index == active_pointer_id:
			active_pointer_id = -1
			_reset_joystick()
			joystick_area.accept_event()
	elif event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event
		if drag_event.index == active_pointer_id:
			_update_joystick(drag_event.position)
			joystick_area.accept_event()
	elif event is InputEventMouseButton:
		var mouse_button_event: InputEventMouseButton = event
		if mouse_button_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button_event.pressed and active_pointer_id == -1:
			active_pointer_id = -2
			_update_joystick(mouse_button_event.position)
			joystick_area.accept_event()
		elif not mouse_button_event.pressed and active_pointer_id == -2:
			active_pointer_id = -1
			_reset_joystick()
			joystick_area.accept_event()
	elif event is InputEventMouseMotion and active_pointer_id == -2:
		var mouse_motion_event: InputEventMouseMotion = event
		_update_joystick(mouse_motion_event.position)
		joystick_area.accept_event()


func _on_viewport_size_changed() -> void:
	_apply_layout()


func _update_joystick(local_position: Vector2) -> void:
	var offset: Vector2 = local_position - joystick_center
	if offset.length() > JOYSTICK_RADIUS:
		offset = offset.normalized() * JOYSTICK_RADIUS

	joystick_vector = offset / JOYSTICK_RADIUS
	var knob_position: Vector2 = joystick_center + offset - Vector2(KNOB_RADIUS, KNOB_RADIUS)
	joystick_knob.position = knob_position
	joystick_knob_shadow.position = knob_position + Vector2(0.0, 4.0)


func _reset_joystick() -> void:
	joystick_vector = Vector2.ZERO
	var knob_position: Vector2 = joystick_center - Vector2(KNOB_RADIUS, KNOB_RADIUS)
	joystick_knob.position = knob_position
	joystick_knob_shadow.position = knob_position + Vector2(0.0, 4.0)
	_release_move_actions()


func _release_move_actions() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")


func _on_interact_button_pressed() -> void:
	if not controls_enabled:
		return
	context_action_pressed.emit()


func _on_quick_item_button_down() -> void:
	if not controls_enabled or quick_item_button.disabled:
		return
	quick_item_pressed.emit()


func set_controls_enabled(value: bool) -> void:
	controls_enabled = value
	visible = value
	if not controls_enabled:
		active_pointer_id = -1
		_reset_joystick()
		Input.action_release("interact")
		Input.action_release("attack")


func set_quick_item(item_name: String, item_count: int) -> void:
	hp_slot_item_name = item_name
	hp_slot_item_count = item_count
	_update_potion_slot_labels()


func set_mana_item(item_name: String, item_count: int) -> void:
	mp_slot_item_name = item_name
	mp_slot_item_count = item_count
	_update_potion_slot_labels()


func _update_potion_slot_labels() -> void:
	if hp_slot_item_name.is_empty() or hp_slot_item_count <= 0:
		quick_item_button.text = "HP"
		quick_item_button.disabled = true
		if quick_item_icon != null:
			quick_item_icon.visible = false
	else:
		quick_item_button.text = "x%d" % hp_slot_item_count
		quick_item_button.disabled = false
		if quick_item_icon != null and quick_item_icon.has_method("set_item_name"):
			quick_item_icon.call("set_item_name", hp_slot_item_name)
			quick_item_icon.visible = true

	if mp_slot_item_name.is_empty() or mp_slot_item_count <= 0:
		mana_potion_button.text = "MP"
		mana_potion_button.disabled = true
		if mana_potion_icon != null:
			mana_potion_icon.visible = false
	else:
		mana_potion_button.text = "x%d" % mp_slot_item_count
		mana_potion_button.disabled = false
		if mana_potion_icon != null and mana_potion_icon.has_method("set_item_name"):
			mana_potion_icon.call("set_item_name", mp_slot_item_name)
			mana_potion_icon.visible = true


func set_context_action_label(label_text: String) -> void:
	current_action_label = label_text
	interact_button.text = ""
	_update_action_button_icon()


func _short_item_name(item_name: String) -> String:
	match item_name:
		"Trail Ration":
			return "Ration"
		"Healer's Herbs":
			return "Herbs"
		_:
			return item_name


func _apply_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var compact: bool = viewport_size.x <= COMPACT_CONTROL_WIDTH
	var side_margin: float = 10.0 if compact else CONTROL_SIDE_MARGIN
	var bottom_margin: float = 12.0 if compact else CONTROL_BOTTOM_MARGIN
	var joystick_plate_size: float = clampf(minf(viewport_size.x, viewport_size.y) * (0.305 if compact else 0.27), 126.0, 154.0)
	var joystick_area_size: float = joystick_plate_size - JOYSTICK_PADDING * 2.0
	var ring_size: float = joystick_area_size - 6.0
	var inner_ring_size: float = ring_size - 24.0
	var main_action_size: float = clampf(minf(viewport_size.x, viewport_size.y) * (0.215 if compact else 0.195), 106.0, 122.0)
	var utility_size: float = clampf(main_action_size * 0.5, 54.0, 64.0)
	var skill_size: float = clampf(main_action_size * 0.48, 52.0, 60.0)
	var cluster_center: Vector2 = Vector2(
		viewport_size.x - side_margin - main_action_size * 0.74,
		viewport_size.y - bottom_margin - main_action_size * 0.66
	)

	joystick_plate.offset_left = side_margin
	joystick_plate.offset_top = viewport_size.y - bottom_margin - joystick_plate_size
	joystick_plate.offset_right = side_margin + joystick_plate_size
	joystick_plate.offset_bottom = viewport_size.y - bottom_margin

	joystick_area.offset_left = side_margin + JOYSTICK_PADDING
	joystick_area.offset_top = viewport_size.y - bottom_margin - joystick_plate_size + JOYSTICK_PADDING
	joystick_area.offset_right = joystick_area.offset_left + joystick_area_size
	joystick_area.offset_bottom = joystick_area.offset_top + joystick_area_size

	var ring_left: float = (joystick_area_size - ring_size) * 0.5
	var inner_left: float = (joystick_area_size - inner_ring_size) * 0.5
	joystick_outer_ring.position = Vector2(ring_left, ring_left)
	joystick_outer_ring.size = Vector2.ONE * ring_size
	joystick_inner_ring.position = Vector2(inner_left, inner_left)
	joystick_inner_ring.size = Vector2.ONE * inner_ring_size
	joystick_knob.size = Vector2.ONE * (KNOB_RADIUS * 2.0)
	joystick_knob_shadow.size = joystick_knob.size

	interact_button.position = cluster_center - Vector2.ONE * (main_action_size * 0.5)
	interact_button.size = Vector2.ONE * main_action_size
	interact_button.add_theme_font_size_override("font_size", 16 if compact else 18)
	if action_icon != null:
		var icon_size: float = main_action_size * 0.44
		action_icon.position = (interact_button.size - Vector2.ONE * icon_size) * 0.5
		action_icon.size = Vector2.ONE * icon_size
	_update_action_button_icon()

	var hp_x: float = interact_button.position.x - utility_size - 12.0
	var hp_y: float = interact_button.position.y + main_action_size - utility_size + 22.0
	quick_item_button.position = Vector2(hp_x, hp_y)
	quick_item_button.size = Vector2.ONE * utility_size
	quick_item_button.add_theme_font_size_override("font_size", 12 if compact else 13)
	if quick_item_icon != null:
		var icon_base_size := Vector2(38.0, 30.0)
		var icon_scale: float = (utility_size * 0.92) / icon_base_size.x
		quick_item_icon.scale = Vector2.ONE * icon_scale
		var scaled_icon_size: Vector2 = icon_base_size * icon_scale
		quick_item_icon.position = (quick_item_button.size - scaled_icon_size) * 0.5 + Vector2(0.0, -2.0)
		quick_item_icon.size = icon_base_size

	mana_potion_button.position = Vector2(hp_x - utility_size - 8.0, hp_y - 2.0)
	mana_potion_button.size = Vector2.ONE * utility_size
	mana_potion_button.add_theme_font_size_override("font_size", 12 if compact else 13)
	if mana_potion_icon != null:
		var mana_icon_base_size := Vector2(38.0, 30.0)
		var mana_icon_scale: float = (utility_size * 0.92) / mana_icon_base_size.x
		mana_potion_icon.scale = Vector2.ONE * mana_icon_scale
		var scaled_mana_icon_size: Vector2 = mana_icon_base_size * mana_icon_scale
		mana_potion_icon.position = (mana_potion_button.size - scaled_mana_icon_size) * 0.5 + Vector2(0.0, -2.0)
		mana_potion_icon.size = mana_icon_base_size

	var arc_center: Vector2 = cluster_center + Vector2(main_action_size * 0.06, 0.0)
	var skill_angles := [-170.0, -136.0, -102.0, -68.0]
	var skill_radius: float = main_action_size * 0.94
	for index in range(skill_buttons.size()):
		var button: Button = skill_buttons[index]
		button.size = Vector2.ONE * skill_size
		button.add_theme_font_size_override("font_size", 10 if compact else 11)
		var angle_radians: float = deg_to_rad(skill_angles[index])
		var button_center: Vector2 = arc_center + Vector2(cos(angle_radians), sin(angle_radians)) * skill_radius
		button.position = button_center - Vector2.ONE * (skill_size * 0.5)

	joystick_center = Vector2.ONE * (joystick_area_size * 0.5)
	_reset_joystick()


func _update_action_button_icon() -> void:
	if action_icon == null:
		return
	var icon_color: Color = Color(0.964706, 0.933333, 0.654902, 1.0)
	var icon_path: String = ACTION_SWORD_ICON_PATH
	var icon_scale: float = 0.48
	var icon_rotation: float = 0.0
	var icon_offset: Vector2 = Vector2.ZERO
	match current_action_label.to_lower():
		"talk":
			icon_path = ACTION_TALK_ICON_PATH
			icon_color = Color(0.862745, 0.827451, 0.576471, 0.94)
			action_icon.flip_h = false
			icon_scale = 0.50
		"use", "enter":
			icon_path = ACTION_HAND_ICON_PATH
			icon_color = Color(0.862745, 0.827451, 0.576471, 0.94)
			action_icon.flip_h = true
			icon_scale = 0.45
			icon_offset = Vector2(-2.0, -1.0)
		_:
			icon_path = ACTION_SWORD_ICON_PATH
			icon_color = Color(0.862745, 0.827451, 0.576471, 0.94)
			action_icon.flip_h = true
			icon_scale = 0.58
	action_icon.texture = _load_action_icon(icon_path, icon_color)
	action_icon.modulate = Color.WHITE
	action_icon.rotation_degrees = icon_rotation
	var icon_size: float = interact_button.size.x * icon_scale
	action_icon.size = Vector2.ONE * icon_size
	action_icon.position = (interact_button.size - action_icon.size) * 0.5 + icon_offset


func _load_action_icon(path: String, color: Color) -> Texture2D:
	var cache_key: String = "%s|%s" % [path, color.to_html(true)]
	if action_icon_cache.has(cache_key):
		return action_icon_cache[cache_key] as Texture2D

	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty():
		return null

	image.convert(Image.FORMAT_RGBA8)
	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x > 0 and used_rect.size.y > 0:
		image = image.get_region(used_rect)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			image.set_pixel(x, y, Color(color.r, color.g, color.b, pixel.a * color.a))

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	action_icon_cache[cache_key] = texture
	return texture


func _prime_action_icon_cache() -> void:
	var gold: Color = Color(0.862745, 0.827451, 0.576471, 0.94)
	_load_action_icon(ACTION_SWORD_ICON_PATH, gold)
	_load_action_icon(ACTION_HAND_ICON_PATH, gold)
	_load_action_icon(ACTION_TALK_ICON_PATH, gold)
