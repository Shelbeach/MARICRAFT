extends "res://tests/forest_art_routes.gd"
const Art:=preload("res://scripts/visual/art_library.gd")
const Sprite:=preload("res://scripts/visual/art_sprite.gd")

func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/animation-fix/regression-%d"%OS.get_process_id())
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for hero in ["human","ogre"]:
		for form in 3:
			state.new_game(hero)
			game.start_level()
			await ticks(5)
			var a=game.world.player
			a.apply_form(form)
			await ticks(2)
			var skin=a.get_node("Skin")
			var model:String=skin.art.model
			var probe:=Sprite.new()
			root.add_child(probe)
			probe.set_actor(model)
			probe.play("jump")
			probe.sprite.pause()
			probe.sprite.frame=1
			var one:float=painted_height(probe)
			probe.sprite.frame=2
			check(absf(one-painted_height(probe))<1,"same airborne pose keeps size "+model)
			probe.play("idle")
			probe.sprite.pause()
			one=painted_height(probe)
			probe.play("land")
			probe.sprite.pause()
			probe.sprite.frame=2
			check(absf(one-painted_height(probe))<1,"settle returns to identical idle size "+model)
			probe.play_locomotion("run",160)
			var full:float=probe.sprite.speed_scale
			probe.play_locomotion("run",80)
			check(is_equal_approx(probe.sprite.speed_scale,full/2),"foot cadence follows travel speed "+model)
			probe.free()
			# Jump during a stationary landing. The next takeoff must not retain it.
			skin.override_clip="land"
			skin.override_time=0.16
			press(KEY_SPACE,true)
			await ticks(3)
			check(not a.is_on_floor() and skin.art.sprite.animation=="jump","new jump interrupts landing "+model)
			press(KEY_SPACE,false)
			await ticks(65)
			check(a.scale==Vector2.ONE and a.get_node("Hitbox").shape.size==Vector2(24,32 if form==0 else 64),"animation never scales body "+model)
			# Actual enemy stomp, not a direct defeat call.
			var enemy=load("res://scenes/enemies/murloc.tscn").instantiate()
			enemy.position=Vector2(300,480)
			enemy.reward_id="animation-stomp-"+model
			game.world.add_child(enemy)
			await ticks(2)
			a.position=Vector2(enemy.position.x,435)
			a.previous_feet=435
			a.velocity=Vector2(0,180)
			await ticks(12)
			check(not is_instance_valid(enemy) and state.p.hearts==3 and a.velocity.y<0,"enlarged enemy stomp remains readable and functional "+model)
			check(state.p.enemies==1 and state.p.ids.has("animation-stomp-"+model),"enemy reward recorded once "+model)
	# Full-size enemy endings use the same transform, and patrol remains 30x28.
	var enemy=load("res://scenes/enemies/murloc.tscn").instantiate()
	check(enemy.scale==Vector2.ONE and enemy.get_node("Hitbox").shape.size==Vector2(30,28),"enemy visual size does not change collision")
	enemy.free()
	for clip in ["idle","patrol","turn","pipe_emerge","stomp_defeat","magic_defeat"]:
		var art:=Sprite.new()
		root.add_child(art)
		art.set_actor("murloc")
		art.play(clip)
		check(art.sprite.scale.x>=0.69,"enlargement applies to "+clip)
		art.free()
	print("ANIMATION REGRESSION ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func painted_height(art:Node) -> float:
	var texture:AtlasTexture=art.sprite.sprite_frames.get_frame_texture(art.sprite.animation,art.sprite.frame)
	return texture.get_image().get_used_rect().size.y*art.sprite.scale.y
