extends "res://tests/s02_forest.gd"

func run() -> void:
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for id in ["1-1","1-2","1-3"]:
		await test_level(id)
		var back=game.world.get_node("ForestArt").get_child(1)
		var count:=0
		for prop in back.props:
			if prop[0] not in ["post","stone_post"]: continue
			count+=1
			var surfaces:Array=[]
			for node in game.world.get_children():
				if node.get("construction")!=null: surfaces.append(Rect2(node.position,node.size))
			var foot:Vector2=Vector2(prop[1].x,prop[2]-4)
			var buried:=foot.y>=540
			for surface in surfaces: buried=buried or surface.has_point(foot)
			check(buried and prop[2]>prop[1].y,"support ends inside a real foundation "+id+" "+str(foot))
		check(count>0,"level has grounded supports "+id)
	# Real boss controller in both directions, through WARN -> ACT -> OPEN.
	var boss=game.world.boss
	var actor=game.world.player
	actor.get_node("Camera").enabled=false
	root.canvas_transform=Transform2D(0,Vector2(-1838,0))
	actor.set_physics_process(false)
	actor.protection=999
	for side in [-1,1]:
		for phase in 3:
			boss.position=boss.home
			boss.hp=9-phase*3
			boss.next_water=false
			actor.position=boss.position+Vector2(side*130,0)
			boss.prepare(actor)
			var cue=boss.get_node("Skin/Telegraph")
			await ticks(4)
			check(cue.visible and cue.charge.visible==(phase==0),"correct visible warning "+str([side,phase]))
			var warnings:=0
			while boss.mode==boss.Mode.WARN and warnings<90:
				warnings+=1
				await ticks(1)
			check(boss.mode==boss.Mode.ACT,"warning reaches real attack "+str([side,phase]))
			await ticks(2)
			check(not cue.visible,"warning disappears during attack "+str([side,phase]))
			await ticks(ceili(boss.move.execution*60)+4)
			check(boss.mode==boss.Mode.OPEN and not cue.visible,"recovery keeps warning off "+str([side,phase]))
			boss.clear_shots()
	quit(1 if failed else 0)
