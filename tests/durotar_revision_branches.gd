extends "res://tests/s04_routes.gd"
## Each case begins on a named safe landing; every ascent/opening is real input.
var cases:=[
	["2-1",Vector2(500,432),[[650,352]],"TrailPay"],
	["2-1",Vector2(1040,400),[[1130,320],[1245,320],[1414,278]],"RidgePay"],
	["2-1",Vector2(1750,370),[[1910,290]],"CacheSeal"],
	["2-1",Vector2(3010,432),[[3184,352]],"HatWorkshop"],
	["2-1",Vector2(3750,416),[[3842,312]],"WatchPay"],
	["2-1",Vector2(4100,480),[[4328,276]],"CargoPay","CargoLift"],
	["2-2",Vector2(300,432),[[534,356]],"SurveyPay"],
	["2-2",Vector2(1390,448),[[1532,348]],"SwitchPay"],
	["2-2",Vector2(2660,432),[[2860,352],[2930,352],[3024,248],[3216,288]],"GalleryPay"],
	["2-2",Vector2(5040,432),[[5192,352]],"KilnPay"],
	["2-2",Vector2(7270,384),[[7335,384],[7440,304],[7560,304]],"VeinPay"],
	["2-2",Vector2(8000,432),[[8202,336]],"LowerPay"],
	["2-2",Vector2(8260,336),[[8500,264]],"VaultSeal","VeinLift"],
	["2-3",Vector2(240,432),[[364,352]],"ShiftPay"],
	["2-3",Vector2(710,400),[[852,320]],"ForemanPay"],
	["2-3",Vector2(1860,432),[[1994,352]],"ForgeCache"]
]

func vertical_lift(deck) -> void:
	var a=game.world.player
	var launched:=false
	var jump_ticks:=0
	var boarded:=false
	var drop:bool=a.position.y<370
	for i in 900:
		if riding(a,deck): boarded=true;break
		if not launched and a.is_on_floor() and deck.position.y>375 and deck.elapsed>deck.period*0.8: launched=true
		if launched: jump_ticks+=1
		drive(1 if launched and a.position.x<deck.position.x-3 else 0,launched and not drop and jump_ticks<52)
		await next_frame()
		if pilot_failed: return
	check(boarded,"boarded vertical lift "+str(deck.name))
	if not boarded: return
	for i in 400:
		if deck.position.y<=286: break
		drive(signi(roundi(deck.position.x-a.position.x)) if absf(deck.position.x-a.position.x)>5 else 0,false)
		await next_frame()
	stop_keys()

func hop(x:float,y:float) -> void:
	var a=game.world.player
	stop_keys()
	for i in 110:
		if a.is_on_floor() and absf(a.velocity.x)<1: break
		await next_frame()
	var continuous:=true
	for dx in range(0,int(absf(x-a.position.x))+1,12):
		var at:=Vector2(a.position.x+signf(x-a.position.x)*dx,y-1)
		if a.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(at,at+Vector2(0,5),1)).is_empty(): continuous=false
	if absf(a.position.y-y)<2 and continuous:
		await approach(x)
		await settle(60)
		return
	# Watch the guard before entering its deck. The longer, stationary turns make
	# a fixed launch delay unsafe; wait for a visibly clear landing, as a player can.
	var landing_guard
	for foe in game.world.get_children():
		if foe.get("state")!=null and not foe.is_queued_for_deletion() and absf(foe.position.y-y)<4 and absf(foe.position.x-x)<160:
			landing_guard=foe
			break
	if is_instance_valid(landing_guard) and landing_guard.state==landing_guard.State.PATROL:
		var way:=signi(roundi(x-a.position.x))
		for i in 420:
			if landing_guard.direction==way and (landing_guard.position.x-landing_guard.origin)*way>landing_guard.patrol_width*0.2 and landing_guard.patrol_turn<=0: break
			drive(0,false)
			await next_frame()
	var airborne:=false
	for i in 150:
		var axis:=signi(roundi(x-a.position.x)) if absf(x-a.position.x)>2 else 0
		drive(axis,i<55)
		await next_frame()
		if not a.is_on_floor(): airborne=true
		if pilot_failed or (airborne and a.is_on_floor()): break
	stop_keys()
	await settle(6)
	check(absf(a.position.y-y)<3,"branch landed on intended tier "+str(Vector2(x,y))+" actual="+str(a.position))
	if absf(a.position.y-y)<3:
		await wait_and_stomp()
		await approach(x)

func centre(x:float) -> void:
	var a=game.world.player
	for i in 160:
		var distance:float=x-a.position.x
		if absf(distance)<1.5 and absf(a.velocity.x)<1: break
		var axis:=signi(roundi(distance)) if absf(distance)>1 and absf(a.velocity.x)<absf(distance)*12 else 0
		drive(axis,false)
		await next_frame()
	stop_keys()

func wait_and_stomp() -> void:
	var a=game.world.player
	var foe
	for n in game.world.get_children():
		if n.get("state")!=null and not n.is_queued_for_deletion() and absf(n.position.y-a.position.y)<80 and absf(n.position.x-a.position.x)<160:
			foe=n
			break
	if not is_instance_valid(foe): return
	var held:=0
	var airborne:=false
	for i in 650:
		if not is_instance_valid(foe) or foe.state!=foe.State.PATROL: break
		var gap:float=foe.position.x-a.position.x
		var toward:bool=gap*foe.direction<0
		if a.is_on_floor() and airborne:
			drive(0,false)
			held=0
			airborne=false
			await next_frame()
			continue
		if held<=0 and a.is_on_floor() and toward and absf(gap)<68: held=48
		var axis:=signi(roundi(gap)) if held>0 and absf(gap)>6 else 0
		drive(axis,held>0)
		held-=1
		await next_frame()
		if not a.is_on_floor(): airborne=true
		if pilot_failed: return
	stop_keys()
	if is_instance_valid(foe) and foe.state==foe.State.HIDDEN:
		# Get to the far side during the rebound and send the hat behind us.
		# A forward kick can bounce from the next raised block into a waiting player.
		var ray:=PhysicsRayQueryParameters2D.create(foe.position+Vector2(40,-2),foe.position+Vector2(40,8),1)
		var side:=1 if not a.get_world_2d().direct_space_state.intersect_ray(ray).is_empty() else -1
		for i in 90:
			if (a.position.x-foe.position.x)*side>37: break
			drive(side,false)
			await next_frame()
		await settle(45)
		for i in 80:
			if not is_instance_valid(foe) or foe.state!=foe.State.HIDDEN: break
			drive(signi(roundi(foe.position.x-a.position.x)),false)
			await next_frame()
		for i in 18:
			drive(side,false)
			await next_frame()
		await settle(6)
	stop_keys()

func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/durotar-revision/branches-%d"%OS.get_process_id())
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	var args:=OS.get_cmdline_user_args()
	var hero:="ogre" if "--ogre" in args else "human"
	for form in 3:
		if "--big" in args and form!=1: continue
		if "--small" in args and form!=0: continue
		if "--magic" in args and form!=2: continue
		for route in cases:
			var selected_case:=""
			for arg in args:
				if arg.begins_with("--case="): selected_case=arg.trim_prefix("--case=")
			if not selected_case.is_empty() and route[3]!=selected_case: continue
			await test_level(route[0])
			state.p.hero=hero
			start_stage(route[0])
			expected_form=form
			game.world.player.apply_form(form)
			await place_player(route[1].x,route[1].y-1)
			print("BRANCH ",route[0]," ",route[3]," ",hero," form=",form)
			if route.size()>4: await vertical_lift(game.world.get_node(route[4]))
			for step in route[2]:
				await hop(step[0],step[1])
				if failed: break
			if failed: quit(1);return
			var chest=game.world.get_node(route[3])
			await wait_and_stomp()
			await approach(chest.position.x)
			await settle(10)
			await centre(chest.position.x)
			await jump_here()
			print("CHEST ",chest.reward_id," spent=",chest.spent," player=",game.world.player.position," form=",game.world.player.form," hearts=",state.p.hearts)
			check(state.claimed(route[0]+"/"+route[3]) and game.world.player.form==form and state.p.hearts==3,"branch chest reached and opened with preserved form")
			if failed: quit(1);return
	print("ALL BRANCHES PASS ",hero)
	quit(0)
