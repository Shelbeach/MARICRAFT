extends "res://tests/campaign_polish_mechanics.gd"
func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/campaign-polish/arena-save-%d"%OS.get_process_id())
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for id in ["1-3","2-3","3-3"]:
		state.store.first_level=id
		state.new_game("human")
		game.start_level()
		await ticks(5)
		var b=game.world.boss
		b.take_damage(b.hp)
		await ticks(3)
		state.save()
		var score:int=state.p.score
		var bank:int=state.p.wallet
		state.p=state.store.read_profile()
		check(state.store.valid(state.p),"real saved post-boss profile valid "+id)
		game.start_level()
		await ticks(6)
		var w=game.world
		check(w.boss.hp==0 and w.arena.released and w.get_node("Gate/Hitbox").disabled,"reloading defeated boss leaves gates open "+id)
		check(state.p.score==score and state.p.wallet==bank,"reload does not grant another reward "+id)
		w.player.position=Vector2(w.arena.left+65,480)
		await ticks(90)
		check(not w.arena.active and w.boss.hp==0,"dead arena never reactivates "+id)
		state.new_game("human")
		game.start_level()
		await ticks(6)
		check(game.world.boss.hp==game.world.boss.MAX_HP and not game.world.arena.released,"new attempt has a live boss "+id)
	# A small player reaches the moved rune with a deliberate jump from the
	# inside edge of the entrance pedestal. Ordinary floor jumps miss it.
	state.store.first_level="3-3"
	state.new_game("human")
	game.start_level()
	await ticks(5)
	var a=game.world.player
	a.position=Vector2(1720,424)
	a.velocity=Vector2.ZERO
	await ticks(4)
	press(KEY_SPACE,true);press(KEY_D,true)
	for i in 48:
		await ticks(1)
		if a.position.x>=1810: press(KEY_D,false)
	press(KEY_SPACE,false);press(KEY_D,false)
	print("RUNE LANDING ",a.position," form=",a.form," active=",game.world.arena.active)
	check(a.form==2 and state.claimed("3-3/LastRune") and game.world.arena.active,"small hero deliberately collects rune inside locked arena")
	game.clear_world()
	await process_frame
	await process_frame
	print("POLISH PERSISTENCE ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
