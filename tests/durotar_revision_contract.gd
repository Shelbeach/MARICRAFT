extends "res://tests/s02_forest.gd"
const Miner:="res://scenes/enemies/kobold.tscn"
const Guard:="res://scenes/enemies/murloc.tscn"
var emissions:Array=[]

func fixture() -> void:
	await test_level("2-1")
	for n in game.world.get_children():
		if n.has_method("defeat"): n.queue_free()
	await ticks(2)
	await place_player(2480)
	game.world.player.protection=0
	emissions.clear()

func hat(x:float,direction:int,id:String):
	var k=load(Miner).instantiate()
	k.position=Vector2(x,479)
	k.reward_id="2-1/fixture_"+id
	game.world.add_child(k)
	k.state=k.State.HIDDEN
	k.set_height(27)
	k.visual_event.connect(func(event): emissions.append(event))
	k.push_hat(game.world.player)
	k.direction=direction
	return k

func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/durotar-revision/contract-%d"%OS.get_process_id())
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for form in 3:
		await fixture()
		var a=game.world.player
		a.apply_form(form)
		var k=hat(2390,1,"player"+str(form))
		await ticks(35)
		check(not is_instance_valid(k),"hat consumed by player form "+str(form))
		check(state.p.hearts==(2 if form==0 else 3) and a.form==0,"normal contact damage, one processing form "+str(form))
		check(emissions==["hat_collision"],"no body death for consumed hat")
	await fixture()
	game.world.player.protection=2
	var k=hat(2390,1,"protected")
	await ticks(35)
	check(state.p.hearts==3 and not is_instance_valid(k),"protection respected; colliding hat still consumed")
	await fixture()
	var victim=load(Guard).instantiate()
	victim.position=Vector2(2360,479)
	victim.reward_id="2-1/fixture_victim"
	victim.patrol_width=0
	game.world.add_child(victim)
	k=hat(2280,1,"projectile")
	await ticks(35)
	check(not is_instance_valid(victim) and not is_instance_valid(k),"one enemy collision consumes both objects")
	print("HAT ECONOMY ",state.p.score," enemies=",state.p.enemies," ids=",state.p.ids)
	check(state.p.enemies==2 and state.p.score==200,"kick and victim awarded exactly once")
	var score:int=state.p.score
	check(not state.reward("2-1/fixture_victim",0,100,true) and state.p.score==score,"enemy ID blocks duplicate reward")
	await fixture()
	k=hat(2280,1,"pair_a")
	var other=hat(2390,-1,"pair_b")
	await ticks(25)
	check(not is_instance_valid(k) and not is_instance_valid(other),"two moving hats disappear")
	check(emissions.count("death")==0 and emissions.count("hat_collision")==2 and state.p.enemies==2,"pair has no bodies, no death replay, no collision awards")
	await fixture()
	var hats:Array=[hat(2320,1,"many_a"),hat(2350,-1,"many_b"),hat(2340,1,"many_c")]
	await ticks(1)
	check(emissions.count("death")==0 and state.p.score==300,"simultaneous contacts cannot duplicate rewards or corpses")
	await fixture()
	var wall=load("res://scenes/objects/test_platform.tscn").instantiate()
	wall.position=Vector2(2400,400)
	wall.size=Vector2(20,80)
	game.world.add_child(wall)
	k=hat(2350,1,"wall")
	await ticks(18)
	check(is_instance_valid(k) and k.direction==-1,"solid wall reverses sliding hat")
	var skin=k.get_node("Skin")
	check(skin.art.sprite.animation=="rolling" and skin.art.sprite.sprite_frames.get_frame_count("rolling")==8 and skin.art.rotation==0,"P06 eight-frame planted slide; visual node never rotates")
	await fixture()
	k=load(Miner).instantiate()
	k.position=Vector2(2300,479)
	k.patrol_width=12
	k.reward_id="2-1/fixture_turn"
	game.world.add_child(k)
	var reversals:=0
	var previous:int=k.direction
	for i in 100:
		await ticks(1)
		await process_frame
		if k.direction!=previous:
			previous=k.direction
			reversals+=1
			check(absf(k.velocity.x)<0.1,"patrol stops during turn")
		if k.patrol_turn<=0: check(k.get_node("Skin").art.scale.x==k.direction,"walking sprite matches movement direction")
	check(reversals>=2,"turn fixture crossed both patrol boundaries")
	await test_level("2-3")
	var b=game.world.boss
	game.world.player.position=Vector2(b.position.x-220,479)
	k=hat(b.position.x-70,1,"boss")
	await ticks(30)
	check(not is_instance_valid(k) and b.hp==9,"hat cannot damage boss")
	b.take_damage(9)
	check(b.mode==b.Mode.DEAD and state.claimed(b.reward_id),"DEAD awards immediately")
	await ticks(2)
	check(game.world.get_node("Gate/Hitbox").disabled and get_nodes_in_group("mine_strikes").is_empty(),"DEAD opens gate and clears attacks before clip ends")
	var facing:float=b.get_node("Skin").art.scale.x
	game.world.player.position.x=b.position.x+200
	await ticks(65)
	check(b.get_node("Skin").art.scale.x==facing and b.get_node("Skin").art.sprite.frame==5,"corpse rests on final frame without following player")
	check(absf(b.global_position.y+b.get_node("Skin").art.position.y-482)<1,"corpse grounded at physical floor")
	print("REVISION CONTRACT ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
