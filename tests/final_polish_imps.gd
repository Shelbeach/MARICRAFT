extends "res://tests/s02_forest.gd"
var rows:Array=[]
func _initialize() -> void:
	root.unfocusable=true
	physics_frame.connect(func():
		if is_instance_valid(game) and game.page=="pause": game.show_page("play"))
	run.call_deferred()
func run() -> void:
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for id in ["3-1","3-2","3-3"]:
		await test_level(id)
		var w=game.world
		var a=w.player
		for imp in w.get_children():
			if imp.get("ranged")!=true: continue
			var attack=imp.attack_controller
			var started:=0
			var aborted:=0
			var old:=0
			a.set_physics_process(false)
			a.protection=999
			for trial in 20:
				attack.cooldown=0
				# Start with a visible target, then perform the high part of a normal jump.
				for frame in 70:
					a.position=imp.position+Vector2(-150,-145 if frame>18 and frame<50 else 0)
					a.velocity=Vector2.ZERO
					await ticks(1)
					if attack.mode==1 and old!=1: started+=1
					if old==1 and attack.mode==0: aborted+=1
					old=attack.mode
			rows.append({"level":id,"imp":str(imp.name),"started":started,"cancelled":aborted,"fired":attack.shots_fired})
			a.set_physics_process(true)
	var suffix:="before" if "--before" in OS.get_cmdline_user_args() else str(Engine.max_fps)
	var file:=FileAccess.open("res://reports/evidence/final-polish/imps-"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "))
	print("IMP REPRO ",JSON.stringify(rows))
	root.get_node("MusicManager").stop_all()
	quit()
