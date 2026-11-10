extends Node2D

func _ready() -> void:
	$Guide/Keys.text = "A / D   движение     ·     Пробел   прыжок"
	if OS.is_debug_build():
		$Guide/Keys.text += "     ·     F1   отладка"

func _draw() -> void:
	var ink := Color("#233c49")
	for x in range(0, 1921, 32):
		draw_line(Vector2(x, 144), Vector2(x, 480), ink)
	for y in range(160, 481, 32):
		draw_line(Vector2(0, y), Vector2(1920, y), ink)
	var font := ThemeDB.fallback_font
	var zones := ["01   /   СТАРТ", "02   /   УСТУПЫ", "03   /   ПЛОЩАДКИ"]
	for i in zones.size():
		draw_string(font, Vector2(44 + 640 * i, 208), zones[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#90aaaF"))
