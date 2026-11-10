extends "res://tests/s02_form_reachability.gd"

const OUTPUT4 := "res://reports/evidence/final-polish/durotar/"
const TMP := "res://reports/temp/final-polish/"
var keys := {}
var frame_no := 0
var frames := 0
var clip4 := ""
var events := []
var movie := false
var level_id := ""
var entering_form := 0
var pilot_failed := false
var visited := {}
var combat_start := 0
var alternative := false
var expected_form := 0

func key(code: Key,on: bool) -> void:
	if keys.get(code,false)==on and (not on or Input.is_physical_key_pressed(code)): return
	keys[code]=on
	press(code,on)
	events.append([frame_no,code,on])

func stop_keys() -> void:
	for code: Key in [KEY_D,KEY_A,KEY_SPACE,KEY_E,KEY_S]: key(code,false)

func start_stage(n: String) -> void:
	level_id=n
	frame_no=0
	keys.clear()
	visited.clear()
	events=[]
	frames=0
	pilot_failed=false
	clip4=n+"-"+str(entering_form)
	if movie:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP+clip4))

func next_frame() -> void:
	await physics_frame
	# A background capture can lose desktop focus while Edge opens. Resume the test world.
	if game.page=="pause": game.show_page("play")
	frame_no+=1
	if movie and frame_no%6==0:
		await RenderingServer.frame_post_draw
		var img:=root.get_texture().get_image()
		img.resize(640,360,Image.INTERPOLATE_BILINEAR)
		img.save_png(TMP+clip4+"/%05d.png"%frames)
		frames+=1
	if (game.page=="offer" or game.world.player.recovering>0 or state.p.hearts<1 or game.world.player.form<expected_form) and not pilot_failed:
		check(false,"route damage at "+str(game.world.player.position)+" in "+level_id+" frame="+str(frame_no))
		pilot_failed=true

func drive(axis: int,jump: bool,shoot:=false) -> void:
	key(KEY_A,axis<0)
	key(KEY_D,axis>0)
	key(KEY_SPACE,jump)
	key(KEY_E,shoot)

func wall_requires_jump(a) -> bool:
	for i in a.get_slide_collision_count():
		var contact=a.get_slide_collision(i)
		if absf(contact.get_normal().x)<0.5: continue
		var box=contact.get_collider().get_node_or_null("Hitbox")
		# A tall head brushing a suspended deck is cleared by falling off the
		# preceding step. Jumping there would unintentionally choose the upper path.
		if box and box.global_position.y+box.shape.get_rect().end.y>=a.position.y-3: return true
	return false

func approach(dest: float, launch: Array=[],avoid_enemies:=true) -> void:
	var a=game.world.player
	var held:=0
	var jumped_airborne:=false
	for tick in 3600:
		if pilot_failed or game.page!="play" or absf(a.position.x-dest)<2.8: break
		var axis:=1 if dest>a.position.x else -1
		if "--trace" in OS.get_cmdline_user_args() and tick%4==0: print("TRACE ",level_id," ",a.position," v=",a.velocity," floor=",a.is_on_floor()," hold=",held)
		var leap:bool=wall_requires_jump(a)
		var shoot:=false
		for x: float in launch:
			if axis==1 and a.position.x>=x and a.position.x<x+31: leap=true
			if axis==1 and a.is_on_floor() and x>=a.position.x-12 and x<a.position.x+120:
				var tip:Vector2=a.global_position+Vector2(26,-3)
				var edge:=PhysicsRayQueryParameters2D.create(tip,tip+Vector2(0,12),1)
				if a.get_world_2d().direct_space_state.intersect_ray(edge).is_empty(): leap=true
		if avoid_enemies:
			var head:Vector2=a.global_position-Vector2(0,a.height+1)
			var overhead:Dictionary=a.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(head,head-Vector2(0,150),1))
			var jump_distance:=45.0 if not overhead.is_empty() and head.y-overhead.position.y<80 else 80.0
			for foe in game.world.get_children():
				if not foe.has_method("defeat") or foe.is_queued_for_deletion(): continue
				var gap:float=(foe.position.x-a.position.x)*axis
				if "--trace" in OS.get_cmdline_user_args() and absf(gap)<120 and tick%4==0: print("NEAR ",foe.name," ",foe.position," state=",foe.get("state")," dir=",foe.get("direction")," v=",foe.velocity)
				if a.form==2 and gap>28 and gap<220 and absf(foe.position.y-a.position.y)<18 and a.is_on_floor(): shoot=tick%22==0
				var timing:float=maxf(jump_distance,65.0) if foe.get("direction")!=axis else jump_distance
				if gap>0 and gap<timing and absf(foe.position.y-a.position.y)<36: leap=true
		if not a.is_on_floor(): jumped_airborne=true
		if leap and a.is_on_floor() and keys.get(KEY_SPACE,false) and jumped_airborne:
			# A rebound/head bump can land before the previous hold finishes.
			# Release then press again, exactly as a human must do for a fresh jump.
			drive(axis,false)
			held=0
			jumped_airborne=false
			await next_frame()
			continue
		if held<=0 and leap and a.is_on_floor():
			held=46
			jumped_airborne=false
		drive(axis,held>0,shoot)
		held-=1
		await next_frame()
	stop_keys()
	if not pilot_failed and game.page=="play" and absf(a.position.x-dest)>6:
		check(false,"route stuck toward %s at %s in %s"%( [dest,a.position,level_id]))
		pilot_failed=true

func settle(count:=65) -> void:
	stop_keys()
	for i in count:
		await next_frame()
		if pilot_failed: return

func jump_here() -> void:
	key(KEY_SPACE,true)
	for i in 34: await next_frame()
	await settle(47)

func crossing(deck,bank: float) -> void:
	var a=game.world.player
	var w=game.world
	var on_deck:=false
	var launched:=false
	var board_ticks:=0
	for i in 720:
		if pilot_failed: return
		if riding(a,deck):
			on_deck=true
			break
		var gap:float=deck.position.x-a.position.x
		# Board from the marked bank when the deck is alongside it.
		if not launched and a.is_on_floor() and deck.elapsed>deck.period*0.65 and gap<132:
			launched=true
		if launched: board_ticks+=1
		drive(1 if launched and gap>4 else 0,launched and board_ticks<44)
		await next_frame()
	check(on_deck,"boarded actual "+str(deck.name))
	if not on_deck:
		pilot_failed=true
		return
	visited[deck.name]=true
	for i in 600:
		if deck.position.x>=bank-91: break
		drive(signi(roundi(deck.position.x-a.position.x)) if absf(deck.position.x-a.position.x)>8 else 0,false)
		await next_frame()
	var jump_ticks:=0
	while a.position.x<bank+30 and jump_ticks<90:
		drive(1,jump_ticks<42)
		jump_ticks+=1
		await next_frame()
	stop_keys()
	check(a.position.x>=bank+30 and a.position.y<500 and w.player==a,"disembarked "+str(deck.name))

func pipe_down() -> void:
	await settle()
	key(KEY_S,true)
	for i in 4: await next_frame()
	key(KEY_S,false)

func stage_one() -> void:
	if entering_form==1:
		await approach(376)
		await settle(8)
		await jump_here()
		await approach(450)
		check(game.world.player.form==1 and state.claimed("2-1/Supplies/item"),"actual growth on trail")
		expected_form=1
	await approach(5303,[770,1500,2780,3570,4450])

func stage_two() -> void:
	var w=game.world
	await approach(680)
	await crossing(w.get_node("WestLift"),1050)
	await approach(1830)
	await crossing(w.get_node("EastLift"),2200)
	if entering_form!=0 or alternative:
		await approach(w.get_node("Entry").position.x)
		await pipe_down()
		print("ENTRY ",w.player.position," form=",w.player.form," room=",w.underground)
		check(w.underground and w.player.form==entering_form,"entered optional mine")
		await approach(8760,[7745])
		await pipe_down()
		check(not w.underground and w.player.form==entering_form,"returned from mine")
	await approach(3630,[3435])
	await crossing(w.get_node("DeepLift"),4020)
	await approach(w.get_node("Vent").position.x)
	await settle(55)
	await approach(5403,[4180,4560])
	check(visited.size()==3 and w.get_node("Vent").triggered,"three moving decks and one-shot vent")

func fight(ranged: bool) -> void:
	var w=game.world
	var a=w.player
	var b=w.boss
	var phases:={}
	var held:=0
	var last_hp:=9
	var evade:=0.0
	var old_step:=-1
	combat_start=frame_no
	var score_before:int=state.p.score
	var coins_before:int=state.p.coins
	var miners_before:int=state.p.enemies
	for i in 6500:
		if pilot_failed or b.hp==0: break
		phases[b.phase()]=true
		var x:float=a.position.x
		var dx:float=b.position.x-x
		var side:float=1 if dx<0 else -1
		var target:float=b.position.x+side*(132 if ranged else 105)
		var leap:bool=wall_requires_jump(a)
		if b.step!=old_step and b.mode==b.Mode.WARN:
			old_step=b.step
			var mark_x:float=b.marks[0]
			# Pick a clear lane on the near side, between marks in the final phase.
			var far_side:float=signf(mark_x-b.position.x)
			if far_side==0: far_side=-1
			evade=mark_x+far_side*78
			if evade<b.arena_start+25 or evade>w.finish_x-120:
				evade=mark_x-far_side*64
		if b.mode in [b.Mode.WARN,b.Mode.STRIKE]:
			target=evade
			if b.attack_phase==1:
				target=b.position.x+side*104
				if b.mode==b.Mode.WARN and b.clock<0.35: leap=true
		if b.mode==b.Mode.OPEN:
			if ranged:
				target=x if absf(dx)<255 and absf(dx)>72 and a.position.y>b.position.y-12 else b.position.x+side*105
			else:
				target=b.position.x
				if absf(dx)<144: leap=true
		if held<=0 and leap and a.is_on_floor(): held=46
		var axis:=signi(roundi(target-x)) if absf(target-x)>3 else 0
		var shoot:bool=ranged and b.mode==b.Mode.OPEN and a.is_on_floor() and a.position.y>b.position.y-12 and i%10==1
		if shoot: axis=signi(roundi(dx))
		if "--trace" in OS.get_cmdline_user_args() and shoot: print("FIRE ",a.position," boss=",b.position," hits=",b.hits," clock=",b.clock," face=",a.facing," bolts=",get_nodes_in_group("bolts").size())
		drive(axis,held>0,shoot)
		held-=1
		await next_frame()
		if b.hp!=last_hp:
			check(last_hp-b.hp==(1 if ranged else 3),"normal hit "+str(last_hp)+" -> "+str(b.hp))
			last_hp=b.hp
	if b.hp>0: print("COMBAT END ",a.position," form=",a.form," boss=",b.position," hp=",b.hp," step=",b.step," mode=",b.mode)
	var other_points:int=10*(state.p.coins-coins_before)+100*maxi(0,state.p.enemies-miners_before-1)
	print("FIGHT phases=",phases," score delta=",state.p.score-score_before," incidental=",other_points)
	check(b.hp==0 and phases.size()==3 and state.claimed(b.reward_id) and state.p.score-score_before-other_points==10000,"full fight across three phases; unique award")
	stop_keys()

func stage_three() -> void:
	if entering_form==2:
		# Every final ranged fight claims the actual rune at the camp.
		await approach(2850,[490,1060,2150])
		key(KEY_SPACE,true)
		for i in 30: await next_frame()
		key(KEY_SPACE,false)
		check(state.claimed("2-3/LastRune") and game.world.player.form==2,"actual arena rune")
		expected_form=2
	await approach(3070,[490,1060,2150])
	await fight(entering_form==2)
	if not pilot_failed: await approach(4023)

func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path(TMP+"run-%d"%OS.get_process_id())
	state.store.first_level="2-1"
	state.p={}
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	var args:=OS.get_cmdline_user_args()
	var hero:="ogre" if "--ogre" in args else "human"
	movie="--movie" in args
	alternative="--alternative" in args
	var arena_only:="--arena-film" in args
	var last_only:=arena_only or "--only-2-3" in args
	if last_only: state.store.first_level="2-3"
	for form in 3:
		if "--small" in args and form!=0: continue
		if "--magic" in args and form!=2: continue
		if "--big" in args and form!=1: continue
		entering_form=form
		state.new_game(hero)
		state.p.hearts=1
		game.start_level()
		for n: String in (["2-3"] if last_only else ["2-1","2-2","2-3"]):
			start_stage(n)
			await ticks(6)
			var a=game.world.player
			check(a.form==0 and state.p.hearts==1,"stage starts small on a single remaining heart")
			if not (form==1 and n=="2-1") and not (form==2 and n=="2-3"): a.apply_form(form)
			expected_form=a.form
			a.form_changed.connect(func(): print("FORM ",n," ",a.position," -> ",a.form))
			audit_passages(n,a)
			if form==1 and n=="2-1":
				# Probe the grown capsule as well as walking it after the real pickup.
				a.apply_form(1)
				audit_passages(n,a)
				a.apply_form(0)
			if arena_only: await place_player(game.world.checkpoint_x)
			match n:
				"2-1": await stage_one()
				"2-2": await stage_two()
				"2-3": await stage_three()
			if not pilot_failed: await settle(4)
			check(game.page=="result" and a.form==form and state.p.hearts==1,"FINISH "+hero+" "+n+" form="+str(form))
			if game.page!="result" or failed:
				print("STOP ",n," ",a.position," form=",a.form," hearts=",state.p.hearts," frame=",frame_no)
				quit(1)
				return
			check(state.store.valid(state.store.read_profile()),"valid saved result "+n)
			var dir:=OUTPUT4+("30/" if "--30" in args else "60/")
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
			var trace:=FileAccess.open(dir+clip4+"-"+hero+".json",FileAccess.WRITE)
			trace.store_string(JSON.stringify({"events":events,"frames":frames,"combat":combat_start,"ticks":frame_no}))
			game.next_map()
			game.start_level()
		check(game.page=="play" and state.p.level=="3-1" and state.p.results.size()==(1 if last_only else 3),"third-world marker and saved results")
		game.main_menu()
	game.clear_world()
	await process_frame
	await process_frame
	root.get_node("SFX").new_world(false)
	root.get_node("MusicManager").stop_all()
	OS.delay_msec(120)
	quit(1 if failed else 0)

func _initialize() -> void:
	root.unfocusable=true
	super._initialize()
