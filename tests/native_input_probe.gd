extends SceneTree
class Probe extends Node:
	func _input(event:InputEvent) -> void:
		if event is InputEventKey:
			print("NATIVE KEY logical=",event.keycode," physical=",event.physical_keycode," pressed=",event.pressed," jump=",event.is_action("jump")," F1=",event.is_action("developer_menu"))
func _initialize() -> void:
	root.title="MARICRAFT · Keyboard diagnostic"
	root.add_child.call_deferred(Probe.new())
