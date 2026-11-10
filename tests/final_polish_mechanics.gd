extends "res://tests/s02_forest.gd"
var evidence:={}
var cast_ticks:Array=[]
var sound_ticks:Array=[]
var fps_tag:="60"
var captures:=false
var capture_dir:=""

func _initialize() -> void:
	root.unfocusable=true
	physics_frame.connect(func():
		if is_instance_valid(game) and game.page=="pause": game.show_page("play"))
	run.call_deferred()

func capture(name:String) -> void:
	if not captures: return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir+name+".png")

func fresh(id:String) -> void:
	await test_level(id)
	await ticks(4)

func move_key(code:Key,count:int) -> void:
	press(code,true)
	await ticks(count)
	press(code,false)
	await ticks(2)

func arena_checks() -> void:
	for id in ["1-3","2-3","3-3"]:
		for form in 3:
			await fresh(id)
			var w=game.world; var a=w.player; var b=w.boss; var lock=w.arena
			b.set_physics_process(false)
			a.position=Vector2(lock.left-35,480)
			var floor_hit:Dictionary=w.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(a.position.x,250),Vector2(a.position.x,520),1))
			if not floor_hit.is_empty(): a.position.y=floor_hit.position.y
			a.apply_form(form)
			await ticks(4)
			check(not lock.active,"arena open before complete entry %s/%d"%[id,form])
			await move_key(KEY_D,38)
			check(lock.active and b.in_arena(),"walking inside starts and locks fight %s/%d"%[id,form])
			await capture("arena-locked-"+id+"-"+str(form))
			press(KEY_SPACE,true)
			await move_key(KEY_A,100)
			press(KEY_SPACE,false)
			check(a.position.x>=lock.left+20,"cannot jump back through entrance %s/%d"%[id,form])
			a.position=Vector2(lock.right-65,480)
			a.velocity=Vector2.ZERO
			await ticks(3)
			press(KEY_SPACE,true)
			await move_key(KEY_D,100)
			press(KEY_SPACE,false)
			check(a.position.x<=lock.right-20,"cannot bypass exit %s/%d"%[id,form])
			check(lock.active and b.in_arena(),"boundary does not end aggro "+id)
			var hp:int=b.hp
			var hearts:int=state.p.hearts
			a.damage(false,true)
			await ticks(80)
			check(state.p.hearts==hearts-1 and not lock.active and b.hp==hp,"death reopens entry and preserves HP "+id)
			a.position=Vector2(lock.left+60,480)
			await ticks(3)
			check(lock.active,"retry locks again "+id)
			var score:int=state.p.score
			b.take_damage(b.hp)
			await ticks(3)
			check(lock.released and not lock.active and w.get_node("Gate/Hitbox").disabled and lock.entrance.get_node("Hitbox").disabled,"victory opens both physical gates "+id)
			b.take_damage(99)
			check(state.p.score==score+10000,"boss award is exactly once "+id)
			await ticks(120)
			await capture("arena-death-"+id+"-"+str(form))
			check(b.hp==0,"corpse persists without reset "+id)
			if id!="3-3":
				var art=b.get_node("Skin").art
				check(art.position.y>=0 and art.sprite.material!=null,"corpse grounded and clipped at floor "+id)

func magic_checks() -> void:
	for id in ["1-3","2-3","3-3"]:
		for near in [true,false]:
			await fresh(id)
			var a=game.world.player; var b=game.world.boss
			b.set_physics_process(false)
			b.mode=b.Mode.OPEN
			b.get_node("Hitbox").disabled=false
			if id=="1-3": b.clear_lane=true
			a.apply_form(2)
			a.position=b.position-Vector2(40 if near else 150,0)
			a.facing=1
			a.protection=20
			await ticks(3)
			a.visual_event.connect(func(event):
				if event=="shoot": cast_ticks.append(Engine.get_physics_frames()))
			cast_ticks.clear(); sound_ticks.clear()
			var hp:int=b.hp
			for i in 120:
				press(KEY_E,true)
				await ticks(1)
				press(KEY_E,false)
				await ticks(1)
			check(cast_ticks.size()>1 and cast_ticks.size()<=7,"rapid input respects 0.60s cooldown "+id+str(near))
			for i in range(1,cast_ticks.size()): check(cast_ticks[i]-cast_ticks[i-1]>=36,"accepted shot spacing "+id)
			check(sound_ticks.size()<=cast_ticks.size() and b.hp>=hp-2,"no extra shot sound/damage "+id)
			evidence[id+"-magic-"+str(near)]={"accepted_ticks":cast_ticks.duplicate(),"sounds":sound_ticks.size(),"hp_before":hp,"hp_after":b.hp}
			await ticks(180)
			cast_ticks.clear()
			press(KEY_E,true)
			await ticks(120)
			press(KEY_E,false)
			check(cast_ticks.size()==1,"holding E does not autorepeat "+id)

func surface_attack_checks() -> void:
	await fresh("2-3")
	var a=game.world.player; var b=game.world.boss
	b.set_physics_process(false)
	a.position=Vector2(2964,408)
	await ticks(4)
	b.prepare(a)
	var mark=get_nodes_in_group("mine_strikes")[0]
	check(absf(mark.position.y-408)<1,"fissure anchors on raised stone, not hidden below it")
	await capture("foreman-plinth-warning")
	await ticks(60)
	check(state.p.hearts==2,"camping on stone is hit in phase one")
	await fresh("2-3")
	a=game.world.player; b=game.world.boss
	b.set_physics_process(false)
	a.position=Vector2(2964,408)
	await ticks(4)
	b.prepare(a)
	await ticks(35)
	await move_key(KEY_SPACE,45)
	check(state.p.hearts==3,"timed jump honestly avoids raised fissure")
	for side in [-1,1]:
		for hp in [12,8,4]:
			await fresh("3-3")
			a=game.world.player; b=game.world.boss
			b.set_physics_process(false)
			b.hp=hp
			a.position=Vector2(b.home.x+side*250,480)
			await ticks(4)
			b.prepare(a)
			check(b.phase()==[12,8,4].find(hp)+1 and b.position.x==b.home.x+side*156,"12HP phases and separate hammer on both sides")
			b.clear_attacks()
			b.mode=b.Mode.OPEN
			b.get_node("Hitbox").disabled=false
			b.clock=99
			b.set_physics_process(true)
			a.position=b.position-Vector2(0,116)
			a.velocity=Vector2(0,40)
			await ticks(25)
			check(b.hp==hp-3,"real descending capsule hits hammer for three HP")
			await capture("hammer-side-%d-hp-%d"%[side,hp])

func patrol_checks() -> void:
	var rows:Array=[]
	for id in ["1-1","1-2","2-1","2-2","2-3","3-1","3-2","3-3"]:
		await fresh(id)
		var w=game.world
		for n in w.get_children():
			if n.get("mode") is String and n.mode=="ambush":
				w.player.position=n.position-Vector2(160,0)
				w.player.protection=40
				await ticks(90)
		w.player.set_physics_process(false)
		w.player.position=Vector2(-100,-200)
		var foes:Array=[]
		for n in w.get_children():
			if n.has_method("defeat") and not n.is_queued_for_deletion(): foes.append({"node":n,"min":INF,"max":-INF,"turns":0,"last":n.direction})
		await ticks(120)
		for i in 720:
			await ticks(1)
			for f in foes:
				if not is_instance_valid(f.node): continue
				f.min=minf(f.min,f.node.position.x); f.max=maxf(f.max,f.node.position.x)
				if f.last!=f.node.direction: f.turns+=1
				f.last=f.node.direction
		for f in foes:
			if not is_instance_valid(f.node): check(false,"enemy fell during patrol "+id);continue
			var row:={"level":id,"id":f.node.reward_id,"span":f.max-f.min,"turns_12s":f.turns}
			rows.append(row)
			check(row.span>=45 and row.turns_12s<=12,"stable patrol "+str(row))
			if row.id=="3-2/DangerGuard": check(row.span>=100 and row.turns_12s<=7,"pipe imp has a meaningful route")
	evidence.patrols=rows

func ranged_checks() -> void:
	await fresh("3-1")
	var w=game.world; var a=w.player; var enemy=w.get_node("ForgeCaster"); var attack=enemy.attack_controller
	a.position=enemy.position-Vector2(230,0)
	a.get_node("Camera").reset_smoothing()
	a.protection=40
	await ticks(8)
	attack.cooldown=0
	for i in 30:
		await ticks(1)
		if attack.mode==attack.Mode.WINDUP: break
	check(attack.mode==attack.Mode.WINDUP,"visible imp begins readable windup")
	var started:=Engine.get_physics_frames()
	await capture("imp-windup")
	while attack.shots_fired==0 and Engine.get_physics_frames()-started<70: await ticks(1)
	check(attack.shots_fired==1 and Engine.get_physics_frames()-started>=36,"imp waits approximately 0.65 seconds")
	var shots=get_nodes_in_group("enemy_projectiles")
	check(shots.size()==1,"one windup creates one projectile")
	if shots.size():
		var direction:Vector2=shots[0].direction
		a.position.y-=70
		await ticks(3)
		check(shots[0].direction==direction,"fireball does not home")
		await capture("imp-fireball")
	await ticks(100)
	check(attack.shots_fired==1,"imp cannot spam during reload")
	a.position=enemy.position-Vector2(50,0)
	attack.mode=attack.Mode.PATROL; attack.cooldown=0
	await ticks(10)
	check(attack.mode==attack.Mode.PATROL,"no shot appears inside nearby player")
	a.position=Vector2(96,480)
	await ticks(10)
	check(attack.mode==attack.Mode.PATROL,"off-screen imp does not attack")
	a.position=enemy.position-Vector2(220,0)
	var wall=preload("res://scenes/objects/test_platform.tscn").instantiate()
	wall.position=enemy.position-Vector2(100,120);wall.size=Vector2(24,120)
	w.add_child(wall)
	await ticks(6)
	check(not attack.can_attack(),"solid obstruction blocks ranged sight")
	var id:String=enemy.reward_id
	enemy.magic_hit()
	await ticks(2)
	check(state.claimed(id) and not is_instance_valid(enemy),"ranged imp retains normal defeat and reward")

func run() -> void:
	captures="--capture" in OS.get_cmdline_user_args()
	if "--640" in OS.get_cmdline_user_args(): root.size=Vector2i(640,360)
	if "--30" in OS.get_cmdline_user_args(): fps_tag="30"
	capture_dir="res://reports/evidence/final-polish/mechanics-"+fps_tag+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
	state=root.get_node("Campaign")
	state.start_sandbox()
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	root.get_node("SFX").played.connect(func(id,_details):
		if id=="magic_cast": sound_ticks.append(Engine.get_physics_frames()))
	await arena_checks()
	await magic_checks()
	await surface_attack_checks()
	await patrol_checks()
	await ranged_checks()
	var file:=FileAccess.open(capture_dir+"results.json",FileAccess.WRITE)
	evidence.success=not failed
	file.store_string(JSON.stringify(evidence,"  "))
	game.clear_world()
	await process_frame
	await process_frame
	print("CAMPAIGN POLISH MECHANICS ","FAIL" if failed else "PASS")
	root.get_node("MusicManager").stop_all()
	OS.delay_msec(150)
	quit(1 if failed else 0)
