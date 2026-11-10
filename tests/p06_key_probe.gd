extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.get_node("Campaign").start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	var game=current_scene
	for mode in ["Input","Viewport"]:
		game.show_page("heroes")
		await process_frame
		await process_frame
		game.screen.get_node("HeroHit_human").grab_focus()
		print("KEY MAP ",InputMap.action_get_events("ui_focus_next")," ACCEPT ",InputMap.action_get_events("ui_accept")," WINDOW ",root.get_window_id())
		for key in [KEY_TAB,KEY_SPACE,KEY_TAB,KEY_SPACE]:
			for on in [true,false]:
				var event:=InputEventKey.new()
				event.keycode=key
				event.physical_keycode=key
				event.pressed=on
				event.window_id=root.get_window_id()
				if on: print("MATCH ",event.is_action_pressed("ui_focus_next")," ",event.is_action_pressed("ui_accept")," FOCUS_MODE ",game.screen.get_node("HeroHit_human").focus_mode)
				if mode=="Input":
					Input.parse_input_event(event)
					Input.flush_buffered_events()
				else: root.push_input(event)
				await process_frame
			print("KEY ",mode," ",key," focus=",root.gui_get_focus_owner()," selected=",game.selected)
	quit()
