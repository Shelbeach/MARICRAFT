extends "res://tests/molten_routes.gd"

func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/molten/platforms-%d"%OS.get_process_id())
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	var count:=0
	for form in [0,2]:
		for phase in [0.0,0.25,0.5,0.75]:
			for entry in [["3-1","ChainLift",3068,480,3294,340],["3-2","LavaCarrier",677,480,1060,0],["3-2","Counterweight",2758,480,3150,0],["3-2","LastBridge",4418,480,4780,0],["3-2","VaultLift",7775,480,7970,328]]:
				state.store.first_level=entry[0]
				state.new_game("human")
				game.start_level()
				start_stage(entry[0])
				await ticks(6)
				var w=game.world
				for node in w.get_children():
					if node.has_method("defeat") or node.has_method("bounds"): node.set_physics_process(false)
				w.player.position=Vector2(entry[2],entry[3]-1)
				w.player.velocity=Vector2.ZERO
				w.player.apply_form(form)
				expected_form=form
				var deck=w.get_node(entry[1])
				deck.elapsed=phase*deck.period
				await ticks(5)
				if entry[5]>0: await lift_to(entry[1],entry[4],entry[5])
				else: await crossing(deck,entry[4])
				check(not pilot_failed,"platform phase %s %.2f form=%d"%[entry[1],phase,form])
				count+=1
				if failed: quit(1);return
	game.clear_world()
	await process_frame
	await process_frame
	root.get_node("SFX").new_world(false)
	OS.delay_msec(120)
	print("MOLTEN PLATFORMS PASS cases=",count)
	quit()
