extends "res://tests/final_polish_capture.gd"
## Isolated visual-test entry, excluded from the public Web preset.
## Fixtures place a hero once; subsequent movement uses real input and physics.
var options:Dictionary={}
var telemetry:Array=[]
var phase:=""
var browser
var outcome:Dictionary={}

func publish(value:Dictionary) -> void:
	if browser: browser.cameraQa=JSON.stringify(value)

func fresh_level(id:String) -> void:
	state.new_game(str(options.get("hero","human")))
	state.p.level=id
	if options.get("mode","") in ["elevation","long","boss"]:
		# These fixtures start mid-level, after the approach taught these actions.
		state.p.tutorial={"move":true,"jump":true,"shoot":true}
	game.start_level()
	await ticks(6)
	game.world.player.apply_form(int(options.get("form",0)))
	if options.get("before",false):
		var c=game.world.player.get_node("Camera")
		c.set_script(load("res://tests/camera_repair_before.gd"))
		c.position_smoothing_enabled=true
		c.position_smoothing_speed=9.0
		c.limit_top=0
		c._ready()

func redraw_all(node:Node) -> void:
	if node is CanvasItem: node.queue_redraw()
	if node.has_method("_process"): node._process(0)
	for child in node.get_children(): redraw_all(child)

func frame_ack(name:String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	publish({"capture":name})
	while str(browser.cameraAck)!=name: await process_frame

func atlas() -> void:
	for id in level_ids:
		await fresh_level(id)
		game.world.player.get_node("Camera").enabled=false
		root.canvas_transform=Transform2D.IDENTITY
		game.get_node("Interface").hide()
		paused=true
		var segments:Array=[[id,0,int(game.world.finish_x+128)-960]]
		if game.world.cave_left>0: segments.append([id+"-mine",int(game.world.cave_left),int(game.world.cave_left+game.world.cave_width)-960])
		for segment in segments:
			var points:Array[int]=[]
			for x in range(segment[1],segment[2],450): points.append(x)
			if not points.has(segment[2]): points.append(segment[2])
			for x in points:
				root.canvas_transform=Transform2D(0,Vector2(-x,0))
				# Refresh only presentation. No gameplay _process callbacks.
				for n in game.world.get_children():
					if str(n.name) in ["ForestArt","LocationArt","FactionDecor"]: redraw_all(n)
				await frame_ack(segment[0]+"-"+str(x))
		paused=false
		game.get_node("Interface").show()

func sample_frame() -> void:
	var a=game.world.player
	var c:Camera2D=a.get_node("Camera")
	c.force_update_scroll()
	var centre:=c.get_screen_center_position()
	telemetry.append({"phase":phase,"frame":Engine.get_physics_frames(),"x":a.position.x,"y":a.position.y,"vx":a.velocity.x,"vy":a.velocity.y,"floor":a.is_on_floor(),"cx":centre.x,"cy":centre.y,"zoom":c.zoom.x,"form":a.form})

func motion(label:String,frames:int,axis:=0,jump:=false) -> void:
	phase=label
	publish({"running":label})
	press(KEY_D,axis>0);press(KEY_A,axis<0);press(KEY_SPACE,jump)
	for i in frames:
		await physics_frame
		if game.page=="pause":game.show_page("play")
		sample_frame()
	press(KEY_D,false);press(KEY_A,false);press(KEY_SPACE,false)

func camera_demo() -> void:
	await fresh_level("1-1")
	var a=game.world.player
	# Long accepted ground bank; posts/trees remain present in this test.
	a.position=Vector2(3340,480);a.velocity=Vector2.ZERO
	a.get_node("Camera").snap_to_player()
	await ticks(90)
	await frame_ack("ready")
	await motion("still",60)
	await motion("one_step",5,1)
	await motion("after_step",40)
	for i in 3:
		await motion("tap",4,1);await motion("after_tap",20)
	await motion("run",160,1)
	await motion("stop",100)
	await motion("reverse",65,-1)
	await motion("stop_reverse",90)
	# A fixture move starts a separate jump shot on an unobstructed landing.
	a.position=Vector2(3950,480);a.velocity=Vector2.ZERO
	a.get_node("Camera").snap_to_player()
	await ticks(90)
	for i in 3:
		await motion("jump",42,0,true);await motion("land",48)

func elevation_demo() -> void:
	await fresh_level("1-1")
	var a=game.world.player
	a.position=Vector2(3090,207);a.velocity=Vector2.ZERO
	a.get_node("Camera").snap_to_player()
	await ticks(90)
	await frame_ack("ready")
	for i in 2:
		await motion("high_jump",42,0,true);await motion("high_land",48)
	await motion("high_fall",180,1)
	await motion("low_land",120)

func long_run_demo() -> void:
	await fresh_level("1-1")
	var a=game.world.player
	a.position=Vector2(1900,480);a.velocity=Vector2.ZERO
	a.get_node("Camera").snap_to_player()
	await ticks(90)
	await frame_ack("ready")
	phase="run_13_seconds"
	press(KEY_D,true)
	var held:=0
	for i in 780:
		if a.is_on_floor() and a.position.x>=3140 and a.position.x<=3170: held=40
		press(KEY_SPACE,held>0);held-=1
		await physics_frame
		sample_frame()
	press(KEY_D,false);press(KEY_SPACE,false)
	await motion("stop_long_run",120)
	await motion("reverse_long_run",120,-1)
	await motion("stop_reverse",90)

func boss_demo() -> void:
	await fresh_level("1-3")
	var a=game.world.player
	a.position=Vector2(1810,480);a.velocity=Vector2.ZERO
	a.get_node("Camera").snap_to_player()
	await ticks(5)
	await frame_ack("ready")
	var pilot=load("res://tests/boss_pilot.gd").new()
	phase="boss_fight"
	for i in 2600:
		pilot.tick(self,a,game.world.boss,a.form==2)
		await physics_frame
		sample_frame()
		if game.world.boss.hp<=0 or state.p.hearts<3: break
	pilot.release(self)
	await motion("boss_end",120)
	outcome={"boss_hp":game.world.boss.hp,"hearts":state.p.hearts,"form":a.form}

func run() -> void:
	if not OS.has_feature("web"): quit(1);return
	browser=JavaScriptBridge.get_interface("window")
	options=JSON.parse_string(str(browser.cameraOptions))
	state=root.get_node("Campaign")
	while not state.access_ready: await process_frame
	state.store.prefix="user://camera-visual-tests"
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	game.get_node("Interface/Feedback").hide()
	match options.get("mode",""):
		"atlas": await atlas()
		"elevation": await elevation_demo()
		"long": await long_run_demo()
		"boss": await boss_demo()
		_: await camera_demo()
	publish({"done":true,"telemetry":telemetry,"outcome":outcome})
	# Browser saves the recording before closing its own isolated process.
	paused=true
