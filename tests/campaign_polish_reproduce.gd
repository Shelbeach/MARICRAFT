extends "res://tests/s02_forest.gd"
var casts:=0
var shot_sounds:=0
func run() -> void:
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	root.get_node("SFX").played.connect(func(id, _details):
		if id=="magic_cast": shot_sounds+=1)
	var results:={}
	for id in ["1-3","2-3","3-3"]:
		await test_level(id)
		var a=game.world.player
		var b=game.world.boss
		b.set_physics_process(false)
		a.apply_form(2)
		a.position=b.position-Vector2(40,0)
		a.facing=1
		a.protection=20
		a.visual_event.connect(func(event):
			if event=="shoot": casts+=1)
		casts=0; shot_sounds=0
		for i in 60:
			a.shoot()
			await ticks(1)
		results[id]={"casts_in_1_second":casts,"sounds":shot_sounds,"hp":b.hp}
	await test_level("3-2")
	game.world.player.position=Vector2(3730,479)
	game.world.player.protection=30
	await ticks(30)
	var guard
	for n in game.world.get_children():
		if n.get("reward_id")=="3-2/DangerGuard": guard=n
	var low:=INF; var high:=-INF; var turns:=0; var last:=0
	for i in 600:
		await ticks(1)
		if not is_instance_valid(guard): break
		if i>120:
			low=minf(low,guard.position.x); high=maxf(high,guard.position.x)
			if last!=0 and guard.direction!=last: turns+=1
			last=guard.direction
	results["pipe_patrol"]={"min_x":low,"max_x":high,"turns_in_8_seconds":turns,"emerging":guard.emerging_from_pipe if is_instance_valid(guard) else false}
	var file:=FileAccess.open("res://reports/evidence/campaign-polish/reproduced-before.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	print(JSON.stringify(results))
	quit()
