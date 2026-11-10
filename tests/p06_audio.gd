extends "res://tests/s04_mechanics.gd"
var sfx
var events:Array=[]
var drops:Array=[]
var recording:AudioEffectRecord
var label:="60"
var allow_focus_resume:=true

func _initialize() -> void:
	root.unfocusable=true
	physics_frame.connect(func():
		if allow_focus_resume and is_instance_valid(game) and game.page=="pause": game.show_page("play"))
	run.call_deferred()

func count(id:String) -> int: return events.filter(func(e): return e.id==id).size()

func live(id:="") -> int:
	return sfx.voices.filter(func(v): return not v.id.is_empty() and (id.is_empty() or v.id==id)).size()

func pickup(kind:String,id:String):
	var item=load("res://scenes/objects/"+kind+".tscn").instantiate()
	item.reward_id="test/audio/"+id
	item.position=game.world.player.position-Vector2(0,16)
	game.world.add_child(item)
	return item

func run() -> void:
	label="30" if "--30" in OS.get_cmdline_user_args() else "60"
	state=root.get_node("Campaign")
	sfx=root.get_node("SFX")
	state.start_sandbox()
	state.store_options({"Эффекты":80},{"Эффекты":false})
	sfx.played.connect(func(id,details): events.append({"id":id,"details":details.duplicate()}))
	sfx.suppressed.connect(func(id,reason): drops.append({"id":id,"reason":reason}))
	recording=AudioEffectRecord.new()
	recording.format=AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,recording)
	recording.set_recording_active(true)
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	check(sfx.streams.size()==22 and sfx.variants.player_jump.size()==3,"22 logical events and 24 source WAV files imported")
	for id in sfx.streams:
		var stream:AudioStreamWAV=sfx.streams[id]
		check(stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.mix_rate==48000 and not stream.stereo and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"PCM16 mono 48k no-loop "+id)
	sfx.random.seed=606
	await actions()
	var jumps:Array=events.filter(func(e): return e.id=="player_jump")
	var used:={}
	for i in jumps.size():
		used[jumps[i].details.variant]=true
		if i>0: check(jumps[i].details.variant!=jumps[i-1].details.variant,"no consecutive jump stream repeat")
	check(used.size()==3,"all three physical-jump variants used")
	await rewards()
	await pipes()
	await enemies()
	await results()
	await attacks_v2()
	await mixer()
	await ticks(110)
	recording.set_recording_active(false)
	var wav:=recording.get_recording()
	check(wav!=null and wav.data.size()>48000,"actual mixed audio captured")
	wav.save_to_wav("res://reports/evidence/p06/game-mix-"+label+".wav")
	var file:=FileAccess.open("res://reports/evidence/p06/events-"+label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"played":events,"suppressed":drops},"  "))
	for id in sfx.config: check(count(id)>0,"covered audible event "+id)
	print("AUDIO CONTRACT ",label," FPS ","FAIL" if failed else "PASS"," events=",events.size())
	quit(1 if failed else 0)

func actions() -> void:
	await test_level("1-1")
	var a=game.world.player
	var jump_before:=count("player_jump")
	for i in 15:
		await place_player(96)
		press(KEY_SPACE,true)
		await ticks(2)
		press(KEY_SPACE,false)
		press(KEY_SPACE,true)
		await ticks(2)
		press(KEY_SPACE,false)
		await ticks(62)
	check(count("player_jump")==jump_before+15,"15 accepted floor jumps; air retries silent")
	var casts:=count("magic_cast")
	a.shoot()
	check(count("magic_cast")==casts,"small form cannot cast sound")
	a.apply_form(2)
	a.shoot()
	await ticks(7)
	a.shoot()
	await ticks(7)
	a.shoot()
	check(count("magic_cast")==casts+2,"two real bolts; projectile cap attempt silent")
	await ticks(150)
	var wall=load("res://scenes/objects/test_platform.tscn").instantiate()
	wall.position=Vector2(184,300)
	wall.size=Vector2(20,180)
	game.world.add_child(wall)
	casts=count("magic_cast")
	for i in 15:
		a.shoot()
		pickup("coin","fast-"+str(i))
		await ticks(22)
	check(count("magic_cast")==casts+15,"15 consecutive successful casts at real wall")
	check(count("coin_pickup")>=15,"rapid physical coins with cast mix")
	var hurt:=count("player_hurt")
	var death:=count("player_death")
	a.protection=0
	a.damage()
	check(count("player_hurt")==hurt+1 and count("player_death")==death,"form loss has hurt only")
	await ticks(20)
	a.protection=0
	var hearts:int=state.p.hearts
	a.damage()
	a.damage()
	check(state.p.hearts==hearts-1 and count("player_death")==death+1 and count("player_hurt")==hurt+1,"confirmed heart decrement, no double damage sound")
	await ticks(72)
	state.cheats.infinite=true
	a.damage(true,true)
	check(count("player_death")==death+1,"infinite hearts produces no false death sound")
	state.cheats.clear()
	await ticks(72)

func rewards() -> void:
	await test_level("1-1")
	var a=game.world.player
	var chest
	for n in game.world.get_children():
		if n.get("kind")=="coins": chest=n; break
	var coins:=count("coin_pickup")
	var opened:=count("chest_open")
	chest.hit_below(a)
	chest.hit_below(a)
	check(count("chest_open")==opened+1 and count("coin_pickup")==coins,"multi-coin chest sounds once, no coin burst")
	var power:=count("powerup_pickup")
	var roof=load("res://scenes/objects/test_platform.tscn").instantiate()
	roof.position=Vector2(50,420)
	roof.size=Vector2(100,18)
	game.world.add_child(roof)
	pickup("potion","blocked-growth")
	await ticks(8)
	check(count("powerup_pickup")==power and a.form==0,"blocked growth has no pickup sound")
	roof.queue_free()
	await ticks(15)
	check(count("powerup_pickup")==power+1 and a.form==1,"cleared growth applies and sounds once")
	await ticks(15)
	pickup("rune","rune")
	await ticks(8)
	check(count("powerup_pickup")==power+2 and a.form==2,"real rune pickup")
	coins=count("coin_pickup")
	state.reward("test/audio/duplicate",1,10)
	pickup("coin","duplicate")
	await ticks(5)
	check(count("coin_pickup")==coins,"claimed reward reload is silent")
	var fragile=load("res://scenes/objects/reward_block.tscn").instantiate()
	fragile.kind="fragile"
	fragile.reward_id="test/audio/break"
	fragile.position=Vector2(250,360)
	game.world.add_child(fragile)
	var broken:=count("block_break")
	fragile.hit_below(a)
	fragile.hit_below(a)
	check(count("block_break")==broken+1,"actual fragile destruction once")

func pipes() -> void:
	await test_level("2-2")
	var checkpoint:=count("checkpoint")
	await place_player(game.world.checkpoint_x)
	await place_player(game.world.checkpoint_x+40)
	await place_player(game.world.checkpoint_x)
	check(count("checkpoint")==checkpoint+1,"checkpoint once in live world")
	var before:=count("pipe_transition")
	await place_player(3060,431)
	press(KEY_S,true)
	await ticks(3)
	press(KEY_S,false)
	check(game.world.underground and count("pipe_transition")==before+1,"one successful entry warp, no second exit sound")
	await ticks(25)
	await place_player(8760,431)
	press(KEY_S,true)
	await ticks(3)
	press(KEY_S,false)
	check(not game.world.underground and count("pipe_transition")==before+2,"one successful return warp")

func enemies() -> void:
	await hats()
	check(count("hat_kick")>0,"real HIDDEN to ROLLING kick")
	for id in ["1-3","2-3"]:
		await test_level(id)
		var b=game.world.boss
		game.world.player.position=Vector2(b.position.x-180,479)
		var warning:=count("boss_warning")
		b.prepare(game.world.player)
		check(count("boss_warning")==warning+1,"one preparation sound "+id)
		var pops:=count("enemy_pop")
		b.magic_hit()
		check(count("enemy_pop")==pops,"closed boss rejects silently "+id)
		await ticks(8)
		b.take_damage(1)
		check(count("enemy_pop")==pops+1,"HP damage pop "+id)
		check(events[-1].details.volume_db==-8,"boss pop additional minus six dB "+id)
		b.reset_health()
		check(live("boss_warning")==0,"reset cancels warning "+id)
		await ticks(14)
		var wins:=count("level_complete")
		b.take_damage(9)
		check(count("level_complete")==wins and live("boss_warning")==0,"boss death opens gate without level jingle "+id)

func results() -> void:
	await test_level("2-3")
	game.world.boss.take_damage(9)
	var wins:=count("level_complete")
	await place_player(game.world.finish_x+2)
	check(game.page=="result" and count("level_complete")==wins+1 and live("level_complete")==1,"confirmed finish survives result page pause")
	game.show_page("result")
	await ticks(110)
	check(count("level_complete")==wins+1,"redrawing saved result does not replay victory")
	await test_level("1-1")
	state.p.hearts=1
	game.world.player.damage(true,true)
	check(game.page=="offer" and live("player_death")==1,"death completes across offer screen")
	await ticks(42)
	var over:=count("game_over")
	game.end_attempt()
	check(game.page=="defeat" and count("game_over")==over+1 and live("game_over")==1,"offer to defeat starts game over once")
	game.show_page("defeat")
	await ticks(80)
	check(count("game_over")==over+1,"saved defeat redraw is silent")
	game.show_page("main")
	for n in game.screen.get_children():
		if n is Button and n.text=="Настройки":
			n.pressed.emit()
			break
	check(game.page=="settings" and live("ui_click")==1,"central UI click survives closing its source page")

func mixer() -> void:
	await test_level("1-1")
	sfx.new_world(false)
	sfx.unlocked=false
	check(not sfx.play("player_jump",self,"locked"),"locked Web-style state drops event")
	sfx.unlocked=true
	await ticks(8)
	check(live()==0,"unlock does not flush an old queue")
	check(sfx.play("player_jump",self,"dedupe"),"first event token accepted")
	check(not sfx.play("player_jump",self,"dedupe"),"duplicate action token rejected")
	sfx.new_world(false)
	for id in ["player_jump","magic_cast","coin_pickup","chest_open","block_break","pipe_transition","enemy_pop","hat_kick"]: sfx.play(id,self,id)
	check(live()==8,"eight ordinary voices fit")
	check(not sfx.play("ui_click",self,"reserved"),"two slots reserved for important signals")
	sfx.play("boss_warning",self,"priority-warning")
	sfx.play("player_death",self,"priority-death")
	check(live()==10,"maximum ten simultaneous voices")
	sfx.play("level_complete",self,"priority-result")
	check(live()==10 and live("boss_warning")==1 and live("level_complete")==1,"important signal replaces low priority, stays bounded")
	await ticks(10)
	allow_focus_resume=false
	game.pause()
	check(live()==0,"pause cancels gameplay and old transition sounds")
	sfx.play("ui_click",self,"paused-click")
	check(live("ui_click")==1,"UI remains audible during pause")
	game.show_page("play")
	await ticks(8)
	check(live()==0,"resume does not restart paused voices")
	state.store_options({"Эффекты":50},{"Эффекты":false})
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Эффекты")),linear_to_db(0.5)),"existing settings set bus volume once")
	sfx.play("player_jump",self,"half-volume")
	state.store_options({"Эффекты":80},{"Эффекты":true})
	await ticks(2)
	check(live()==0 and not sfx.play("boss_warning",self,"muted"),"mute stops active effects and drops new effects")
	state.store_options({"Эффекты":0},{"Эффекты":false})
	check(not sfx.play("player_jump",self,"zero"),"zero volume is silent")
	state.store_options({"Эффекты":80},{"Эффекты":false})
	game.start_level()
	check(live()==0,"restart leaves no previous-world sounds")
	game.main_menu()
	check(live()==0,"main menu has no old warnings")

func attacks_v2() -> void:
	await test_level("1-3")
	state.cheats.shield=true
	var boss=game.world.boss
	await place_player(boss.home.x-210)
	for phase in 3:
		boss.hp=9-phase*3
		boss.next_water=false
		var id:String=["murloc_water_cast","murloc_dash","murloc_slam"][phase]
		var before:=count(id)
		boss.prepare(game.world.player)
		await ticks(ceili((boss.move.warning+boss.move.execution)*60)+4)
		check(count(id)==before+1,"one real murloc attack activation "+id)
	boss.reset_health()
	check(live("murloc_slam")==0,"boss reset stops attack tail")
	await test_level("2-3")
	await place_player(3090)
	boss=game.world.boss
	for phase in 3:
		boss.reset_cycle()
		boss.hp=9-phase*3
		var id:String=["foreman_pickaxe_strike","foreman_wax_burst","foreman_rockfall"][phase]
		var before:=count(id)
		boss.prepare(game.world.player)
		var marks:=get_nodes_in_group("mine_strikes")
		check(marks.size()==(1 if phase==0 else 2),"current foreman mark count phase "+str(phase+1))
		await ticks(20)
		check(count(id)==before,"warning never plays active sound "+id)
		for mark in marks:
			var skin=mark.get_node("Skin")
			skin._process(0)
			check(skin.art.last_clip.ends_with("_warning") and skin.art.sprite.sprite_frames.get_frame_count(skin.art.last_clip)==4,"P06 warning follows real mark")
		await ticks(100)
		check(count(id)==before+(2 if phase==2 else 1),"one sound per activation, simultaneous wax grouped "+id)
	var falls:Array=events.filter(func(e):return e.id=="foreman_rockfall")
	check(falls.size()>=2 and absf(falls[-1].details.clock-falls[-2].details.clock-0.45)<0.04,"second rockfall uses its own delayed activation")
	boss.prepare(game.world.player)
	boss.take_damage(9)
	var before:=count("foreman_rockfall")
	await ticks(125)
	check(count("foreman_rockfall")==before,"deleted warnings cannot sound after death")
	check(live("foreman_rockfall")==0,"death stops active attack tail")
	state.cheats.clear()
