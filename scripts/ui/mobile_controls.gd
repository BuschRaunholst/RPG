extends Control

const JOYSTICK_RADIUS: float = 56.0
const KNOB_RADIUS: float = 24.0

signal quick_item_pressed
signal context_action_pressed

@onready var joystick_area: Control = $JoystickArea
@onready var joystick_knob: Panel = $JoystickArea/Knob
@onready var interact_button: Button = $InteractButton
@onready var attack_button: Button = $AttackButton
@onready var quick_item_button: Button = $QuickItemButton

var active_pointer_id: int = -1
var joystick_vector: Vector2 = Vector2.ZERO
var joystick_center: Vector2 = Vector2.ZERO
var controls_enabled: bool = true


func _ready() -> void:
	joystick_area.gui_input.connect(_on_joystick_gui_input)
	interact_button.pressed.connect(_on_interact_button_pressed)
	quick_item_button.button_down.connect(_on_quick_item_button_down)
	attack_button.visible = false
	attack_button.disabled = true
	joystick_center = joystick_area.size * 0.5
	_reset_joystick()


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


func _update_joystick(local_position: Vector2) -> void:
	var offset: Vector2 = local_position - joystick_center

	if offset.length() > JOYSTICK_RADIUS:
		offset = offset.normalized() * JOYSTICK_RADIUS

	joystick_vector = offset / JOYSTICK_RADIUS
	joystick_knob.position = joystick_center + offset - Vector2(KNOB_RADIUS, KNOB_RADIUS)


func _reset_joystick() -> void:
	joystick_vector = Vector2.ZERO
	joystick_knob.position = joystick_center - Vector2(KNOB_RADIUS, KNOB_RADIUS)
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
	if item_name.is_empty() or item_count <= 0:
		quick_item_button.text = "Item"
		quick_item_button.disabled = true
		return

	quick_item_button.text = "%s\nx%d" % [_short_item_name(item_name), item_count]
	quick_item_button.disabled = false


func set_context_action_label(label_text: String) -> void:
	interact_button.text = label_text


func _short_item_name(item_name: String) -> String:
	match item_name:
		"Trail Ration":
			return "Ration"
		"Healer's Herbs":
			return "Herbs"
		_:
			return item_name
