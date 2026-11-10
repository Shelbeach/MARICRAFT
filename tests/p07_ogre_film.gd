extends "res://tests/p07_routes.gd"
var seen:={}
var page_frames:=0

func _initialize() -> void:
	root.unfocusable=true
	film_frames=180
	if "--640" in OS.get_cmdline_user_args(): root.size=Vector2i(640,360)
	RenderingServer.frame_post_draw.connect(capture)
	run.call_deferred()

func film_finish() -> void:
	for child in game.screen.find_children("*","Button",true,false):
		if child is Button and child.text=="На карту мира":
			var at:Vector2=child.get_global_rect().get_center()*Vector2(root.size)/Vector2(960,540)
			for on in [true,false]:
				var event:=InputEventMouseButton.new()
				event.position=at
				event.button_index=MOUSE_BUTTON_LEFT
				event.pressed=on
				Input.parse_input_event(event)
				await process_frame
			break
	await ticks(180)
	check(game.page=="map","filmed victory opens free map with an actual click")

func capture() -> void:
	if not is_instance_valid(game): return
	var label:=""
	if game.page in ["result","victory","map"]:
		page_frames+=1
		if page_frames<4: return
		label=game.page+"-"+state.p.get("level","")
	elif game.page=="play" and is_instance_valid(game.world):
		page_frames=0
		if game.world.boss:
			var b=game.world.boss
			if b.mode==b.Mode.WARN and b.clock>0.55: return
			if b.mode==b.Mode.STRIKE and b.clock>0.60: return
			if b.mode==b.Mode.DEAD: label="ragnaros-death-end" if b.death_age>1.9 else "ragnaros-death-start"
			elif b.mode in [b.Mode.WARN,b.Mode.STRIKE,b.Mode.OPEN]: label="ragnaros-%d-%d-%d"%[b.phase(),b.attack,b.mode]
		else:
			label="route-"+level_id+"-"+str(floori(game.world.player.position.x/500)*500)
	if label.is_empty() or seen.has(label): return
	seen[label]=true
	root.get_texture().get_image().save_png("res://reports/evidence/p07/film-ogre/"+label+".png")
