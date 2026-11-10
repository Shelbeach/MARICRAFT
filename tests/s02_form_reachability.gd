extends "res://tests/s02_forest.gd"

# Foot routes that must be walkable under overhead geometry; takeoff and ferry
# approaches are exercised by the continuous route driver instead.
const PASSAGES := {
	"1-1":[[544,656,480],[856,1024,480],[1088,1312,480],[1952,2096,480],[2152,2624,480],
		[2800,2952,480],[3472,3624,480],[3672,3856,480],[4160,4480,508],[4544,4728,480],
		[5130,5170,480],[5360,5568,294],[5832,5952,480],[6240,6352,480],[6864,7016,480]],
	"1-2":[[1104,1248,480],[1304,1372,456],[1872,2032,480],[2480,2616,480],
		[3520,3640,480],[3808,3968,260],[4544,4672,480],[4720,4808,480],
		[6656,6708,432],[6736,6826,384],[6856,6968,336],[7136,7230,424],[7248,7378,364]],
	"2-1":[[300,440,480],[600,740,480],[1115,1225,448],[1875,1995,448],[2620,2760,440],[3115,3290,480],[3795,3925,416],[4760,4870,448]],
	"2-2":[[430,608,480],[1475,1655,480],[2390,2530,480],[2785,2945,480],[3145,3220,480],[7475,7665,480],[8145,8305,480],[8465,8615,480]],
	"2-3":[[395,485,480],[765,865,448],[1275,1415,416],[1915,2105,480],[2510,2730,480],[3070,3510,480]],
	"1-3":[[496,640,480],[496,640,384],[879,1231,480],[1912,2024,480],[2340,2452,480],[2500,2592,480]]
}
const EVIDENCE := "res://reports/evidence/s02fix/"
var target_form := 0
var in_cave_done := false
var wanted := 0
var damage_run := false
var lost_power := false
var next_shot := 0
var rune_seen := false
var drank := false
var opened := false
var struck := {}
var boundary_shot := false
var before := false
var film := false
var still_frames := 0
var high_x := 0.0
var last_axis := 0
var recording := false
var sample_count := 0

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/temp"))
	var args := OS.get_cmdline_user_args()
	before = "--before" in args
	film = "--film" in args
	if film:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/temp/s02fix/clip"))
	var hero := "ogre" if "--ogre" in args else "human"
	state = root.get_node("Campaign")
	state.store.prefix = ProjectSettings.globalize_path("res://reports/temp/form-test-%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()])
	state.p = {}
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for form in ([1] if before else [0,1,2]):
		target_form=form
		game.pages.request_new()
		if game.page=="confirm":
			game.pending.call()
		game.pages.select_hero(hero)
		game.pages.start_campaign()
		if form==2:
			state.start_sandbox()
		game.start_level()
		for level: String in ["1-1","1-2","1-3"]:
			await ticks(5)
			var actor=game.world.player
			in_cave_done=false
			struck.clear()
			drank=false
			opened=false
			boundary_shot=false
			still_frames=0
			high_x=actor.position.x
			wanted=form
			if form==1 and level=="1-1":
				wanted=0
			else:
				# Only the starting form is prepared. The rest is keyboard input.
				check(actor.apply_form(form),"starting shape "+level+" "+str(form))
			if not before:
				audit_passages(level,actor)
			await route(level,false)
			if game.page!="result":
				if film: await snapshot("before" if before else "failure")
				break
			check(actor.form==form and (level!="1-1" or form!=1 or drank),"FINISH "+hero+" "+level+" form="+str(form))
			if form==2 and level=="1-3":
				check(rune_seen,"arena rune collected during magic route")
			game.next_map()
			game.start_level()
		if before or failed: break
		game.main_menu()
	if not before and not failed:
		await damage_recovery_route()
		await tight_growth()
	if film and not before:
		print("VIDEO FRAMES ",sample_count)
	quit(1 if failed else 0)

func audit_passages(level: String, actor) -> void:
	var shape: RectangleShape2D=actor.get_node("Hitbox").shape
	var probe:=RectangleShape2D.new()
	probe.size=shape.size+Vector2(2,4)
	var q:=PhysicsShapeQueryParameters2D.new()
	q.shape=probe
	q.collision_mask=1
	var space: PhysicsDirectSpaceState2D=actor.get_world_2d().direct_space_state
	# Inspect authored bonus sources in this world, including the grotto.
	for source in game.world.get_children():
		if source.get("kind") not in ["potion","rune"]:
			continue
		var mouth: Vector2=source.global_position
		if source.has_method("release_offset"):
			var item=source.POTION.instantiate()
			mouth+=source.release_offset(item.get_node("Hitbox").shape)
			item.free()
		var ray:=PhysicsRayQueryParameters2D.create(mouth,mouth+Vector2(0,280),1)
		var landing:=space.intersect_ray(ray)
		if landing.is_empty():
			check(false,"no landing for "+str(source.name))
			continue
		var foot: Vector2=landing.position
		q.transform.origin=foot-Vector2(0,probe.size.y/2+0.2)
		var clear:=space.intersect_shape(q,1).is_empty()
		var exit_clear:=false
		for dx in [-shape.size.x,shape.size.x]:
			q.transform.origin.x=foot.x+dx
			exit_clear=exit_clear or space.intersect_shape(q,1).is_empty()
		check(clear and exit_clear,"bonus clearance %s %s shape=%s"%[level,source.name,shape.size])
	for span: Array in PASSAGES[level]:
		for x in range(span[0],span[1]+1,4):
			q.transform.origin=Vector2(x,span[2]-probe.size.y/2-0.2)
			var obstacles:=space.intersect_shape(q,1)
			if not obstacles.is_empty():
				check(false,"CLEARANCE %s x=%d form=%d body=%s obstacle=%s"%[level,x,actor.form,shape.size,obstacles[0].collider.name])
				break

func snapshot(id: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(EVIDENCE+id+".png")

func frame_capture() -> void:
	if film and recording and not before and Engine.get_physics_frames()-last_capture>=6:
		last_capture=Engine.get_physics_frames()
		await RenderingServer.frame_post_draw
		var img:=root.get_texture().get_image()
		img.resize(640,360,Image.INTERPOLATE_BILINEAR)
		img.save_png("res://reports/temp/s02fix/clip/%04d.png"%sample_count)
		sample_count+=1

func route_action(level: String,a) -> void:
	if level=="1-3" and state.claimed("1-3/arena_rune"):
		rune_seen=true
	if a.form==2:
		press(KEY_E,false)
		if Engine.get_physics_frames()>=next_shot:
			for foe in game.world.get_children():
				if (foe.has_method("defeat") or foe.has_method("magic_hit")) and foe.position.x-a.position.x>10 and foe.position.x-a.position.x<255:
					press(KEY_E,true)
					next_shot=Engine.get_physics_frames()+16
					break
	if damage_run and not lost_power and a.form==0:
		lost_power=true
		wanted=0
	if level=="1-1" and a.form>0 and not before:
		for name in ["Block3792","Block4296"]:
			var support=game.world.get_node_or_null(name)
			if support and not struck.has(name) and a.position.x>=support.position.x-5:
				struck[name]=true
				await head_strike()
				check(not game.world.has_node(name),"physical removal of "+name)
	if level=="1-2" and not in_cave_done and a.position.x>=2141 and a.position.x<2180:
		in_cave_done=true
		await cave_detour(a)
	if level=="1-1" and target_form==1:
		if not opened and a.position.x>=2601:
			opened=true
			recording=true
			press(KEY_D,false)
			await ticks(8)
			press(KEY_SPACE,true)
			await ticks(32)
			press(KEY_SPACE,false)
			await ticks(34)
			press(KEY_D,true)
		if opened and not drank and a.form==1:
			drank=true
			wanted=1
			if not before: audit_passages(level,a)
			print("POTION ",state.p.hero," feet=",a.position," body=",a.get_node("Hitbox").shape.size)
		if not before and a.position.x>=3470 and not boundary_shot:
			boundary_shot=true
			if film: await snapshot("after")
		if a.position.x>=3575: recording=false

func head_strike() -> void:
	press(KEY_D,false)
	press(KEY_SPACE,false)
	await ticks(8)
	press(KEY_SPACE,true)
	await ticks(30)
	press(KEY_SPACE,false)
	await ticks(36)
	press(KEY_D,true)

func cave_detour(a) -> void:
	press(KEY_D,false)
	press(KEY_SPACE,false)
	await ticks(65)
	press(KEY_S,true)
	await ticks(3)
	press(KEY_S,false)
	check(game.world.underground and a.form==wanted,"enter cave form "+str(wanted))
	if not game.world.underground: return
	press(KEY_D,true)
	var held:=0
	var used_bonus:=false
	for frame in 900:
		await ticks(1)
		if a.position.x>=7525: break
		if (wanted>0 or damage_run) and not used_bonus and a.position.x>=6568:
			used_bonus=true
			press(KEY_D,false)
			await ticks(7)
			press(KEY_SPACE,true)
			await ticks(30)
			press(KEY_SPACE,false)
			await ticks(40)
			press(KEY_D,true)
		if held>0:
			held-=1
			if held==0: press(KEY_SPACE,false)
		elif a.is_on_floor() and (a.is_on_wall() or (a.position.x>6948 and a.position.x<6990)):
			press(KEY_SPACE,true)
			held=36
	press(KEY_D,false)
	press(KEY_SPACE,false)
	await ticks(42)
	press(KEY_DOWN,true)
	await ticks(4)
	press(KEY_DOWN,false)
	if damage_run:
		wanted=1
	check(not game.world.underground and a.form==wanted,"return from cave form "+str(wanted))
	if wanted>0: check(state.claimed("1-2/grotto_growth/item"),"cave potion collected")
	press(KEY_D,true)

func damage_recovery_route() -> void:
	await test_level("1-2")
	target_form=1
	wanted=1
	in_cave_done=false
	damage_run=true
	still_frames=0
	high_x=0
	game.world.player.apply_form(1)
	await route("1-2",false)
	check(lost_power and game.page=="result" and game.world.player.form==1,"completed after spikes, small entry and real regrowth in grotto")
	damage_run=false

func tight_growth() -> void:
	# A local adverse fixture, separate from the end-to-end runs.
	await test_level("1-1")
	var ceiling=load("res://scenes/objects/test_platform.tscn").instantiate()
	ceiling.position=Vector2(1450,408)
	ceiling.size=Vector2(100,20)
	game.world.add_child(ceiling)
	await place_player(1544)
	var potion=load("res://scenes/objects/potion.tscn").instantiate()
	potion.reward_id="fixture/tight_growth"
	potion.position=Vector2(1556,460)
	game.world.add_child(potion)
	await ticks(5)
	check(game.world.player.form==0 and not state.claimed(potion.reward_id),"blocked growth leaves potion unclaimed")
	press(KEY_D,true)
	await ticks(15)
	press(KEY_D,false)
	check(game.world.player.form==1 and state.claimed("fixture/tight_growth"),"potion grants growth once clear")

func route_jump(level: String,a,jump: bool) -> bool:
	if damage_run and not lost_power and a.position.x<480:
		return false
	if level=="1-1" and target_form==1 and a.position.x>3430 and a.position.x<3572:
		return false # This is the lower passage being audited.
	if level=="1-3" and target_form>0 and a.position.x>2036 and a.position.x<2060:
		return true
	if level=="1-3" and target_form==2 and a.position.x>1918 and a.position.x<1940:
		return true
	return jump

func route_continue(level: String,a,axis: int,_frame: int) -> bool:
	if a.form!=wanted or (level=="1-1" and opened and not drank and a.position.x>2695):
		check(false,"FORM %s at %s expected %d actual %d"%[level,a.position,wanted,a.form])
		return false
	if axis!=last_axis or absf(a.position.x-high_x)>2:
		last_axis=axis
		still_frames=0
		high_x=a.position.x
	else:
		still_frames+=1
	if still_frames>(480 if axis==0 else 120):
		var obstacles: Array[String]=[]
		for i in a.get_slide_collision_count():
			obstacles.append(str(a.get_slide_collision(i).get_collider().name))
		check(false,"STUCK %s %s form=%d at %s contacts=%s"%[state.p.hero,level,a.form,a.position,obstacles])
		return false
	return true
