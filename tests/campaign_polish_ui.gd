extends "res://tests/p06_ui.gd"
const DEST:="res://reports/evidence/campaign-polish/ui/"

func click(caption:String) -> void:
	var target:Button
	for child in game.screen.find_children("*","Control",true,false):
		if child is Button and (child.text==caption or child.name==caption): target=child
	check(target!=null,"visible button "+caption)
	if target==null: return
	var at:Vector2=target.get_global_rect().get_center()*Vector2(root.size)/Vector2(960,540)
	for on in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=at
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=on
		Input.parse_input_event(event)
		await process_frame

func snap(id:String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DEST+id+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	state=root.get_node("Campaign")
	state.start_sandbox()
	state.store.first_level="1-1"
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	game.get_node("Interface/Feedback").hide()
	for size in [Vector2i(960,540),Vector2i(640,360)]:
		root.size=size
		state.new_game("human")
		game.show_page("map")
		await process_frame
		check(game.screen.find_children("Level_*","Button",true,false).filter(func(b):return not b.disabled).size()==1,"first campaign has no active level selection")
		await snap("locked-map-"+str(size.x))
		for id in state.ROUTE:
			state.reward(id+"/fixture",8,80)
			state.finish(10)
			if id!="3-3": state.leave_result()
		game.show_page("victory")
		await process_frame
		for child in game.screen.find_children("*","Control",true,false):
			if child is Label and child.autowrap_mode!=TextServer.AUTOWRAP_OFF: check(child.position.y+child.size.y<=496,"wrapped victory text fits visible panel")
		controls(game.screen)
		await snap("victory-"+str(size.x))
		await click("На карту мира")
		var choices=game.screen.find_children("Level_*","Button",true,false)
		check(choices.size()==9,"nine free-map controls "+str(size.x))
		await snap("free-map-"+str(size.x))
		for id in state.ROUTE:
			await click("Level_"+id)
			await click("Играть")
			await ticks(8)
			check(game.page=="play" and state.p.level==id and state.p.hearts==3,"UI opens actual scene "+id+" at "+str(size.x))
			if id.begins_with("3-"): await snap("level-"+id+"-"+str(size.x))
			game.clear_world()
			game.show_page("map")
			await process_frame
		state.start_replay("3-2")
		for i in 3: state.lose_heart()
		game.show_page("offer")
		await process_frame
		await click("Завершить попытку")
		check(game.page=="confirm","replay defeat asks about this attempt")
		await snap("replay-abandon-"+str(size.x))
		await click("Да, продолжить")
		check(game.page=="defeat" and state.p.completed,"replay defeat retains campaign unlock")
		await snap("replay-defeat-"+str(size.x))
		await click("Карта уровней")
		check(game.screen.find_children("Level_*","Button",true,false).size()==9,"replay defeat returns to nine-level map")
		game.main_menu()
		await process_frame
	# F1 scroll covers nine levels and all boss commands at the smaller window.
	state.debug_level("3-3")
	game.start_level()
	await ticks(8)
	press(KEY_F1,true)
	await process_frame
	press(KEY_F1,false)
	var menu=root.get_node("DebugTools/DeveloperMenu")
	check(menu.modal.visible,"F1 opens using real mapped key event")
	await snap("f1-640")
	menu.toggle()
	game.clear_world()
	await process_frame
	await process_frame
	print("CAMPAIGN POLISH UI ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
