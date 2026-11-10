extends Control

func _ready() -> void:
	$Start.grab_focus()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/test_field.tscn")

func _draw() -> void:
	var mint := Color("#75cbb6")
	var line := Color("#345363")
	draw_line(Vector2(54, 76), Vector2(906, 76), line, 2)
	draw_line(Vector2(54, 460), Vector2(906, 460), line, 2)
	for i in 3:
		var top := Vector2(610 + 84 * i, 330 - 42 * i)
		draw_rect(Rect2(top, Vector2(68, 14)), line)
		draw_rect(Rect2(top, Vector2(68, 3)), mint)
	draw_rect(Rect2(808, 208, 24, 32), Color("#ffb849"))
