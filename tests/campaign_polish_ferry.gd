extends "res://tests/campaign_polish_forest_stars.gd"
## Local boarding fixture, kept distinct from continuous star runs.
func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/campaign-polish/ferry-%d"%OS.get_process_id())
	state.store.first_level="1-2"
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for hero in ["human","ogre"]:
		for form in 3:
			state.new_game(hero)
			game.start_level()
			await ticks(8)
			await place_player(790,479)
			game.world.player.apply_form(form)
			await star_practice_ferry()
			check(state.p.hearts==3 and game.world.player.form==form,"ferry and chest preserve "+hero+" form="+str(form))
			game.world.player.set_physics_process(false)
			var deck=game.world.get_node("PracticeFerry")
			var quay=game.world.get_node("Shelf1112Y388")
			var gap:=INF
			for i in 255:
				await ticks(1)
				gap=minf(gap,quay.position.x-(deck.position.x+64))
			check(gap>=23.9,"diagonal deck never overlaps static quay; min gap="+str(gap))
	game.clear_world()
	await process_frame
	await process_frame
	root.get_node("SFX").new_world(false)
	OS.delay_msec(120)
	print("POLISH FERRY ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
