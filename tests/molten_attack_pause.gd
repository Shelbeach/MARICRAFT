extends "res://tests/molten_mechanics.gd"

func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/molten/pause-%d"%OS.get_process_id())
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	for step in [0,1,2]:
		await fresh("3-3")
		var a=game.world.player
		var b=game.world.boss
		a.position=Vector2(1800,480)
		b.hp=3
		b.step=step
		b.prepare(a)
		await ticks(8)
		check(state.p.hearts==3 and b.mode==b.Mode.WARN,"harmless visible warning for attack %d"%b.attack)
		var clock:float=b.clock
		paused=true
		await ticks(20)
		check(is_equal_approx(clock,b.clock),"warning pauses for attack %d"%b.attack)
		paused=false
		# Local timing fixture: move clear of the locked aim; route tests prove actual evasion.
		a.position=Vector2(1580,480)
		await ticks(67)
		var threats=get_nodes_in_group("molten_attacks")
		check(not threats.is_empty() and state.p.hearts==3,"attack becomes active after warning %d"%b.attack)
		var samples:Array=[]
		for threat in threats: samples.append([threat,threat.position,threat.get("age")])
		clock=b.clock
		paused=true
		await ticks(20)
		for sample in samples:
			check(sample[0].position==sample[1] and sample[0].get("age")==sample[2],"active threat pauses %d"%b.attack)
		check(is_equal_approx(clock,b.clock),"active boss timer pauses %d"%b.attack)
		paused=false
		await ticks(10)
		check(b.clock<clock and state.p.hearts==3,"attack resumes safely %d"%b.attack)
		b.reset_cycle()
		await ticks(2)
		check(get_nodes_in_group("molten_attacks").is_empty(),"reset clears attack %d"%b.attack)
	game.clear_world()
	await process_frame
	await process_frame
	root.get_node("SFX").new_world(false)
	OS.delay_msec(120)
	print("MOLTEN ATTACK PAUSE ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
