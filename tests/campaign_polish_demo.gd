extends "res://tests/campaign_polish_mechanics.gd"
var take:=""
var frame:=0
var movie_tick:=0
const MOVIE_DIR:="res://reports/temp/campaign-polish/frames/"

func ticks(count:int) -> void:
	for i in count:
		await physics_frame
		movie_tick+=1
		if not take.is_empty() and movie_tick%3==0:
			await RenderingServer.frame_post_draw
			var img:=root.get_texture().get_image()
			img.resize(960,540,Image.INTERPOLATE_LANCZOS)
			img.save_png(MOVIE_DIR+take+"/%05d.png"%frame)
			frame+=1

func begin_clip(id:String) -> void:
	take=id;frame=0;movie_tick=0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOVIE_DIR+take))

func run() -> void:
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	await fresh("3-2")
	var w=game.world;var a=w.player
	a.position=Vector2(3750,480)
	await ticks(5)
	a.position=Vector2(4090,480)
	a.get_node("Camera").reset_smoothing()
	await ticks(150)
	begin_clip("pipe-patrol")
	await ticks(720)
	take=""
	await fresh("3-1")
	w=game.world;a=w.player
	var imp=w.get_node("ForgeCaster")
	a.position=imp.position-Vector2(220,0)
	a.protection=0
	a.get_node("Camera").reset_smoothing()
	await ticks(6)
	imp.attack_controller.cooldown=0.4
	begin_clip("imp-ranged")
	for i in 480:
		var jump:=false
		for p in get_nodes_in_group("enemy_projectiles"):
			if p.position.x-a.position.x>0 and p.position.x-a.position.x<100: jump=true
		press(KEY_SPACE,jump)
		await ticks(1)
	press(KEY_SPACE,false)
	check(state.p.hearts==3,"ordinary jump avoids recorded imp projectiles")
	take=""
	for id in ["1-3","2-3"]:
		await fresh(id)
		w=game.world;a=w.player
		a.position=w.boss.position-Vector2(130,0)
		a.protection=0
		a.get_node("Camera").reset_smoothing()
		w.boss.set_physics_process(false)
		await ticks(5)
		begin_clip("corpse-"+id)
		await ticks(60)
		w.boss.take_damage(w.boss.hp)
		await ticks(180)
		take=""
	game.clear_world()
	await process_frame
	await process_frame
	print("POLISH DEMO clips recorded at 20 FPS from real native frames")
	quit()
