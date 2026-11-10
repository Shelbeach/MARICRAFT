extends "res://tests/camera_repair_web.gd"
## Isolated visual fixtures. No commands in the public build or user profile.

func arena_at(x:float) -> void:
	await fresh_level("3-3")
	state.p.tutorial={"move":true,"jump":true,"shoot":true}
	var w=game.world
	w.boss.set_physics_process(false)
	w.player.position=Vector2(x,480)
	w.player.velocity=Vector2.ZERO
	w.player.get_node("Camera").snap_to_player()
	await ticks(100)

func views() -> void:
	state.new_game("human")
	game.main_menu()
	await frame_ack("menu-locked")
	for id in state.ROUTE:
		state.finish(10)
		if id!="3-3": state.leave_result()
	game.main_menu()
	await frame_ack("menu-unlocked")
	game.pages.choose_levels()
	await frame_ack("level-select")
	await arena_at(1830)
	await frame_ack("arena-left")
	game.world.player.position=Vector2(2875,480)
	await ticks(100)
	await frame_ack("arena-right")

func rune() -> void:
	await arena_at(1810)
	await frame_ack("ready")
	await motion("rune-standing",45)
	await motion("rune-jump",12,0,true)
	await motion("rune-land",60)
	await frame_ack("rune-collected")
	outcome={"form":game.world.player.form,"claimed":state.claimed("3-3/LastRune"),"hearts":state.p.hearts,"arena_locked":game.world.arena.active}

func waves() -> void:
	await arena_at(2460)
	game.world.player.protection=999
	await frame_ack("ready")
	var boss=game.world.boss
	boss.attack=boss.Attack.HAMMER
	boss.execute()
	await motion("wave-flight",10)
	await frame_ack("waves")
	await motion("wave-travel",80,0,true)
	await motion("wave-end",60)
	outcome={"wave_scale":0.48,"hitbox":[12,12]}

func run() -> void:
	browser=JavaScriptBridge.get_interface("window")
	options=JSON.parse_string(str(browser.cameraOptions))
	state=root.get_node("Campaign")
	while not state.access_ready: await process_frame
	state.store.prefix="user://arena-polish-visual-tests"
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	game.get_node("Interface/Feedback").hide()
	match options.mode:
		"arena_view": await views()
		"arena_rune": await rune()
		"arena_waves": await waves()
	publish({"done":true,"telemetry":telemetry,"outcome":outcome})
	paused=true
