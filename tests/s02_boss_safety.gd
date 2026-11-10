extends "res://tests/s02_forest.gd"

func run() -> void:
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	# Test both sides of cover, both shooting steps, floor and beyond aggro range.
	for spot in [Vector2(1710,479),Vector2(1790,442),Vector2(1835,442),
			Vector2(1918,385),Vector2(2003,385),Vector2(1960,479),
			Vector2(2050,479),Vector2(2090,479),Vector2(2270,479),
			Vector2(2320,479),Vector2(2370,479),Vector2(2360,385),
			Vector2(2440,385),Vector2(2500,368),Vector2(2580,479),Vector2(2600,479)]:
		await test_level("1-3")
		var a=game.world.player
		var b=game.world.boss
		await place_player(spot.x,spot.y)
		check(a.apply_form(2),"room for caster "+str(spot))
		a.facing=1 if spot.x<b.position.x else -1
		for frame in 3600:
			await physics_frame
			if frame%5==0: press(KEY_E,true)
			if frame%5==2: press(KEY_E,false)
			if a.form!=2 or b.hp==0: break
		press(KEY_E,false)
		check(b.hp>0,"stationary position "+str(spot)+" remaining HP="+str(b.hp))
	await test_level("1-3")
	var boss=game.world.boss
	await place_player(1920)
	# A low wave going left meets the right side of the grounded step at X=1850.
	boss.fire(Vector2(1900,470),Vector2.LEFT,true)
	await ticks(20)
	check(get_nodes_in_group("boss_shots").is_empty(),"wave stopped at solid step")
	boss.fire(Vector2(1900,465),Vector2.LEFT)
	await ticks(23)
	check(get_nodes_in_group("boss_shots").is_empty(),"aimed projectile stopped at solid step")
	quit(1 if failed else 0)
