extends CanvasLayer

signal dialogue_finished
signal choice_selected(choice_id: String)

@onready var name_label: Label = $Panel/MarginContainer/VBoxContainer/NameLabel
@onready var body_label: Label = $Panel/MarginContainer/VBoxContainer/BodyLabel
@onready var hint_label: Label = $Panel/MarginContainer/VBoxContainer/HintLabel
@onready var choices_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ChoicesContainer
@onready var choice_a_button: Button = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/ChoiceA
@onready var choice_b_button: Button = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/ChoiceB

var dialogue_lines: PackedStringArray = []
var current_index: int = 0
var is_open: bool = false
var choice_ids: PackedStringArray = []
var choice_texts: PackedStringArray = []
var choice_index: int = 0
var is_showing_choices: bool = false


func _ready() -> void:
	choices_container.hide()
	choice_a_button.pressed.connect(_on_choice_a_pressed)
	choice_b_button.pressed.connect(_on_choice_b_pressed)
	hide()


func start_dialogue(speaker_name: String, lines: PackedStringArray) -> void:
	if lines.is_empty():
		return

	dialogue_lines = lines
	current_index = 0
	is_open = true
	is_showing_choices = false
	name_label.text = speaker_name
	_show_current_line()
	show()


func advance_dialogue() -> void:
	if not is_open:
		return

	if is_showing_choices:
		_emit_selected_choice()
		return

	current_index += 1

	if current_index >= dialogue_lines.size():
		close_dialogue()
		return

	_show_current_line()


func close_dialogue() -> void:
	dialogue_lines = []
	current_index = 0
	is_open = false
	is_showing_choices = false
	choice_ids = PackedStringArray()
	choice_texts = PackedStringArray()
	choices_container.hide()
	hide()
	dialogue_finished.emit()


func _show_current_line() -> void:
	body_label.text = dialogue_lines[current_index]
	choices_container.hide()
	is_showing_choices = false

	if current_index == dialogue_lines.size() - 1:
		hint_label.text = "Press E to close"
	else:
		hint_label.text = "Press E to continue"


func show_choices(speaker_name: String, prompt: String, choices: Array[Dictionary]) -> void:
	if choices.size() < 2:
		return

	is_open = true
	is_showing_choices = true
	name_label.text = speaker_name
	body_label.text = prompt
	choice_ids = PackedStringArray([
		str(choices[0].get("id", "choice_a")),
		str(choices[1].get("id", "choice_b"))
	])
	choice_texts = PackedStringArray([
		str(choices[0].get("text", "Choice A")),
		str(choices[1].get("text", "Choice B"))
	])
	choice_index = 0
	_refresh_choice_labels()
	choices_container.show()
	hint_label.text = "Tap a choice or use W/S and E"
	show()


func move_choice_selection(direction: int) -> void:
	if not is_showing_choices:
		return

	choice_index = clampi(choice_index + direction, 0, choice_ids.size() - 1)
	_refresh_choice_labels()


func _emit_selected_choice() -> void:
	if choice_index < 0 or choice_index >= choice_ids.size():
		return

	is_showing_choices = false
	choices_container.hide()
	choice_selected.emit(choice_ids[choice_index])


func _format_choice_text(choice_text: String, index: int) -> String:
	if index == choice_index:
		return "> " + choice_text

	return "  " + choice_text


func _refresh_choice_labels() -> void:
	if choice_texts.size() < 2:
		return

	choice_a_button.text = _format_choice_text(choice_texts[0], 0)
	choice_b_button.text = _format_choice_text(choice_texts[1], 1)


func _on_choice_a_pressed() -> void:
	if not is_showing_choices:
		return

	choice_index = 0
	_emit_selected_choice()


func _on_choice_b_pressed() -> void:
	if not is_showing_choices:
		return

	choice_index = 1
	_emit_selected_choice()
