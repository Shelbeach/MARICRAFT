extends SceneTree
## Controlled player positions exercise real controller timings on both sides.
## Separate from the input-only full-fight recording.
var game
var boss
var view
var max_motion:=0.0
var max_open_error:=0.0
var previous:=Vector2.ZERO
var clips:Dictionary={}
var steps:=0
var old_mode:=-1
var dead_ticks:=0
var failed:=false
func _initialize() -> void:
	root.unfocusable=true
	run.call_deferred()
func run() -> void:
	var c=root.get_node("Campaign")
	c.start_sandbox();c.debug_level("3-3");c.cheats.shield=true
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene;game.start_level()
	boss=game.world.boss;view=game.world.get_node("RagnarosPresentation")
	var a=game.world.player
	a.position=Vector2(boss.home.x-245,480);a.set_physics_process(false)
	a.get_node("Camera").enabled=false
	root.canvas_transform=Transform2D(0,Vector2(-1660,0))
	await process_frame;await process_frame
	previous=view.rig.head_bottom
	for i in 2400:
		await process_frame
		if game.page=="pause":game.show_page("play")
		clips[view.rig.clip]=true
		max_motion=maxf(max_motion,previous.distance_to(view.rig.head_bottom))
		previous=view.rig.head_bottom
		if boss.mode==boss.Mode.OPEN:
			max_open_error=maxf(max_open_error,(view.global_position+view.rig.head_bottom).distance_to(boss.global_position))
		if boss.mode!=old_mode:
			old_mode=boss.mode
			if boss.mode==boss.Mode.WARN:
				steps+=1
				boss.magic_hit() # Guarded rejection, not HP damage.
			if boss.mode==boss.Mode.OPEN:
				boss.magic_hit()
				a.position.x=boss.home.x+245*(1 if steps%2 else -1)
				if steps>=4:boss.take_damage(boss.hp)
		if boss.hp<=0:
			dead_ticks+=1
			if dead_ticks>=120:break
	var ok:bool=steps==4 and max_open_error<.05 and max_motion<50 and boss.death_age==2.0
	var report:={"steps":steps,"max_head_step":max_motion,"max_open_error":max_open_error,"clips":clips.keys(),"death_age":boss.death_age,"passed":ok,"controlled_fixture":true}
	FileAccess.open("res://reports/evidence/p07v03-music/rig-motion.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RIG MOTION ",report)
	root.get_node("MusicManager").stop_all();root.get_node("SFX").new_world(false)
	OS.delay_msec(150)
	quit(0 if ok else 1)
