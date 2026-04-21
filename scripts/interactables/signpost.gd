extends StaticBody2D

@export var sign_id: String = "signpost"
@export var speaker_name: String = "Signpost"
@export_multiline var message_text: String = "Oakcross Village\nMarket to the west\nSquare to the north"


func get_dialogue_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()

	for line in message_text.split("\n", false):
		var trimmed: String = line.strip_edges()

		if not trimmed.is_empty():
			lines.append(trimmed)

	return lines
