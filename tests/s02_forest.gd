extends "res://tests/s01_campaign.gd"

const OUTPUT := "res://reports/evidence/s02/"
var footage := false
var clip := ""
var clip_index := 0
var clip_lengths := {}
var last_capture := -100
var max_form := 0

func frame_capture() -> void:
	if footage and not clip.is_empty() and Engine.get_physics_frames()-last_capture>=5:
		last_capture = Engine.get_physics_frames()
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.resize(640,360,Image.INTERPOLATE_BILINEAR)
		image.save_png("res://reports/temp/s02/%s/%04d.png"%[clip,clip_index])
		clip_index += 1
		clip_lengths[clip]=clip_index

func record(name: String) -> void:
	clip = name
	clip_index = 0
	last_capture = -100
	if footage:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/temp/s02/"+name))

func ticks(count: int) -> void:
	for i in count:
		await physics_frame
		await frame_capture()

func photo(id: String) -> void:
	if shots:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUTPUT+id+".png")==OK,"frame "+id)

func run() -> void:
	shots = "--screenshots" in OS.get_cmdline_user_args()
	footage = "--clips" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var work := ProjectSettings.globalize_path("res://reports/temp/s02")
	DirAccess.make_dir_recursive_absolute(work)
	state = root.get_node("Campaign")
	state.store.prefix = work.path_join("test-%d"%OS.get_process_id()+"-"+str(Time.get_ticks_usec()))
	state.p = {}
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game = current_scene
	var hero := "ogre" if "--ogre" in OS.get_cmdline_user_args() else "human"
	state.new_game(hero)
	game.start_level()
	await ticks(6)
	await chest_and_stairs()
	await local_water_tests()
	await local_boss_tests()
	await remaining_chests()
	await migration()
	state.new_game(hero)
	game.start_level()
	await ticks(8)
	check(state.p.hearts==3 and state.p.wallet==0,"continuous campaign starts fresh "+hero)
	if hero=="ogre":
		game.world.player.damage(false,true)
		await ticks(70)
		check(state.p.hearts==2,"ogre begins route with two remaining hearts")
	for level: String in ["1-1","1-2","1-3"]:
		if state.p.level!=level or game.page!="play":
			check(false,"campaign cannot enter "+level)
			break
		var balance: int = state.p.wallet
		var hearts: int = state.p.hearts
		await atlas(level)
		await route(level)
		if game.page!="result":
			break
		var result: Dictionary = state.p.results[level]
		check(result.total==game.world.total_coins and result.score>=result.coins*10,"result belongs to "+level)
		check(state.p.wallet==balance+result.coins and state.p.hearts==hearts,"no rollback or refill at "+level)
		if level=="1-3":
			await photo("result")
		game.next_map()
		if level=="1-3":
			await photo("map")
		game.start_level()
		await ticks(4)
	check(game.page=="play" and state.p.level=="2-1" and state.p.results.size()==3,"three unique results unlock 2-1")
	check(max_form==0,"entire main route in small form")
	if footage:
		var index_file:=FileAccess.open("res://reports/temp/s02/clips.json",FileAccess.WRITE)
		index_file.store_string(JSON.stringify(clip_lengths))
	quit(1 if failed else 0)

func atlas(level: String) -> void:
	if not shots:
		return
	# Photograph adjacent strips of the live world with one scale per map.
	var w=game.world
	var camera: Camera2D=w.player.get_node("Camera")
	var count:=ceili((float(w.finish_x)+128)/1920)
	var rows:=count+int(w.cave_left>0)
	var sheet:=Image.create(960,rows*274,false,Image.FORMAT_RGB8)
	game.get_node("Interface").hide()
	paused=true
	camera.enabled=false
	for i in rows:
		var begin: float=i*1920 if i<count else w.cave_left
		root.canvas_transform=Transform2D(Vector2(0.5,0),Vector2(0,0.5),Vector2(-begin*0.5,0))
		await RenderingServer.frame_post_draw
		var part:=root.get_texture().get_image()
		part.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(part,Rect2i(0,0,960,270),Vector2i(0,i*274))
	check(sheet.save_png(OUTPUT+"atlas-"+level+".png")==OK,"world overview "+level)
	camera.enabled=true
	camera.reset_smoothing()
	game.get_node("Interface").show()
	paused=false

func chest_and_stairs() -> void:
	await place_player(2608)
	record("chest")
	press(KEY_SPACE,true)
	await ticks(25)
	press(KEY_SPACE,false)
	await ticks(42)
	check(state.claimed("1-1/block_2608") and not state.claimed("1-1/block_2608/item"),"chest dispenses pending item")
	await photo("chest")
	press(KEY_D,true)
	await ticks(18)
	press(KEY_D,false)
	await ticks(6)
	check(game.world.player.form==1 and state.claimed("1-1/block_2608/item"),"opened original chest with Space, collected with D at ground level")
	clip = ""
	var actor = game.world.player
	await place_player(2782)
	record("stairs")
	press(KEY_SPACE,true)
	await ticks(10)
	press(KEY_D,true)
	await ticks(19)
	press(KEY_D,false)
	await ticks(32)
	press(KEY_SPACE,false)
	check(actor.is_on_floor() and absf(actor.position.y-372)<1,"intact empty block supports feet")
	await photo("stairs")
	await ticks(3)
	await jump_right_to(2932)
	check(absf(actor.position.y-288)<2,"second breakable stair reached by jumping")
	await jump_right_to(3050)
	check(absf(actor.position.y-207)<2,"upper optional coin shelf reached without teleport")
	clip = ""
	await place_player(2832)
	record("break")
	var score: int = state.p.score
	await hit_block(2832)
	check(not game.world.has_node("Block2832") and state.p.score==score,"empty step breaks without points")
	press(KEY_SPACE,true)
	await ticks(62)
	press(KEY_SPACE,false)
	check(actor.position.y>440 and actor.is_on_floor(),"same jump no longer lands on missing stair")
	await photo("broken")
	clip = ""
	actor.damage(false,true)
	await ticks(70)
	check(not game.world.has_node("Block2832"),"ordinary death keeps broken structure")
	actor.apply_form(2)
	await hit_block(3840)
	check(state.claimed("1-1/block_3712"),"magic form breaks scoring block")
	# Leave all optional supports broken before a keyboard-only traversal.
	for block in game.world.get_children():
		if block.get("kind") in ["empty","fragile"]:
			block.hit_below(actor)
	actor.apply_form(0)
	await place_player(96)
	await route("1-1",false)
	check(game.page=="result","finish reachable after all optional supports are destroyed")

func jump_right_to(target: float) -> void:
	press(KEY_D,true)
	press(KEY_SPACE,true)
	for i in 55:
		await ticks(1)
		if game.world.player.position.x >= target-4:
			break
	press(KEY_D,false)
	await ticks(45)
	press(KEY_SPACE,false)
	await ticks(3)

func test_level(level: String) -> void:
	state.new_game("human")
	state.p.level = level
	game.start_level()
	await ticks(6)

func local_water_tests() -> void:
	await test_level("1-2")
	var w = game.world
	var a = w.player
	await place_player(380)
	record("spikes")
	a.apply_form(1)
	press(KEY_D,true)
	await ticks(22)
	press(KEY_D,false)
	await ticks(25)
	await photo("spikes")
	clip=""
	check(a.form==0 and state.p.hearts==3,"spikes strip form once during protection")
	a.protection=0
	await ticks(5)
	check(state.p.hearts==2 and state.p.lost==1,"spikes cost one heart during recovery")
	await ticks(70)
	await place_player(w.checkpoint_x)
	await place_player(2144,430)
	a.apply_form(2)
	record("pipe")
	press(KEY_S,true)
	await ticks(12)
	press(KEY_S,false)
	check(w.underground and a.form==2 and a.position.x>=6400,"S enters grotto with same form")
	await photo("grotto")
	press(KEY_D,true)
	await ticks(44)
	press(KEY_D,false)
	await ticks(10)
	var bank: int = state.p.wallet
	check(bank>=1 and state.claimed("1-2/coin_6560"),"underground coin credits campaign")
	clip = ""
	# Traverse the optional room to the other pipe using only A/D and Space.
	press(KEY_D,true)
	var held := 0
	for i in 800:
		await ticks(1)
		if a.position.x>7525:
			break
		if held>0:
			held-=1
			if held==0: press(KEY_SPACE,false)
		elif a.is_on_floor() and (a.is_on_wall() or ((a.position.x>6894 and a.position.x<6920 and a.position.y<350) or (a.position.x>6948 and a.position.x<6990))):
			press(KEY_SPACE,true)
			held=36
	press(KEY_D,false)
	press(KEY_SPACE,false)
	await ticks(35)
	check(absf(a.position.y-432)<2 and absf(a.position.x-7530)<38,"underground room crossed using keys "+str(a.position))
	bank=state.p.wallet
	press(KEY_DOWN,true)
	await ticks(4)
	press(KEY_DOWN,false)
	check(not w.underground and a.form==2 and a.position.x>2160 and a.position.x<2310,"down arrow on return pipe reaches safe surface")
	await place_player(2144,430)
	press(KEY_S,true)
	await ticks(4)
	press(KEY_S,false)
	await place_player(6560)
	check(state.p.wallet==bank,"reentry cannot duplicate cave coin")
	await place_player(7020,595)
	await ticks(95)
	check(not w.underground and absf(a.position.x-w.checkpoint_x)<1 and a.form==0,"cave fall respawns above ground at checkpoint")
	await place_player(2790)
	await ticks(8)
	var count := 0
	for child in w.get_children():
		if child.get("reward_id")=="1-2/pipe_guard":
			count+=1
	await place_player(2580)
	await place_player(2810)
	var repeated := 0
	for child in w.get_children():
		if child.get("reward_id")=="1-2/pipe_guard":
			repeated+=1
	check(count==1 and repeated==1,"ambush triggers once on repeated approach")
	# Stand on the moving deck with no movement keys.
	var deck = w.get_node("BrookFerry")
	await place_player(deck.position.x,deck.position.y-2)
	var last_x: float = a.position.x
	var distance := 0.0
	var relative: float = a.position.x-deck.position.x
	for i in 80:
		await ticks(1)
		distance += absf(a.position.x-last_x)
		last_x = a.position.x
	check(a.is_on_floor() and distance>35 and absf(a.position.x-deck.position.x-relative)<5,"moving deck carries resting actor")
	await place_player(1620,610)
	await ticks(85)
	check(state.p.hearts==0 or absf(a.position.x-w.checkpoint_x)<1,"missed ferry costs a heart")

func local_boss_tests() -> void:
	await test_level("1-3")
	var w=game.world
	var b=w.boss
	var a=w.player
	check(b.hp==9 and not w.get_node("Gate/Hitbox").disabled,"boss begins at 9, gate closed")
	await place_player(w.finish_x,475)
	check(game.page=="play","crossing finish before victory gives no result")
	await place_player(w.checkpoint_x)
	await place_player(1812,441)
	var pilot:=preload("res://tests/boss_pilot.gd").new()
	for frame in 1200:
		await ticks(1)
		if b.hp<9: break
		pilot.tick(self,a,b,false)
	pilot.release(self)
	check(b.hp==6 and b.phase()==2,"real stomp changes phase")
	# Put the small body beside the live boss. Let normal contact trigger death.
	await place_player(b.position.x-35,b.position.y)
	await ticks(80)
	check(state.p.hearts==2 and b.hp==6 and b.phase()==2 and absf(a.position.x-w.checkpoint_x)<2,"respawn at checkpoint keeps wounded phase")
	game.start_level()
	await ticks(6)
	b=game.world.boss
	check(b.hp==9,"full restart restores boss HP")
	var prior: int = state.p.score
	b.take_damage(9)
	var total: int = state.p.score
	check(total-prior==10000 and state.p.enemies==1 and game.page=="play","boss grants 10000, player still controls the arena")
	game.start_level()
	await ticks(5)
	game.world.boss.take_damage(9)
	check(state.p.score==total and state.p.enemies==1,"boss reward cannot be claimed after restart")

func remaining_chests() -> void:
	# Each fixture starts on the actual supporting surface. Open using Space.
	for level: String in ["1-1","1-2","1-3"]:
		await test_level(level)
		var w=game.world
		for chest in w.get_children():
			if chest.get("kind")!="coins": continue
			var surface:=480.0
			if level=="1-1" and chest.position.x==5460: surface=294
			if level=="1-2":
				var surfaces:={1196:384,3890:260,7320:364}
				surface=surfaces.get(int(chest.position.x),480)
			await place_player(chest.position.x,surface-1)
			var balance:int=state.p.wallet
			press(KEY_SPACE,true)
			await ticks(30)
			press(KEY_SPACE,false)
			await ticks(33)
			check(chest.spent and state.p.wallet>=balance+chest.amount,"coin cache opened by jump "+chest.reward_id)
		if level=="1-2":
			await hit_block(2664)
			check(state.claimed("1-2/growth"),"second map potion dispensed")
			w.player.damage(false,true)
			await ticks(80)
			await place_player(2666,479)
			press(KEY_D,true)
			await ticks(30)
			press(KEY_D,false)
			check(w.player.form==1 and state.claimed("1-2/growth/item"),"pending second-map potion remains after death")
		if level=="1-3":
			await place_player(w.get_node("Block350").position.x,383)
			press(KEY_SPACE,true)
			await ticks(28)
			press(KEY_SPACE,false)
			await ticks(40)
			press(KEY_D,true)
			await ticks(21)
			press(KEY_D,false)
			check(w.player.form==1 and state.claimed("1-3/approach_potion/item"),"elevated potion lands on reachable shelf")
			await place_player(1688)
			press(KEY_SPACE,true)
			await ticks(30)
			press(KEY_SPACE,false)
			check(w.player.form==2,"arena rune collected by jumping")

func migration() -> void:
	var store = STORE.new()
	store.prefix = state.store.prefix+"-v1"
	state.new_game("human")
	state.reward("1-1/coin_208",1,10)
	var old: Dictionary=state.p.duplicate(true)
	for crossed in [false,true]:
		if crossed:
			old.level="1-2"
			old.results["1-1"]={"stars":1,"coins":1,"total":138,"score":10,"lost":0,"enemies":0,"seconds":0.0}
		var blob:=var_to_bytes(old)
		var file:=FileAccess.open(store.prefix+".1",FileAccess.WRITE)
		file.store_var({"version":1,"serial":1,"checksum":hash(blob),"data":blob})
		file.close()
		var migrated: Dictionary=store.read_profile()
		check(migrated.wallet==1 and migrated.score==10 and (migrated.coins==0 if crossed else migrated.ids.has("1-1/coin_208")),"v1 migration, crossed="+str(crossed))

# Subclasses can exercise pickups and audit directed passages during the same walk.
func route_action(_level: String, _actor) -> void:
	pass

func route_jump(_level: String, _actor, jump: bool) -> bool:
	return jump

func route_continue(_level: String, _actor, _axis: int, _frame: int) -> bool:
	return true

func riding(actor: CharacterBody2D, deck: AnimatableBody2D) -> bool:
	for index in actor.get_slide_collision_count():
		var hit:=actor.get_slide_collision(index)
		if hit.get_collider()==deck and hit.get_normal().y < -0.8:
			return true
	return false

func route(level: String, capture := true) -> void:
	var w=game.world
	var a=w.player
	var pits: Array = {"1-1":[1600,3184,4784,6560],"1-2":[650,3380],"1-3":[700]}[level]
	var held := 0
	var direction := 0
	var ferry_state := [0,0]
	var floor_hearts: int = state.p.hearts
	for frame in 6500:
		await physics_frame
		if game.page!="play":
			break
		await route_action(level,a)
		var x: float=a.position.x
		max_form=maxi(max_form,a.form)
		var axis := 1
		var jump: bool=a.is_on_wall()
		for edge: int in pits:
			if x>=edge-42 and x<edge: jump=true
		for child in w.get_children():
			if child.has_method("defeat") and absf(child.position.y-a.position.y)<45 and child.position.x-x>12 and child.position.x-x<86:
				jump=true
		if level=="1-2":
			for thorn in [430,3090,3948]:
				if x>thorn-89 and x<thorn-52: jump=true
			for i in 2:
				var deck=w.get_node(["BrookFerry","LastFerry"][i])
				var left: int=[1450,4200][i]
				var right: int=[1770,4480][i]
				if x<left-110 or ferry_state[i]==3: continue
				if ferry_state[i]==0:
					axis=0
					if deck.position.x<left+32 and a.is_on_floor():
						ferry_state[i]=1
						jump=true
						axis=1
				elif ferry_state[i]==1:
					axis=1 if x<deck.position.x-4 else 0
					if riding(a,deck):
						ferry_state[i]=2
						if capture and i==0:
							await photo("ferry")
							record("ferry")
				elif ferry_state[i]==2:
					axis=0
					if x>right-85:
						ferry_state[i]=3
						axis=1
						jump=true
				if x>=right+20: ferry_state[i]=3
			if clip=="ferry" and x>1820: clip=""
		if level=="1-3" and w.boss.hp>0 and x>=2030:
			var pilot:=preload("res://tests/boss_pilot.gd").new()
			press(KEY_SPACE,false)
			press(KEY_D,false)
			var entry_form:int=a.form
			for duel_tick in 4200:
				await ticks(1)
				if w.boss.hp==0 or a.form!=entry_form or state.p.hearts!=floor_hearts: break
				pilot.tick(self,a,w.boss,entry_form==2)
			pilot.release(self)
			check(w.boss.hp==0 and a.form==entry_form,"arena victory in entry form "+str(entry_form))
			if w.boss.hp>0: break
			held=0
			direction=0
		if capture and frame==80: await photo("start-"+level)
		jump=route_jump(level,a,jump)
		if not route_continue(level,a,axis,frame):
			break
		if axis!=direction:
			press(KEY_D,axis>0)
			press(KEY_A,axis<0)
			direction=axis
		if held>0:
			held-=1
			if held==0: press(KEY_SPACE,false)
		elif jump and a.is_on_floor():
			press(KEY_SPACE,true)
			held=40
		await frame_capture()
		if state.p.hearts!=floor_hearts:
			print("UNEXPECTED LOSS ",level," x=",x," state=",ferry_state)
			break
	press(KEY_D,false)
	press(KEY_A,false)
	press(KEY_SPACE,false)
	clip=""
	check(game.page=="result","continuous "+level+" at x="+str(int(a.position.x))+" hp="+str(w.boss.hp if w.boss else -1)+" ferries="+str(ferry_state))
