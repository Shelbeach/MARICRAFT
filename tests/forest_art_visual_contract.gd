extends "res://tests/s02_forest.gd"
const Art:=preload("res://scripts/visual/art_library.gd")
func run() -> void:
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	Art.initialize()
	for hero in ["human","ogre"]:
		await test_level("1-1")
		state.p.hero=hero
		var a=game.world.player
		await place_player(1500)
		for form in 3:
			a.apply_form(form)
			await ticks(2)
			var skin=a.get_node("Skin").art
			check(skin.model==hero+"_"+["small","large","magic"][form],"model follows real form "+skin.model)
			check(a.scale==Vector2.ONE and a.get_node("Hitbox").shape.size==Vector2(24,32 if form==0 else 64),"collider outside visual transforms")
			check(skin.base_scale==Vector2(0.5,0.5),"2 px per world unit")
			for clip in skin.sprite.sprite_frames.get_animation_names():
				for frame in skin.sprite.sprite_frames.get_frame_count(clip):
					var tex:AtlasTexture=skin.sprite.sprite_frames.get_frame_texture(clip,frame)
					check(tex.region.end.x<=tex.atlas.get_width() and tex.region.end.y<=tex.atlas.get_height(),"valid region "+skin.model+"/"+str(clip)+"/"+str(frame))
		a.shoot()
		await ticks(6)
		var first_frame:int=a.get_node("Skin").art.sprite.frame
		a.shoot()
		await ticks(1)
		check(a.get_node("Skin").art.sprite.frame<=1 and first_frame>0,"each actual shot restarts cast once")
		await place_player(1500)
		press(KEY_SPACE,true)
		await ticks(15)
		a.damage()
		press(KEY_SPACE,false)
		await ticks(2)
		check(a.form==0 and a.velocity.y<0 and a.get_node("Skin").art.model==hero+"_small","airborne loss keeps physics and updates skin")
		a.damage(false,true)
		check(not a.visible and a.recovering>0,"death hides live actor immediately")
		await ticks(70)
		check(a.visible and a.form==0 and a.get_node("Skin").art.model==hero+"_small","respawn reuses small art")
	for level in ["1-1","1-2","1-3"]:
		await test_level(level)
		var terrain=game.world.get_node("ForestArt").get_child(2)
		for tile in terrain.tiles:
			var texture:Texture2D=terrain.cavern if tile[2] else terrain.forest
			check(tile[1].position.x>=0 and tile[1].position.y>=0 and tile[1].end.x<=texture.get_width() and tile[1].end.y<=texture.get_height(),"terrain region in atlas")
		for object in game.world.get_children():
			if object.get_script() and object.get_script().resource_path.ends_with("pipe.gd"):
				var parts=object.get_node("Skin").pipe_parts
				check(parts[0].position.y==-48 and parts[2].position.y+12==4 and parts[1].scale.y==1.25,"pipe keeps physical rim and continuous buried base")
	await test_level("1-3")
	state.finish(game.world.total_coins)
	game.show_page("result")
	check(Art.enabled(),"forest result keeps completed chapter theme")
	state.leave_result()
	check(not Art.enabled(),"next chapter map switches theme")
	for level in ["2-1","2-2","2-3"]:
		await test_level(level)
		check(not game.world.has_node("ForestArt") and not game.world.player.has_meta("forest_skin"),"Durotar remains isolated "+level)
		check(not Art.enabled(),"Durotar UI remains isolated")
	quit(1 if failed else 0)

