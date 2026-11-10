extends "res://tests/s02_forest.gd"

# Each local run starts on the ground before a branch. All subsequent movement
# across that branch is produced by A/D and Space on the actual collision bodies.
func walk_to(x: float) -> void:
	press(KEY_D,true)
	for i in 180:
		await ticks(1)
		if game.world.player.position.x>=x-4: break
	press(KEY_D,false)
	await ticks(8)

func landing(x: float,y: float,label: String) -> void:
	await jump_right_to(x)
	var actor=game.world.player
	check(actor.is_on_floor() and absf(actor.position.x-x)<15 and absf(actor.position.y-y)<1,
		label+" form="+str(actor.form)+" feet="+str(actor.position))

func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/branches-%d"%OS.get_process_id())
	state.p={}
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for form in 3:
		await test_level("1-1")
		await place_player(678)
		game.world.player.apply_form(form)
		await landing(776,448,"opener step")
		await landing(907,380,"mill first deck")
		await walk_to(1005)
		await landing(1132,352,"mill upper dock")
		await walk_to(1293)
		check(absf(game.world.player.position.y-352)<1,"chest forms end of loading deck")
		await test_level("1-2")
		await place_player(3494)
		game.world.player.apply_form(form)
		await landing(3565,376,"lookout approach")
		await landing(3684,340,"empty stair")
		await landing(3764,292,"breakable stair")
		await landing(3854,260,"lookout floor")
		await walk_to(3890)
		press(KEY_SPACE,true)
		await ticks(30)
		press(KEY_SPACE,false)
		check(state.claimed("1-2/lookout"),"lookout chest reached from ground")
		await test_level("1-3")
		await place_player(782)
		game.world.player.apply_form(form)
		await landing(832,448,"gatehouse footing")
		await landing(929,344,"gatehouse gallery")
		await walk_to(1170)
		check(absf(game.world.player.position.y-344)<1 and game.world.player.position.x>1150,
			"crossed entire gallery and central chest")
	quit(1 if failed else 0)
