extends StaticBody2D

@export var speaker_name: String = "Dungeon Stairs"
@export var target_depth: int = 2

@onready var sprite_root: Node2D = $SpriteRoot
@onready var glow: Polygon2D = $SpriteRoot/Glow

var interaction_highlighted: bool = false
var highlight_time: float = 0.0


func _ready() -> void:
	add_to_group("dungeon_stairs")
	_update_visual_state()


func _process(delta: float) -> void:
	if not interaction_highlighted:
		if glow != null:
			glow.visible = false
		return

	highlight_time += delta
	if glow != null:
		glow.visible = true
		glow.color = Color(0.76, 0.94, 1.0, 0.18 + sin(highlight_time * 2.4) * 0.05)


func get_dialogue_lines() -> PackedStringArray:
	if target_depth <= 0:
		return PackedStringArray(["The stairs lead back to the village."])
	return PackedStringArray(["The stairs lead to dungeon depth %d." % target_depth])


func set_interaction_highlight(value: bool) -> void:
	interaction_highlighted = value
	_update_visual_state()


func _update_visual_state() -> void:
	if glow != null:
		glow.visible = interaction_highlighted
