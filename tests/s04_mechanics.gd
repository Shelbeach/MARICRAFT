extends "res://tests/s02_forest.gd"

const MINER:="res://scenes/enemies/kobold.tscn"
const MURLOC4:="res://scenes/enemies/murloc.tscn"
var bounds_checked:=0

func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/s04/mechanics-%d"%OS.get_process_id())
	state.p={}
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	await objects()
	await hats()
	await mine()
	await arena()
	await sequence()
	quit(1 if failed else 0)

func objects() -> void:
	for level in ["2-1","2-2","2-3"]:
		await test_level(level)
		var w=game.world
		var space:PhysicsDirectSpaceState2D=w.get_world_2d().direct_space_state
		var ids:={}
		for n in w.get_children():
			if n.get("reward_id")!=null:
				check(not ids.has(n.reward_id) and n.reward_id.begins_with(level+"/"),"unique "+n.reward_id)
				ids[n.reward_id]=true
			if n.get("kind")=="coin" or n.has_method("defeat"):
				var q:=PhysicsShapeQueryParameters2D.new()
				q.shape=n.get_node("Hitbox").shape
				q.transform=n.get_node("Hitbox").global_transform
				q.transform.origin.y-=1
				q.collision_mask=1
				check(space.intersect_shape(q,1).is_empty(),"free object "+str(n.name))
				bounds_checked+=1
		print("INVENTORY ",level," total=",w.total_coins," threshold=",ceili(0.8*w.total_coins))

func drop_on(miner) -> void:
	var a=game.world.player
	a.position=miner.position-Vector2(0,63)
	a.velocity=Vector2(0,90)
	for i in 26:
		await ticks(1)
		if a.velocity.y<0: break

func hats() -> void:
	await test_level("2-1")
	var w=game.world
	var a=w.player
	var k=w.get_node("Scout")
	await drop_on(k)
	check(k.state==k.State.HIDDEN and not state.claimed(k.reward_id) and a.velocity.y<0,"descending contact hides and bounces without score")
	await place_player(440)
	await ticks(110)
	var left:float=k.wake_in
	await drop_on(k)
	check(k.wake_in<left and not state.claimed(k.reward_id),"second bounce does not extend five seconds")
	await place_player(450)
	await ticks(ceil(k.wake_in*60)+4)
	check(k.state==k.State.PATROL,"miner wakes after five seconds")
	await drop_on(k)
	var kx:float=k.position.x
	await place_player(kx-53)
	var victim=load(MURLOC4).instantiate()
	victim.position=Vector2(kx+117,479)
	victim.patrol_width=12
	victim.reward_id="2-1/test_roll_target"
	w.add_child(victim)
	press(KEY_D,true)
	await ticks(22)
	press(KEY_D,false)
	check(k.state==k.State.ROLLING and k.direction==1 and state.claimed(k.reward_id),"side contact kicks away and pays once")
	await ticks(40)
	check(not is_instance_valid(victim) and state.claimed("2-1/test_roll_target") and a.form==0 and state.p.hearts==3,"rolling hat defeats guard without hurting player")
	var score:int=state.p.score
	check(not state.reward("2-1/Scout",0,100,true) and state.p.score==score,"duplicate miner award rejected")
	check(not is_instance_valid(k),"hat consumed by first victim")
	await test_level("2-1")
	w=game.world
	a=w.player
	k=w.get_node("Scout")
	k.position=Vector2(225,479)
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
	other.reward_id="2-1/test_other_hat"
	w.add_child(other)
	other.state=other.State.HIDDEN
	other.set_height(27)
	other.push_hat(a)
	other.direction=1
	await ticks(18)
	check(not is_instance_valid(k) and not is_instance_valid(other),"two rolling hats disappear")
	for hidden in [false,true]:
		await test_level("2-1")
		w=game.world
		k=w.get_node("Scout")
		if hidden: await drop_on(k)
		await place_player(k.position.x-85)
		w.player.apply_form(2)
		w.player.facing=1
		press(KEY_E,true)
		await ticks(3)
		press(KEY_E,false)
		await ticks(30)
		check(state.claimed("2-1/Scout") and not is_instance_valid(k),"real bolt defeats miner hidden="+str(hidden))

func mine() -> void:
	await test_level("2-2")
	var w=game.world
	var a=w.player
	await place_player(w.checkpoint_x)
	check(w.checkpoint,"mine checkpoint activated")
	for f in [1,2]:
		await place_player(3400,447)
		a.apply_form(f)
		await place_player(3490,447)
		check(a.form==0 and state.p.hearts==3,"spikes remove form "+str(f))
		await place_player(w.checkpoint_x)
		await ticks(123)
	await place_player(3490,447)
	await ticks(70)
	check(state.p.hearts==2 and absf(a.position.x-w.checkpoint_x)<2 and a.form==0,"death returns small to checkpoint")
	await hit_block(2454)
	await place_player(2492)
	check(a.form==1 and state.claimed("2-2/GateGrowth/item"),"mine growth picked up from actual chest")
	var hearts:int=state.p.hearts
	for visit in 2:
		await place_player(3060,431)
		press(KEY_S,true)
		await ticks(3)
		press(KEY_S,false)
		check(w.underground and a.form==1,"mine entry visit "+str(visit))
		await place_player(7710)
		press(KEY_SPACE,true)
		await ticks(35)
		press(KEY_SPACE,false)
		await ticks(40)
		check(state.claimed("2-2/CrustB"),"hidden vein opened from below")
		await place_player(8760,431)
		press(KEY_S,true)
		await ticks(3)
		press(KEY_S,false)
		check(not w.underground and state.p.hearts==hearts and absf(a.position.x-3160)<3,"return preserves hearts")
	var coins:int=state.p.wallet
	game.start_level()
	await ticks(7)
	check(state.p.wallet==coins and game.world.get_node("CrustB")!=null,"restart restores physical block, retains vein ledger")
	game.world.player.apply_form(1)
	await hit_block(7710)
	check(state.p.wallet==coins,"rebreaking seam pays no extra coins")
	w=game.world
	await place_player(4040,447)
	await ticks(10)
	await place_player(4030,447)
	await place_player(4040,447)
	var spawned:=0
	for n in w.get_children():
		if n.get("reward_id")=="2-2/VentGuard": spawned+=1
	check(spawned==1 and w.get_node("Vent").triggered,"one enemy on repeated ambush approach")

func arena() -> void:
	await test_level("2-3")
	var w=game.world
	var a=w.player
	var b=w.boss
	await place_player(2540)
	await place_player(3898)
	press(KEY_D,true)
	await ticks(24)
	press(KEY_D,false)
	check(a.position.x<=3920 and game.page=="play" and b.hp==9,"closed gate blocks actual movement")
	var hat=load(MINER).instantiate()
	hat.position=Vector2(b.position.x-48,479)
	hat.reward_id="2-3/test_hat"
	w.add_child(hat)
	hat.state=hat.State.HIDDEN
	hat.set_height(27)
	hat.push_hat(a)
	hat.direction=1
	await ticks(15)
	check(not is_instance_valid(hat) and b.hp==9,"rolling hat stops on boss without damage")
	# Start one real ranged exchange, then deliberately stand in marked attacks.
	await place_player(3090)
	a.apply_form(2)
	a.facing=1
	for i in 1000:
		await ticks(1)
		if b.mode==b.Mode.WARN and b.attack_phase==1 and b.clock<0.34: press(KEY_SPACE,true)
		if b.mode==b.Mode.OPEN:
			press(KEY_SPACE,false)
			if i%8==1: press(KEY_E,true)
			if i%8==3: press(KEY_E,false)
		if b.hp<9: break
	press(KEY_E,false)
	press(KEY_SPACE,false)
	var retained:int=b.hp
	await ticks(440)
	check(retained<9 and a.form==0 and b.hp<=retained,"real ranged hit followed by form loss")
	for i in 900:
		await ticks(1)
		if state.p.hearts<3 and a.recovering<=0: break
	check(state.p.hearts==2 and absf(a.position.x-2540)<3 and b.hp>0 and b.hp<9,"death and same-world respawn preserve boss HP")
	game.start_level()
	await ticks(6)
	check(game.world.boss.hp==9,"full restart restores nine HP")
	# Isolate the economy from combat here; normal full wins are in s04_routes.
	game.world.boss.take_damage(9)
	var once:int=state.p.score
	game.start_level()
	await ticks(4)
	game.world.boss.take_damage(9)
	check(state.p.score==once and state.claimed("2-3/foreman"),"boss reward only once over full restart")
	for x in [2540,2770,3080,3120,3180,3300,3460,3720,3860]:
		await test_level("2-3")
		w=game.world
		a=w.player
		b=w.boss
		await place_player(x)
		a.facing=1 if x<b.position.x else -1
		a.apply_form(2)
		for tick in 900:
			press(KEY_E,tick%6==0)
			await ticks(1)
			if a.form==0 or b.hp==0: break
		press(KEY_E,false)
		check(b.hp>0 and (a.form==0 if x>=2780 else b.hp==9),"stationary spam x="+str(x))
	await test_level("2-3")
	await place_player(3300,360)
	for i in 1500:
		press(KEY_SPACE,game.world.player.is_on_floor())
		await ticks(1)
		if state.p.hearts<3: break
	press(KEY_SPACE,false)
	check(game.world.boss.hp>0 and state.p.hearts<3,"jumping in place cannot win")

func sequence() -> void:
	state.store.first_level="1-1"
	state.new_game("ogre")
	for level in ["1-1","1-2","1-3","2-1","2-2","2-3"]:
		check(state.p.level==level,"ordinary campaign enters "+level)
		state.reward(level+"/fixture",22,220)
		if level=="1-3": state.lose_heart()
		state.finish(25)
		game.next_map()
		game.start_level()
		await ticks(4)
		check(state.store.valid(state.store.read_profile()),"restore ordinary save after "+level)
	check(state.p.wallet==132 and state.p.hearts==2 and state.p.level=="3-1" and game.page=="future","ordinary campaign through 3-1; balances retained")
