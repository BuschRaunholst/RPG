extends RefCounted

var _data: Dictionary = {}


func load_from_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Dialogue data file not found: %s" % path)
		return

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Dialogue data in %s is not a dictionary." % path)
		return

	_data = parsed


func get_entry(npc_id: String, state: String) -> Dictionary:
	var npc_data: Dictionary = _data.get(npc_id, {})
	var raw_entry: Variant = npc_data.get(state, null)

	if raw_entry == null:
		return {}

	if typeof(raw_entry) == TYPE_ARRAY:
		return {
			"lines": _to_packed_string_array(raw_entry)
		}

	if typeof(raw_entry) == TYPE_DICTIONARY:
		var entry: Dictionary = raw_entry
		var normalized: Dictionary = {}
		normalized["lines"] = _to_packed_string_array(entry.get("lines", []))
		normalized["choices"] = entry.get("choices", [])
		normalized["effects"] = entry.get("effects", {})
		return normalized

	return {}


func get_lines(npc_id: String, state: String) -> PackedStringArray:
	return get_entry(npc_id, state).get("lines", PackedStringArray())


func _to_packed_string_array(raw_lines: Variant) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()

	if typeof(raw_lines) != TYPE_ARRAY:
		return lines

	for raw_line in raw_lines:
		lines.append(str(raw_line))

	return lines
