extends SceneTree


func _init() -> void:
	var image: Image = Image.create(18, 34, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var outline: Color = Color(0.04, 0.03, 0.025, 1.0)
	var bow_dark: Color = Color(0.42, 0.10, 0.18, 1.0)
	var bow_mid: Color = Color(0.63, 0.17, 0.28, 1.0)
	var bow_light: Color = Color(0.78, 0.30, 0.38, 1.0)
	var wrap: Color = Color(0.86, 0.67, 0.24, 1.0)
	var string_color: Color = Color(0.84, 0.78, 0.63, 1.0)
	var bow_rows := {
		2: Vector2i(11, 13),
		3: Vector2i(9, 14),
		4: Vector2i(8, 14),
		5: Vector2i(7, 13),
		6: Vector2i(6, 12),
		7: Vector2i(5, 11),
		8: Vector2i(4, 10),
		9: Vector2i(4, 9),
		10: Vector2i(3, 8),
		11: Vector2i(3, 7),
		12: Vector2i(2, 6),
		13: Vector2i(2, 5),
		14: Vector2i(2, 5),
		15: Vector2i(2, 5),
		16: Vector2i(2, 5),
		17: Vector2i(2, 5),
		18: Vector2i(2, 5),
		19: Vector2i(2, 5),
		20: Vector2i(2, 5),
		21: Vector2i(2, 5),
		22: Vector2i(2, 6),
		23: Vector2i(2, 6),
		24: Vector2i(2, 6),
		25: Vector2i(2, 6),
		26: Vector2i(3, 6),
		27: Vector2i(3, 7),
		28: Vector2i(4, 8),
		29: Vector2i(5, 8),
		30: Vector2i(5, 7),
		31: Vector2i(5, 7),
		32: Vector2i(5, 6)
	}
	for y in bow_rows.keys():
		var row: Vector2i = bow_rows[y]
		for x in range(row.x, row.y + 1):
			var color: Color = bow_mid
			if y >= 22:
				color = bow_dark
			if x >= row.y - 1:
				color = bow_light if y < 22 else bow_mid
			if x == row.x or x == row.y:
				color = outline
			image.set_pixel(x, y, color)
	image.fill_rect(Rect2i(12, 2, 2, 3), wrap)
	image.fill_rect(Rect2i(5, 30, 2, 3), wrap)
	image.fill_rect(Rect2i(5, 12, 2, 8), outline)
	image.fill_rect(Rect2i(6, 13, 1, 6), bow_dark)
	for point in [Vector2i(10, 3), Vector2i(9, 4), Vector2i(8, 6), Vector2i(7, 8), Vector2i(4, 24), Vector2i(5, 27), Vector2i(6, 29)]:
		image.set_pixelv(point, bow_light)
	var string_points := [
		Vector2i(13, 3), Vector2i(13, 5), Vector2i(12, 7), Vector2i(12, 9),
		Vector2i(11, 11), Vector2i(11, 13), Vector2i(10, 15), Vector2i(10, 17),
		Vector2i(9, 19), Vector2i(9, 21), Vector2i(8, 23), Vector2i(8, 25),
		Vector2i(7, 27), Vector2i(7, 29), Vector2i(6, 31)
	]
	for point in string_points:
		image.set_pixelv(point, string_color)

	image.save_png("C:/Users/Jakob/Documents/RPG/bow_preview_check.png")
	var preview_large: Image = image.duplicate()
	preview_large.resize(180, 340, Image.INTERPOLATE_NEAREST)
	preview_large.save_png("C:/Users/Jakob/Documents/RPG/bow_preview_check_large.png")
	quit()
