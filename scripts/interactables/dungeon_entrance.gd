extends StaticBody2D

@export var speaker_name: String = "Old Mine Gate"
@export var scene_path: String = "res://scenes/world/dungeon_run.tscn"

@onready var glow: Polygon2D = $SpriteRoot/Glow

var interaction_highlighted: bool = false
var highlight_time: float = 0.0


func _ready() -> void:
	add_to_group("dungeon_entrance")
	_update_visual_state()


func _process(delta: float) -> void:
	if not interaction_highlighted:
		if glow != null:
			glow.visible = false
		return

	highlight_time += delta
	if glow != null:
		glow.visible = true
		glow.color = Color(0.62, 0.83, 1.0, 0.16 + sin(highlight_time * 2.1) * 0.04)


func get_dialogue_lines() -> PackedStringArray:
	return PackedStringArray(["Cold air rises from below. The dungeon waits."])


func set_interaction_highlight(value: bool) -> void:
	interaction_highlighted = value
	_update_visual_state()


func _update_visual_state() -> void:
	if glow != null:
		glow.visible = interaction_highlighted
