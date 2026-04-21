extends SceneTree

const FRAME_SIZE := Vector2(64, 64)
const LAYERS := [
	{
		"sheet": "res://assets/art/characters/player_human_base_4dir_64.png",
		"output": "res://assets/art/characters/player_human_base_4dir_64_frames.tres"
	},
	{
		"sheet": "res://assets/art/characters/player_clothes_village_tunic_4dir_64.png",
		"output": "res://assets/art/characters/player_clothes_village_tunic_4dir_64_frames.tres"
	},
	{
		"sheet": "res://assets/art/characters/player_boots_worn_4dir_64.png",
		"output": "res://assets/art/characters/player_boots_worn_4dir_64_frames.tres"
	}
]


func _initialize() -> void:
	for layer_data: Dictionary in LAYERS:
		_build_layer_frames(str(layer_data.get("sheet", "")), str(layer_data.get("output", "")))

	quit()


func _build_layer_frames(sheet_path: String, output_path: String) -> void:
	var image := Image.new()
	var load_error: Error = image.load(ProjectSettings.globalize_path(sheet_path))
	if load_error != OK:
		push_error("Could not load player sheet: %s" % sheet_path)
		quit(1)
		return
	var sheet: ImageTexture = ImageTexture.create_from_image(image)

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	_add_animation(frames, sheet, "idle_down", 0, [0], 4.0, true)
	_add_animation(frames, sheet, "walk_down", 0, [1, 0, 2, 0], 7.0, true)
	_add_animation(frames, sheet, "idle_left", 1, [0], 4.0, true)
	_add_animation(frames, sheet, "walk_left", 1, [1, 0, 2, 0], 7.0, true)
	_add_animation(frames, sheet, "idle_right", 2, [0], 4.0, true)
	_add_animation(frames, sheet, "walk_right", 2, [1, 0, 2, 0], 7.0, true)
	_add_animation(frames, sheet, "idle_up", 3, [0], 4.0, true)
	_add_animation(frames, sheet, "walk_up", 3, [1, 0, 2, 0], 7.0, true)

	var error := ResourceSaver.save(frames, output_path)
	if error != OK:
		push_error("Could not save player SpriteFrames: %s" % output_path)
		quit(1)
		return


func _add_animation(frames: SpriteFrames, sheet: Texture2D, animation_name: StringName, row: int, columns: Array[int], speed: float, loop: bool) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, loop)

	for column: int in columns:
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = sheet
		atlas_texture.region = Rect2(Vector2(column * FRAME_SIZE.x, row * FRAME_SIZE.y), FRAME_SIZE)
		frames.add_frame(animation_name, atlas_texture)
