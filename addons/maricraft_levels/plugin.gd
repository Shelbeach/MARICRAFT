@tool
extends EditorPlugin
var preview:Node2D
var active_level:Node2D
var dragged:Node2D
var start_mouse:=Vector2.ZERO
var start_position:=Vector2.ZERO
func _enter_tree() -> void:
	set_process(true)
	set_input_event_forwarding_always_enabled()
func _handles(object:Object) -> bool: return object is Node2D
func _process(_delta:float) -> void:
	var edited=EditorInterface.get_edited_scene_root()
	if edited==active_level and is_instance_valid(preview): return
	if is_instance_valid(preview): preview.queue_free()
	active_level=null
	if not edited or edited.get("finish_x")==null: return
	active_level=edited
	preview=preload("preview.gd").new()
	preview.name="__LevelPreview"
	active_level.add_child(preview)
	preview.build()
func _exit_tree() -> void:
	if is_instance_valid(preview): preview.queue_free()
func _forward_canvas_gui_input(event:InputEvent) -> bool:
	if not is_instance_valid(preview) or not is_instance_valid(active_level): return false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.alt_pressed or event.ctrl_pressed or event.shift_pressed: return false
			var at:Vector2=active_level.get_global_transform_with_canvas().affine_inverse()*event.position
			var picked=preview.pick(at)
			if not picked: return false
			dragged=picked
			start_mouse=at
			start_position=dragged.position
			EditorInterface.get_selection().clear()
			EditorInterface.get_selection().add_node(dragged)
			EditorInterface.edit_node(dragged)
			return true
		elif is_instance_valid(dragged):
			if dragged.position!=start_position:
				var undo:=get_undo_redo()
				undo.create_action("Переместить "+str(dragged.name))
				undo.add_do_property(dragged,"position",dragged.position)
				undo.add_undo_property(dragged,"position",start_position)
				undo.commit_action(false)
			dragged=null
			return true
	if event is InputEventMouseMotion and is_instance_valid(dragged):
		var at:Vector2=active_level.get_global_transform_with_canvas().affine_inverse()*event.position
		dragged.position=(start_position+at-start_mouse).round()
		return true
	return false
