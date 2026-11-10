extends Node2D

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	for hitbox: CollisionShape2D in get_tree().get_nodes_in_group("test_hitboxes"):
		var rectangle := hitbox.shape as RectangleShape2D
		if rectangle and not hitbox.disabled:
			var transform_2d := hitbox.get_global_transform_with_canvas()
			draw_set_transform_matrix(transform_2d)
			draw_rect(Rect2(-rectangle.size / 2, rectangle.size), Color("#ff86cf"), false, 2.0)
