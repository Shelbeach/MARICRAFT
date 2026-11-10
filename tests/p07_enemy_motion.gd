extends "res://tests/s04_mechanics.gd"
var seen:={}
func _initialize() -> void:
	root.unfocusable=true
	run.call_deferred()
func test_level(id:String) -> void:
	await super.test_level(id)
	var k=game.world.get_node("Keeper")
	k.position=Vector2(2425,479)
	k.origin=2425
	k.patrol_width=30
	await place_player(2640)
func ticks(count:int) -> void:
	for i in count:
		await physics_frame
		if not is_instance_valid(game) or not is_instance_valid(game.world): continue
		if "--capture" not in OS.get_cmdline_user_args(): continue
		await RenderingServer.frame_post_draw
		for n in game.world.get_children():
			if not n.has_node("Skin") or n.get("wake_in")==null: continue
			var tag:String=String(n.get_node("Skin").art.sprite.animation)
			if not seen.has(tag):
				seen[tag]=true
				root.get_texture().get_image().save_png("res://reports/evidence/p07/enemies/"+tag+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/evidence/p07/enemies"))
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	await hats()
	print("P07 HAT MECHANICS ","FAIL" if failed else "PASS", " captured=",seen)
	game.clear_world()
	await process_frame
	root.get_node("SFX").new_world(false)
	OS.delay_msec(120)
	quit(1 if failed else 0)
func hats() -> void:
	await test_level("3-1")
	var w=game.world
	var a=w.player
	var k=w.get_node("Keeper")
	await drop_on(k)
	check(k.state==k.State.HIDDEN and not state.claimed(k.reward_id) and a.velocity.y<0,"descending contact hides and bounces without score")
	await place_player(2640)
	await ticks(110)
	var left:float=k.wake_in
	await drop_on(k)
	check(k.wake_in<left and not state.claimed(k.reward_id),"second bounce does not extend five seconds")
	await place_player(2650)
	await ticks(ceil(k.wake_in*60)+4)
	check(k.state==k.State.PATROL,"miner wakes after five seconds")
	await drop_on(k)
	var kx:float=k.position.x
	await place_player(kx-53)
	var victim=load(MURLOC4).instantiate()
	victim.position=Vector2(kx+117,479)
	victim.patrol_width=12
	victim.reward_id="3-1/test_roll_target"
	w.add_child(victim)
	press(KEY_D,true)
	await ticks(22)
	press(KEY_D,false)
	check(k.state==k.State.ROLLING and k.direction==1 and state.claimed(k.reward_id),"side contact kicks away and pays once")
	await ticks(40)
	check(not is_instance_valid(victim) and state.claimed("3-1/test_roll_target") and a.form==0 and state.p.hearts==3,"rolling hat defeats guard without hurting player")
	var score:int=state.p.score
	check(not state.reward("3-1/Keeper",0,100,true) and state.p.score==score,"duplicate miner award rejected")
	check(not is_instance_valid(k),"hat consumed by first victim")
	await test_level("3-1")
	w=game.world
	a=w.player
	k=w.get_node("Keeper")
	k.position=Vector2(2425,479)
	k.state=k.State.HIDDEN
	k.set_height(27)
	k.push_hat(a)
	var wall=load("res://scenes/objects/test_platform.tscn").instantiate()
	wall.position=Vector2(k.position.x+48,415)
	wall.size=Vector2(20,65)
	w.add_child(wall)
	await ticks(18)
	check(k.direction==-1,"rolling hat ricochets from solid wall")
	var other=load(MINER).instantiate()
	other.position=Vector2(k.position.x-53,479)
	other.reward_id="3-1/test_other_hat"
	w.add_child(other)
	other.state=other.State.HIDDEN
	other.set_height(27)
	other.push_hat(a)
	other.direction=1
	await ticks(18)
	check(not is_instance_valid(k) and not is_instance_valid(other),"two rolling hats disappear")
	for hidden in [false,true]:
		await test_level("3-1")
		w=game.world
		k=w.get_node("Keeper")
		if hidden: await drop_on(k)
		await place_player(k.position.x-85)
		w.player.apply_form(2)
		w.player.facing=1
		press(KEY_E,true)
		await ticks(3)
		press(KEY_E,false)
		await ticks(30)
		check(state.claimed("3-1/Keeper") and not is_instance_valid(k),"real bolt defeats miner hidden="+str(hidden))

