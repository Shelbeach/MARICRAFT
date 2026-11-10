extends "res://tests/s02_forest.gd"
var checked:=0
func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/durotar-revision/blocks-%d"%OS.get_process_id())
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for hero in ["human","ogre"]:
		for form in 3:
			for id in ["2-1","2-2","2-3"]:
				await test_level(id)
				state.p.hero=hero
				var w=game.world
				# Isolate head clearance/reward IDs. Enemy timing is covered by continuous
				# route and guarded-branch tests, not by these local placement fixtures.
				for n in w.get_children():
					if n.has_method("defeat") or n==w.boss: n.set_physics_process(false)
				for block in w.get_children():
					# A neighbouring fragile may break in the same physical head contact.
					# Godot returns a snapshot of children; do not dereference freed entries.
					if not is_instance_valid(block): continue
					if block.get("kind")!="fragile": continue
					var key:String=block.reward_id
					var ray:=PhysicsRayQueryParameters2D.create(block.position+Vector2(0,18),block.position+Vector2(0,350),1)
					var support:Dictionary=w.get_world_2d().direct_space_state.intersect_ray(ray)
					check(not support.is_empty(),"support below "+key)
					if support.is_empty(): continue
					var a=w.player
					a.apply_form(0)
					a.position=Vector2(block.position.x,support.position.y-1)
					a.velocity=Vector2.ZERO
					a.protection=100
					check(a.apply_form(form),"growth clearance below "+key)
					await ticks(4)
					press(KEY_SPACE,true)
					await ticks(42)
					press(KEY_SPACE,false)
					await ticks(36)
					check((is_instance_valid(block) and not state.claimed(key)) if form==0 else (not is_instance_valid(block) and state.claimed(key)),"physical underside "+key+" "+hero+" form="+str(form))
					checked+=1
					if failed: quit(1);return
	check(checked==468,"complete 78 blocks × two heroes × three forms")
	print("ALL FRAGILE ACCESS ","FAIL" if failed else "PASS"," cases=",checked)
	quit(1 if failed else 0)
