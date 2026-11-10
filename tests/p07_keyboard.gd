extends "res://tests/s02_forest.gd"
func _initialize() -> void:
	root.unfocusable=true
	run.call_deferred()
func key(code:Key,shift:=false) -> void:
	for on in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=code
		event.physical_keycode=code
		event.shift_pressed=shift
		event.pressed=on
		Input.parse_input_event(event)
		await process_frame
func run() -> void:
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	state.new_game("human")
	for i in 4: state.finish(10); state.leave_result()
	game.show_page("map")
	await ticks(3)
	var map=game.screen.get_node("WorldMap")
	check(map.buttons.filter(func(b):return not b.disabled).size()==1,"only current level enabled before campaign completion")
	check(root.gui_get_focus_owner()==map.start_button,"keyboard starts on map launch button")
	await key(KEY_ENTER)
	await ticks(6)
	check(game.page=="play" and state.p.level=="2-2","Enter launches current level")
	await key(KEY_ESCAPE)
	await ticks(3)
	check(game.page=="pause","Escape opens pause")
	await key(KEY_ENTER)
	await ticks(3)
	check(game.page=="play","Enter resumes focused pause button")
	game.clear_world()
	state.new_game("ogre")
	for id in state.ROUTE:
		state.finish(10)
		if id!="3-3": state.leave_result()
	game.show_page("map")
	await ticks(3)
	await key(KEY_TAB,true)
	check(str(root.gui_get_focus_owner().name)=="Level_3-3","Shift Tab navigates to ninth point")
	await key(KEY_TAB,true)
	check(str(root.gui_get_focus_owner().name)=="Level_3-2","Shift Tab navigates along available points")
	await key(KEY_SPACE)
	check(game.map_selected=="3-2","Space selects focused map point")
	await key(KEY_TAB)
	await key(KEY_TAB)
	await key(KEY_ENTER)
	await ticks(6)
	check(game.page=="play" and state.p.level=="3-2" and state.p.hero=="ogre","keyboard launches real selected replay")
	game.clear_world()
	await process_frame
	root.get_node("SFX").new_world(false)
	OS.delay_msec(120)
	print("P07 KEYBOARD ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
