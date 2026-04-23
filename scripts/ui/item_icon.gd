extends Control

const OUTLINE_COLOR := Color(0.05, 0.06, 0.055, 0.95)
const METAL_COLOR := Color(0.78, 0.82, 0.78, 1.0)
const WOOD_COLOR := Color(0.48, 0.29, 0.14, 1.0)
const CLOTH_COLOR := Color(0.62, 0.74, 0.44, 1.0)
const HERB_COLOR := Color(0.32, 0.73, 0.34, 1.0)
const JELLY_COLOR := Color(0.42, 0.86, 0.75, 1.0)
const POTION_COLOR := Color(0.86, 0.18, 0.22, 1.0)
const PAPER_COLOR := Color(0.86, 0.78, 0.54, 1.0)
const RATION_COLOR := Color(0.72, 0.46, 0.22, 1.0)
const BUCKLER_COLOR := Color(0.53, 0.35, 0.18, 1.0)

var item_name: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(38, 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_item_name(value: String) -> void:
	item_name = value
	queue_redraw()


func _draw() -> void:
	if item_name.is_empty():
		return

	match item_name:
		"Traveler Knife":
			_draw_knife()
		"Hunter Bow":
			_draw_bow()
		"Ash Staff":
			_draw_staff()
		"Willow Wand":
			_draw_wand()
		"Iron Greatsword":
			_draw_greatsword()
		"Woodsman Axe":
			_draw_axe()
		"Village Tunic":
			_draw_tunic()
		"Oak Buckler":
			_draw_buckler()
		"Slime Jelly":
			_draw_jelly()
		"Healer's Herbs":
			_draw_herbs()
		"Trail Ration":
			_draw_ration()
		"Minor Potion":
			_draw_potion()
		"Supply Ledger":
			_draw_ledger()
		_:
			_draw_generic_item()


func _draw_knife() -> void:
	var blade := PackedVector2Array([
		Vector2(20, 3),
		Vector2(32, 8),
		Vector2(14, 19),
		Vector2(10, 15)
	])
	draw_polygon(blade, PackedColorArray([METAL_COLOR]))
	draw_polyline(blade, OUTLINE_COLOR, 1.2, true)
	draw_line(Vector2(13, 18), Vector2(7, 25), WOOD_COLOR, 4.0)
	draw_line(Vector2(13, 18), Vector2(7, 25), OUTLINE_COLOR, 1.1)


func _draw_bow() -> void:
	draw_arc(Vector2(14, 15), 10.0, -1.2, 1.2, 18, WOOD_COLOR, 3.0)
	draw_line(Vector2(18, 6), Vector2(18, 24), METAL_COLOR, 1.4)
	draw_line(Vector2(13, 10), Vector2(28, 15), Color(0.84, 0.80, 0.70, 1.0), 1.2)
	draw_line(Vector2(26, 14), Vector2(31, 9), METAL_COLOR, 2.0)


func _draw_staff() -> void:
	draw_line(Vector2(11, 25), Vector2(24, 5), WOOD_COLOR, 4.0)
	draw_line(Vector2(11, 25), Vector2(24, 5), OUTLINE_COLOR, 1.0)
	draw_circle(Vector2(26, 7), 4.5, Color(0.94, 0.58, 0.18, 1.0))
	draw_arc(Vector2(26, 7), 4.5, 0.0, TAU, 18, OUTLINE_COLOR, 1.0)


func _draw_wand() -> void:
	draw_line(Vector2(12, 24), Vector2(23, 8), WOOD_COLOR.darkened(0.15), 3.2)
	draw_line(Vector2(12, 24), Vector2(23, 8), OUTLINE_COLOR, 1.0)
	draw_circle(Vector2(25, 6), 3.5, Color(0.48, 0.78, 0.98, 1.0))
	draw_circle(Vector2(17, 12), 1.6, Color(0.88, 0.95, 1.0, 0.72))


func _draw_greatsword() -> void:
	draw_line(Vector2(8, 24), Vector2(18, 20), WOOD_COLOR, 3.0)
	draw_line(Vector2(16, 21), Vector2(22, 19), OUTLINE_COLOR, 2.2)
	draw_polygon(PackedVector2Array([
		Vector2(22, 18),
		Vector2(31, 7),
		Vector2(33, 9),
		Vector2(25, 21)
	]), PackedColorArray([METAL_COLOR]))
	draw_polyline(PackedVector2Array([
		Vector2(22, 18),
		Vector2(31, 7),
		Vector2(33, 9),
		Vector2(25, 21)
	]), OUTLINE_COLOR, 1.1, true)


func _draw_axe() -> void:
	draw_line(Vector2(12, 25), Vector2(23, 7), WOOD_COLOR, 3.2)
	draw_line(Vector2(12, 25), Vector2(23, 7), OUTLINE_COLOR, 1.0)
	draw_polygon(PackedVector2Array([
		Vector2(20, 8),
		Vector2(30, 10),
		Vector2(28, 18),
		Vector2(21, 15)
	]), PackedColorArray([METAL_COLOR]))
	draw_polyline(PackedVector2Array([
		Vector2(20, 8),
		Vector2(30, 10),
		Vector2(28, 18),
		Vector2(21, 15)
	]), OUTLINE_COLOR, 1.0, true)


func _draw_tunic() -> void:
	var body := Rect2(Vector2(10, 9), Vector2(18, 17))
	draw_rect(body, CLOTH_COLOR, true)
	draw_rect(body, OUTLINE_COLOR, false, 1.2)
	draw_polygon(PackedVector2Array([Vector2(10, 10), Vector2(4, 15), Vector2(8, 20), Vector2(12, 16)]), PackedColorArray([CLOTH_COLOR]))
	draw_polygon(PackedVector2Array([Vector2(28, 10), Vector2(34, 15), Vector2(30, 20), Vector2(26, 16)]), PackedColorArray([CLOTH_COLOR]))
	draw_rect(Rect2(Vector2(16, 9), Vector2(6, 6)), Color(0.12, 0.14, 0.13, 1.0), true)


func _draw_buckler() -> void:
	draw_circle(Vector2(19, 15), 11.0, BUCKLER_COLOR)
	draw_circle(Vector2(19, 15), 7.0, Color(0.66, 0.46, 0.24, 1.0))
	draw_circle(Vector2(19, 15), 3.0, METAL_COLOR)
	draw_arc(Vector2(19, 15), 11.0, 0.0, TAU, 24, OUTLINE_COLOR, 1.2)


func _draw_jelly() -> void:
	draw_circle(Vector2(19, 17), 11.0, JELLY_COLOR)
	draw_circle(Vector2(15, 13), 3.0, Color(0.82, 1.0, 0.92, 0.7))
	draw_line(Vector2(10, 23), Vector2(28, 23), Color(0.22, 0.48, 0.42, 1.0), 2.0)


func _draw_herbs() -> void:
	draw_line(Vector2(19, 23), Vector2(19, 8), Color(0.23, 0.48, 0.22, 1.0), 2.0)
	draw_circle(Vector2(13, 12), 5.0, HERB_COLOR)
	draw_circle(Vector2(23, 11), 5.0, HERB_COLOR)
	draw_circle(Vector2(15, 18), 5.0, Color(0.45, 0.82, 0.36, 1.0))
	draw_circle(Vector2(25, 18), 4.0, Color(0.45, 0.82, 0.36, 1.0))


func _draw_ration() -> void:
	draw_rect(Rect2(Vector2(9, 9), Vector2(20, 14)), RATION_COLOR, true)
	draw_rect(Rect2(Vector2(9, 9), Vector2(20, 14)), OUTLINE_COLOR, false, 1.2)
	draw_line(Vector2(13, 13), Vector2(25, 13), Color(0.91, 0.68, 0.34, 1.0), 2.0)
	draw_line(Vector2(13, 19), Vector2(23, 19), Color(0.44, 0.25, 0.13, 1.0), 1.2)


func _draw_potion() -> void:
	draw_rect(Rect2(Vector2(15, 5), Vector2(8, 6)), METAL_COLOR, true)
	draw_circle(Vector2(19, 18), 9.0, POTION_COLOR)
	draw_rect(Rect2(Vector2(13, 12), Vector2(12, 8)), POTION_COLOR, true)
	draw_arc(Vector2(19, 18), 9.0, 0.0, TAU, 24, OUTLINE_COLOR, 1.2)
	draw_circle(Vector2(16, 15), 2.5, Color(1.0, 0.72, 0.72, 0.7))


func _draw_ledger() -> void:
	draw_rect(Rect2(Vector2(10, 5), Vector2(19, 22)), PAPER_COLOR, true)
	draw_rect(Rect2(Vector2(10, 5), Vector2(19, 22)), OUTLINE_COLOR, false, 1.2)
	draw_line(Vector2(14, 12), Vector2(25, 12), OUTLINE_COLOR, 1.0)
	draw_line(Vector2(14, 17), Vector2(25, 17), OUTLINE_COLOR, 1.0)
	draw_line(Vector2(14, 22), Vector2(22, 22), OUTLINE_COLOR, 1.0)


func _draw_generic_item() -> void:
	draw_circle(Vector2(19, 15), 9.0, Color(0.74, 0.7, 0.42, 1.0))
	draw_arc(Vector2(19, 15), 9.0, 0.0, TAU, 24, OUTLINE_COLOR, 1.2)
