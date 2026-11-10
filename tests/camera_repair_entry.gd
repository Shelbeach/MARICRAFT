extends Node
func _ready() -> void:
	var tree=get_tree()
	var options=JSON.parse_string(str(JavaScriptBridge.get_interface("window").cameraOptions))
	if str(options.get("mode","")).begins_with("arena_"):
		tree.set_script(load("res://tests/arena_polish_web.gd"))
	else:
		tree.set_script(load("res://tests/camera_repair_web.gd"))
	tree._initialize()
