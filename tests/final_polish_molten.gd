extends "res://tests/durotar_revision_branches.gd"
## Continuous input-only runs. No warp, position edits, damage immunity or reward calls.
var boss_attacks:={}
var route_log:Array=[]
var film_frames:=0
var evade_hold:=0

func drive(axis:int,jump:bool,shoot:=false) -> void:
	var a=game.world.player
	if a.is_on_floor():
		for shot in get_nodes_in_group("enemy_projectiles"):
			var gap:float=a.position.x-shot.position.x
			var closing:float=shot.direction.x*shot.speed_override-axis*160.0
			var meet:float=gap/closing if absf(closing)>1 else -1
			var future_y:float=shot.position.y+shot.direction.y*shot.speed_override*maxf(0,meet)
			if gap*shot.direction.x>0 and absf(gap)<110 and meet>=0 and future_y>a.position.y-a.height-6 and future_y<a.position.y+6:
				evade_hold=24
	super.drive(axis,jump or evade_hold>0,shoot)

func film_finish() -> void:
	pass

func next_frame() -> void:
	evade_hold=maxi(0,evade_hold-1)
	await super.next_frame()
	if frame_no%30==0:
		route_log.append({"level":level_id,"tick":frame_no,"x":game.world.player.position.x,"y":game.world.player.position.y,"form":game.world.player.form,"hearts":state.p.hearts})

func settle(count:=65) -> void:
	stop_keys()
	for i in count:
		drive(0,false)
		await next_frame()
		if pilot_failed: return
	stop_keys()

func valve(name:String,direction:=1) -> void:
	var vent=game.world.get_node(name)
	await approach(vent.position.x-direction*(vent.width/2+42))
	await settle(6)
	for i in 480:
		var phase:float=fmod(vent.age,vent.warning+vent.duration+vent.rest)
		if phase>=vent.warning+vent.duration+0.03 and phase<vent.warning+vent.duration+0.45 and game.world.player.is_on_floor(): break
		drive(0,false)
		await next_frame()
	await approach(vent.position.x+direction*(vent.width/2+46))
	check(not pilot_failed,"readable safe interval "+name)

func lift_to(name:String,x:float,y:float) -> void:
	var deck=game.world.get_node(name)
	var a=game.world.player
	var launched:=false
	var held:=0
	var boarded:=false
	for i in 900:
		if riding(a,deck): boarded=true;break
		if not launched and a.is_on_floor() and deck.elapsed>deck.period*0.8 and absf(a.position.x-deck.position.x)<125: launched=true
		if launched: held+=1
		drive(1 if launched and a.position.x<deck.position.x-2 else 0,launched and held<47)
		await next_frame()
		if pilot_failed: return
	check(boarded,"boarded "+name)
	if not boarded: pilot_failed=true;return
	visited[name]=true
	for i in 650:
		if deck.position.y<=y+4: break
		drive(signi(roundi(deck.position.x-a.position.x)) if absf(deck.position.x-a.position.x)>7 else 0,false)
		await next_frame()
	stop_keys()
	await hop(x,y)

func stage_one() -> void:
	if alternative:
		await approach(286)
		await hop(400,352)
		await approach(474)
		if entering_form>0: await jump_here()
		# A growth chest is intentionally skipped in a strict small-form run.
	await valve("FirstVent")
	await approach(1510,[748,1200])
	if alternative:
		await approach(1615)
		await hop(1700,350)
		await centre(1744)
		await jump_here()
		await approach(1835)
		await hop(1905,302)
		await approach(1950)
		await hop(2008,270)
		await centre(2084)
		await jump_here()
		await approach(2278)
		await settle(70)
		await approach(2190)
		await valve("LowerValveB",-1)
		await approach(1860)
		await valve("LowerValveB")
	else:
		await approach(1612)
		await settle(65)
		await valve("LowerValveA")
		await valve("LowerValveB")
	await approach(2480)
	if alternative:
		await centre(2604)
		await jump_here()
		await approach(2715)
		await hop(2830,352)
		await approach(3000)
		await approach(3068)
	else: await approach(3068)
	await lift_to("ChainLift",3294,340)
	await approach(3560)
	await settle(55)
	await approach(3808,[3598])
	await valve("LastValve")
	if alternative:
		await approach(4232,[4056])
		await settle(60)
		await jump_here()
	await approach(4303,[4056])

func chamber() -> void:
	var w=game.world
	await approach(2580)
	await pipe_down()
	check(w.underground,"3-2 entered actual pipe")
	await approach(6920)
	await hop(7054,352)
	await centre(7124)
	await jump_here()
	await approach(7275)
	await settle(65)
	await approach(7775,[7270])
	await lift_to("VaultLift",7970,328)
	await centre(8042)
	await jump_here()
	await approach(8200)
	await pipe_down()
	check(not w.underground and w.player.position.x>2640,"3-2 returned safely")
	var coins:int=state.p.coins
	# Revisit without reconstructing the room or its spent chests.
	await approach(2580)
	await pipe_down()
	check(w.get_node("ChamberCache").spent and w.get_node("VaultCache").spent and state.p.coins>=coins,"pipe revisit keeps spent chests; only new loose coins remain available")
	await approach(8200,[7270])
	await pipe_down()

func stage_two() -> void:
	var w=game.world
	# Read the new entrance caster's first shot before crossing the low ceiling.
	# Waiting below the ledge lets its upward-aimed ball pass above the route.
	await approach(399)
	await settle(60)
	await approach(677)
	await crossing(w.get_node("LavaCarrier"),1060)
	if alternative:
		await approach(1462)
		await hop(1580,352)
		await wait_and_stomp()
		await centre(1654)
		await jump_here()
		await approach(1774)
		await hop(1838,304)
		await hop(1915,272)
		await centre(1986)
		await jump_here()
		await approach(2150)
	else:
		await approach(1462)
		await settle(65)
		await valve("TowerValve")
	await approach(2480)
	if alternative: await chamber()
	await approach(2758)
	await crossing(w.get_node("Counterweight"),3150)
	if alternative:
		await approach(3272)
		await hop(3360,252)
		await centre(3402)
		await jump_here()
	await approach(3500)
	await settle(55)
	await approach(3800,[3522])
	await approach(4008)
	if alternative:
		await approach(4024)
		await hop(4135,352)
		await centre(4172)
		await jump_here()
		await approach(4300)
	else: await approach(4260,[4123])
	await valve("CastingValve")
	await approach(4418)
	await crossing(w.get_node("LastBridge"),4780)
	await valve("LastBreath")
	if alternative:
		await approach(5472,[4978])
		await settle(60)
		await jump_here()
	await approach(5543,[4978])
	check(w.get_node("DangerVent").triggered,"danger pipe triggered once on wide ground")

func fight(ranged:bool) -> void:
	var w=game.world
	var a=w.player
	var b=w.boss
	var held:=0
	var last_hp:int=b.hp
	var phases:={}
	var evade:=1900.0
	var old_step:=-1
	var stomp_started:=false
	var points:int=state.p.score
	var coins:int=state.p.coins
	for i in 14000:
		if pilot_failed or b.hp<=0: break
		phases[b.phase()]=true
		var x:float=a.position.x
		var use_magic:bool=ranged and ("--mixed" not in OS.get_cmdline_user_args() or b.phase()==2)
		var target:float=b.position.x-112
		var leap:=wall_requires_jump(a)
		if b.mode!=b.Mode.OPEN or b.hits>=2: stomp_started=false
		if b.mode==b.Mode.WARN and b.phase()*100+b.step!=old_step:
			old_step=b.phase()*100+b.step
			boss_attacks[b.attack]=true
			evade=x-95 if x>b.arena_start+120 else x+95
		if b.mode in [b.Mode.WARN,b.Mode.STRIKE]:
			if b.attack==b.Attack.ERUPTION: target=evade
			else:
				target=b.position.x-112
		elif b.mode==b.Mode.OPEN:
			if b.hits>=2: target=b.position.x-120
			elif use_magic:
				target=b.position.x-112
			else:
				if a.is_on_floor(): stomp_started=true
				target=b.position.x if stomp_started else b.position.x-112
				if stomp_started and absf(b.position.x-x)<135: leap=true
		else: target=1910
		if b.attack==b.Attack.FIREBALL and not get_nodes_in_group("boss_shots").is_empty():
			target=x
			stomp_started=false
		for shot in get_nodes_in_group("boss_shots"):
			if (x-shot.position.x)*shot.direction.x>0 and absf(x-shot.position.x)<105 and shot.position.y>=a.position.y-a.height-20 and shot.position.y<=a.position.y+10: leap=true
		if held<=0 and leap and a.is_on_floor(): held=45
		var axis:=signi(roundi(target-x)) if absf(target-x)>3 else 0
		var shoot:bool=use_magic and b.mode==b.Mode.OPEN and a.is_on_floor() and b.hits<2 and i%15==1
		if shoot: axis=signi(roundi(b.position.x-x))
		drive(axis,held>0,shoot)
		held-=1
		await next_frame()
		if b.hp!=last_hp:
			check(last_hp-b.hp==(1 if use_magic else 3),"Ragnaros normal hit %d -> %d"%[last_hp,b.hp])
			last_hp=b.hp
		if "--trace" in OS.get_cmdline_user_args() and i%30==0: print("BOSS ",i," player=",a.position," hp=",b.hp," mode=",b.mode," attack=",b.attack," clock=",b.clock)
	stop_keys()
	check(b.hp==0 and phases.size()==3,"Ragnaros defeated across all phases")
	check(boss_attacks.size()==3,"all three attack types encountered in normal fight")
	check(state.p.score-points-10*(state.p.coins-coins)==10000 and state.claimed(b.reward_id),"Ragnaros reward exactly once")
	check(get_nodes_in_group("molten_attacks").filter(func(n):return not n.is_queued_for_deletion()).is_empty(),"boss death clears attacks immediately")
	await settle(125)

func stage_three() -> void:
	await approach(201)
	await settle(65)
	if alternative:
		await hop(279,352)
		await centre(302)
		await jump_here()
	await approach(390 if alternative else 360)
	await settle(55)
	await approach(800,[388])
	await settle(65)
	await approach(1340,[822])
	await approach(1442)
	# Keep form-specific boss routes below the same rules: jump over the
	# now-accessible optional rune. Its ordinary floor pickup is tested separately.
	await approach(1730)
	await settle(4)
	await approach(1910,[1730])
	await fight(entering_form==2)
	if alternative and not pilot_failed:
		await approach(1660)
		await settle(65)
		await approach(1740)
		await approach(2580)
		await settle(65)
		await approach(2630)
	if not pilot_failed: await approach(3023)

func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/final-polish/route-%d"%OS.get_process_id())
	state.store.first_level="3-1"
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	var args:=OS.get_cmdline_user_args()
	var hero:="ogre" if "--ogre" in args else "human"
	alternative="--alternative" in args
	var only:=""
	for arg in args:
		if arg.begins_with("--level="): only=arg.trim_prefix("--level=");state.store.first_level=only
	for form in 3:
		if "--small" in args and form!=0 or "--big" in args and form!=1 or "--magic" in args and form!=2: continue
		entering_form=form
		state.new_game(hero)
		state.p.hearts=1
		game.start_level()
		for id in ([only] if not only.is_empty() else ["3-1","3-2","3-3"]):
			start_stage(id)
			await ticks(6)
			var a=game.world.player
			a.apply_form(form)
			expected_form=form
			match id:
				"3-1": await stage_one()
				"3-2": await stage_two()
				"3-3": await stage_three()
			stop_keys()
			await settle(4)
			check(game.page in ["result","victory"] and state.p.hearts==1 and a.form==form,"FINISH %s %s form=%d no damage"%[hero,id,form])
			if failed or pilot_failed:
				print("STOP ",id," at=",a.position," form=",a.form," hearts=",state.p.hearts," tick=",frame_no)
				quit(1);return
			check(state.store.valid(state.store.read_profile()),"saved result valid "+id)
			print("COINS ",id," ",state.p.last_result.coins,"/",state.p.last_result.total," stars=",state.p.last_result.stars)
			if alternative and form==0:
				check(state.p.last_result.coins>=ceili(state.p.last_result.total*0.8) and state.p.last_result.stars==3,"small hero earns three stars without magic "+id)
			if film_frames>0: await ticks(film_frames)
			var report_stage:="arena-polish" if "--arena-polish" in args else "final-polish"
			var dir:="res://reports/evidence/"+report_stage+"/molten/"+("30/" if "--30" in args else "60/")
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
			var file:=FileAccess.open(dir+"route-%s-%s-%d-%s.json"%[hero,id,form,"alt" if alternative else "main"],FileAccess.WRITE)
			file.store_string(JSON.stringify({"input":events,"ticks":frame_no,"samples":route_log,"boss_attacks":boss_attacks,"result":state.p.last_result}))
			if id=="3-3" and film_frames>0: await film_finish()
			if id!="3-3" and only.is_empty(): game.next_map();game.start_level()
		game.main_menu()
		await process_frame
		await process_frame
	print("CAMPAIGN POLISH MOLTEN ROUTES ","FAIL" if failed else "PASS")
	root.get_node("SFX").new_world(false)
	root.get_node("MusicManager").stop_all()
	# Allow the real audio mixer to release the last WAV before a fast headless exit.
	OS.delay_msec(120)
	quit(1 if failed else 0)

