extends Control

@onready var continue_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ContinueButton
@onready var status_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel


func _ready() -> void:
	GameSession.hide_game_overlay()
	continue_button.disabled = not GameSession.has_save()

	if continue_button.disabled:
		status_label.text = "Start a new journey in Oakcross Village."
	else:
		status_label.text = "A save is ready. Continue where you left off."


func _on_new_game_button_pressed() -> void:
	status_label.text = "Preparing a fresh start..."
	GameSession.start_new_game()


func _on_continue_button_pressed() -> void:
	status_label.text = "Loading your adventure..."
	GameSession.continue_game()
