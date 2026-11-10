extends "res://tests/s02_forest.gd"
var tested:=0
var chest_count:=0

func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/molten/blocks-%d"%OS.get_process_id())
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for hero in ["human","ogre"]:
		for form in 3:
			for id in ["3-1","3-2","3-3"]:
				await test_level(id)
				state.p.hero=hero
				var w=game.world
				# Local head-contact fixtures; continuous routes test enemy/vent timing.
				for n in w.get_children():
					if n.has_method("defeat") or n==w.boss or n.has_method("bounds"): n.set_physics_process(false)
				for block in w.get_children():
					if not is_instance_valid(block) or not block.has_method("hit_below"): continue
					var id_key:String=block.reward_id
					var kind:String=block.kind
					var support:Dictionary=w.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(block.position+Vector2(0,18),block.position+Vector2(0,350),1))
					check(not support.is_empty(),"ground beneath "+id_key)
					if support.is_empty(): continue
					var a=w.player
					a.apply_form(0)
					a.position=Vector2(block.position.x,support.position.y-1)
					a.velocity=Vector2.ZERO
					a.protection=100
					check(a.apply_form(form),"grown capsule fits "+id_key)
					await ticks(5)
					press(KEY_SPACE,true)
					await ticks(42)
					press(KEY_SPACE,false)
					await ticks(38)
					if kind=="fragile": check((is_instance_valid(block) and not state.claimed(id_key)) if form==0 else (not is_instance_valid(block) and state.claimed(id_key)),"physical fragile "+id_key+" "+hero+str(form))
					else:
						check(block.spent and state.claimed(id_key),"physical chest "+id_key+" "+hero+str(form))
						chest_count+=1
					tested+=1
					if failed: print("BLOCK STOP ",id_key," support=",support.position," actor=",a.position);quit(1);return
	game.clear_world()
	await process_frame
	await process_frame
	print("MOLTEN BLOCKS ","FAIL" if failed else "PASS"," cases=",tested," chests=",chest_count)
	quit(1 if failed else 0)
