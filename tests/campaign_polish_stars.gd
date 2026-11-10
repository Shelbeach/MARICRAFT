extends "res://tests/durotar_revision_branches.gd"
## Continuous small-form reward routes: only keyboard input after each real spawn.
var summaries:={}

func branch(name:String,launch:Array=[]) -> void:
	var row:Array=[]
	for c in cases:
		if c[3]==name: row=c;break
	check(not row.is_empty(),"known reward branch "+name)
	if row.is_empty(): return
	await approach(row[1].x,launch)
	await settle(20)
	await centre(row[1].x)
	if row.size()>4: await vertical_lift(game.world.get_node(row[4]))
	for step in row[2]:
		await hop(step[0],step[1])
		if pilot_failed: return
	var chest=game.world.get_node(name)
	await wait_and_stomp()
	await centre(chest.position.x)
	await jump_here()
	check(state.claimed(chest.reward_id),"continuous chest "+name)

func stage_one() -> void:
	await branch("TrailPay")
	await branch("RidgePay",[770])
	await branch("CacheSeal",[1500])
	await branch("HatWorkshop",[2780])
	await branch("WatchPay",[3570])
	await branch("CargoPay")
	await approach(5303,[4450])

func stage_two() -> void:
	var w=game.world
	await branch("SurveyPay")
	await approach(680)
	await crossing(w.get_node("WestLift"),1050)
	await branch("SwitchPay")
	await approach(1830)
	await crossing(w.get_node("EastLift"),2200)
	await branch("GalleryPay")
	await approach(3280)
	await settle(65)
	await approach(w.get_node("Entry").position.x)
	await pipe_down()
	check(w.underground,"small enters mine through pipe")
	await branch("VeinPay")
	await branch("LowerPay",[7745])
	await branch("VaultSeal")
	await approach(8760)
	await pipe_down()
	check(not w.underground,"small leaves mine through pipe")
	await approach(3630,[3435])
	await crossing(w.get_node("DeepLift"),4020)
	await approach(4160)
	await settle(55)
	await branch("KilnPay",[4180,4560])
	await approach(5403)

func stage_three() -> void:
	await branch("ShiftPay")
	await approach(475)
	await settle(65)
	await branch("ForemanPay",[490])
	await approach(1030)
	await settle(65)
	await branch("ForgeCache",[1060])
	await approach(2140)
	await settle(65)
	await approach(3070,[2150])
	await fight(false)
	if not pilot_failed: await approach(4023)

func run() -> void:
	state=root.get_node("Campaign")
	state.store.prefix=ProjectSettings.globalize_path("res://reports/temp/campaign-polish/stars-%d"%OS.get_process_id())
	var args:=OS.get_cmdline_user_args()
	var only:=""
	for a in args:
		if a.begins_with("--level="): only=a.trim_prefix("--level=")
	state.store.first_level="2-1" if only.is_empty() else only
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	state.new_game("ogre" if "--ogre" in args else "human")
	game.start_level()
	entering_form=0;expected_form=0
	for id in (["2-1","2-2","2-3"] if only.is_empty() else [only]):
		start_stage(id)
		await ticks(8)
		match id:
			"2-1": await stage_one()
			"2-2": await stage_two()
			"2-3": await stage_three()
		await settle(5)
		check(game.page=="result" and state.p.hearts==3 and game.world.player.form==0,"continuous small no-damage finish "+id)
		if game.page!="result" or failed or pilot_failed:
			print("STOP ",id," ",game.world.player.position," form=",game.world.player.form," hearts=",state.p.hearts)
			quit(1);return
		var result:Dictionary=state.p.last_result.duplicate()
		print("COINS ",id," ",result.coins,"/",result.total," stars=",result.stars)
		check(result.stars==3,"small without magic earns three stars "+id)
		summaries[id]={"result":result,"events":events,"ticks":frame_no}
		if not only.is_empty() or id=="2-3": break
		game.next_map();game.start_level()
	var file:=FileAccess.open("res://reports/evidence/campaign-polish/stars-durotar-"+str(state.p.hero)+("-30" if "--30" in args else "-60")+("-"+only if not only.is_empty() else "")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summaries))
	game.clear_world()
	await process_frame
	await process_frame
	root.get_node("SFX").new_world(false)
	OS.delay_msec(120)
	print("SMALL THREE STARS ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
