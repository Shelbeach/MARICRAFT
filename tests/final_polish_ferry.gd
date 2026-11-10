extends SceneTree
## Controlled edge placement; normal character and ferry physics after placement.
var game
var failures:Array=[]
var records:Array=[]
const OUT:="res://reports/evidence/final-polish/"
func _initialize() -> void:
	root.unfocusable=true
	run.call_deferred()
func frames(n:int) -> void:
	for i in n:
		await physics_frame
		await process_frame
		if game and game.page=="pause":game.show_page("play")
func run() -> void:
	var c=root.get_node("Campaign")
	c.start_sandbox();c.cheats.shield=true
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for hero in ["human","ogre"]:
		for form in 3:
			for side in [-1,1]:
				c.new_game(hero);c.debug_level("3-2");c.cheats.shield=true
				game.start_level()
				var a=game.world.player
				var deck=game.world.get_node("LavaCarrier")
				a.apply_form(form)
				a.position=deck.position+Vector2(side*50,-2);a.velocity=Vector2.ZERO
				var start:Vector2=deck.position
				await frames(15)
				var offset:float=a.position.x-deck.position.x
				var max_slip:=0.0
				var max_floor_gap:=0.0
				var bank_contacts:Array=[]
				for i in 70:
					await frames(1)
					if a.is_on_wall():
						for j in a.get_slide_collision_count():
							var hit=a.get_slide_collision(j)
							if absf(hit.get_normal().x)>0.8:
								bank_contacts.append({"surface":str(hit.get_collider().name),"shift":a.position.x-deck.position.x-offset})
						# A passive rider at the extreme end touches the receiving
						# bank. That wall correction is not slipping off the ferry.
						offset=a.position.x-deck.position.x
					else: max_slip=maxf(max_slip,absf(a.position.x-deck.position.x-offset))
					max_floor_gap=maxf(max_floor_gap,absf(a.position.y-deck.position.y))
				var art=deck.find_child("FerryArt",true,false)
				var art_rect:Rect2=Rect2(art.offset*art.scale,art.texture.get_size()*art.scale)
				var shape=deck.get_node("Hitbox").shape
				var ok:bool=a.is_on_floor() and max_slip<1.0 and max_floor_gap<1.0 and art_rect==Rect2(-64,0,128,22) and shape.size==Vector2(128,16)
				var row:={"hero":hero,"form":form,"side":side,"slip":max_slip,"bank_contacts":bank_contacts,"floor_gap":max_floor_gap,"deck_distance":deck.position.distance_to(start),"art_rect":str(art_rect),"collision_size":str(shape.size),"passed":ok}
				records.append(row)
				if not ok:failures.append(row)
				if DisplayServer.get_name()!="headless" and hero=="human" and form in [0,1]:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OUT+"screens/ferry-%d-%d.png"%[form,side])
	var report:={"cases":records,"failures":failures,"passed":failures.is_empty(),"controlled_placement":true}
	FileAccess.open("res://reports/evidence/camera-repair/ferry-edges-"+("30" if "--30" in OS.get_cmdline_user_args() else "60")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FERRY EDGES ",records.size()," cases; failures=",failures)
	root.get_node("MusicManager").stop_all();root.get_node("SFX").new_world(false)
	OS.delay_msec(150)
	quit(0 if failures.is_empty() else 1)
