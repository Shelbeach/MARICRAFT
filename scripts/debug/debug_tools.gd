extends CanvasLayer

const MENU := preload("res://scenes/ui/developer_menu.tscn")

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(MENU.instantiate())

func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("developer_menu"):
		$DeveloperMenu.toggle()
		get_viewport().set_input_as_handled()
