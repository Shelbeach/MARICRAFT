extends "res://tests/forest_art_routes.gd"
var capture_index:=0
var capture_due:=false
var label:=""
var destination:=""
var observed:Array=[]
var moving_land:=0
var grounded_steps:=0
var chapters:Array=[]
var capture_interval:=4
func save_recorded_frame() -> void:
	if not capture_due: return
	capture_due=false
	var im:=root.get_texture().get_image()
	im.save_jpg(destination+"/%05d.jpg"%capture_index,0.96)
	capture_index+=1
func frame_capture() -> void:
	if Engine.get_physics_frames()%capture_interval==0: capture_due=true
	if is_instance_valid(game.world):
		var a=game.world.player
		var skin=a.get_node("Skin")
		if absf(a.velocity.x)>50 and a.is_on_floor():
			grounded_steps+=1
			if skin.art.sprite.animation=="land": moving_land+=1
		var key=label+"/"+str(skin.art.sprite.animation)
		if key not in observed: observed.append(key)
func chapter(name:String) -> void:
	label=name
	chapters.append({"name":name,"seconds":capture_index/(60.0/capture_interval)})
func run() -> void:
	var before:bool="--before" in OS.get_cmdline_user_args()
	var tag:="before" if before else "after"
	if "--smooth" in OS.get_cmdline_user_args():
		capture_interval=1
		tag="after-60"
	destination="res://reports/temp/animation-fix/"+tag
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/animation-fix/profile-%s-%d"%[tag,OS.get_process_id()])
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for hero in ["human","ogre"]:
		for form in 3:
			state.new_game(hero)
			game.start_level()
			await ticks(5)
			game.world.player.apply_form(form)
			trace_level="fixture"
			chapter(hero+"_"+["small","large","magic"][form])
			await ticks(18)
			press(KEY_D,true)
			await ticks(48)
			press(KEY_SPACE,true)
			await ticks(30)
			press(KEY_SPACE,false)
			await ticks(45)
			press(KEY_D,false)
			await ticks(30)
			press(KEY_A,true)
			await ticks(40)
			press(KEY_SPACE,true)
			await ticks(12)
			press(KEY_A,false)
			press(KEY_SPACE,false)
			await ticks(48)
			if form==2:
				press(KEY_E,true)
				await ticks(4)
				press(KEY_E,false)
				await ticks(20)
				press(KEY_D,true)
				press(KEY_E,true)
				await ticks(4)
				press(KEY_E,false)
				await ticks(28)
				press(KEY_D,false)
			await ticks(15)
			check(game.world.player.form==form and state.p.hearts==3,"motion fixture unchanged form "+label)
			capture_due=false
			trace_level=""
	state.new_game("human")
	game.start_level()
	await ticks(5)
	chapter("murloc")
	var enemy=load("res://scenes/enemies/murloc.tscn").instantiate()
	enemy.position=Vector2(380,480)
	enemy.patrol_width=64
	game.world.add_child(enemy)
	await ticks(30)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/evidence/animation-fix/enemy-"+tag+".png")
	await ticks(120)
	capture_due=false
	var file:=FileAccess.open("res://reports/evidence/animation-fix/motion-"+tag+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames":capture_index,"fps":60/capture_interval,"chapters":chapters,"clips":observed,"moving_land_ticks":moving_land,"grounded_move_ticks":grounded_steps},"  "))
	if not before: check(moving_land==0,"no planted landing pose while running")
	print("MOTION ",tag," frames=",capture_index," moving_land_ticks=",moving_land)
	quit(1 if failed else 0)
