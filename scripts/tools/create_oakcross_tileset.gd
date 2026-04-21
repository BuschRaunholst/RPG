extends SceneTree

const TILE_SIZE := Vector2i(32, 32)
const ATLAS_COLUMNS := 24
const ATLAS_PATH := "res://assets/art/tilesets/oakcross_ground_32.png"
const TILESET_PATH := "res://assets/art/tilesets/oakcross_ground_tileset.tres"


func _init() -> void:
	var atlas_texture: Texture2D = load(ATLAS_PATH)
	if atlas_texture == null:
		push_error("Could not load atlas: %s" % ATLAS_PATH)
		quit(1)
		return

	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE

	var source := TileSetAtlasSource.new()
	source.texture = atlas_texture
	source.texture_region_size = TILE_SIZE

	for x in range(ATLAS_COLUMNS):
		source.create_tile(Vector2i(x, 0))

	tile_set.add_source(source, 0)

	var error := ResourceSaver.save(tile_set, TILESET_PATH)
	if error != OK:
		push_error("Could not save tileset: %s" % TILESET_PATH)
		quit(1)
		return

	print("Created %s from %s" % [TILESET_PATH, ATLAS_PATH])
	quit()
