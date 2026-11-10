extends SceneTree

var state
var game
var failed := false
var shots := false
const STORE := preload("res://scripts/core/save_store.gd")

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, caption: String) -> void:
	print(("PASS " if value else "FAIL ") + caption)
	failed = failed or not value

func ticks(count: int) -> void:
	for i in count:
		await physics_frame

func press(code: Key,on: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = on
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func photo(id: String) -> void:
	if shots:
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://reports/evidence/screenshots/s01-"+id+".png")
		check(root.get_texture().get_image().save_png(path)==OK,"viewport "+id)

func place_player(x: float, y := 479.0) -> void:
	var player = game.world.player
	player.position = Vector2(x,y)
	player.velocity = Vector2.ZERO
	player.get_node("Camera").reset_smoothing()
	await ticks(5)

func hit_block(x: float) -> void:
	await place_player(x)
	press(KEY_SPACE,true)
	await ticks(22)
	press(KEY_SPACE,false)
	await ticks(48)

func run() -> void:
	shots = "--screenshots" in OS.get_cmdline_user_args()
	state = root.get_node("Campaign")
	# Only test records on D: are touched, even when a regular native save exists.
	var work := ProjectSettings.globalize_path("res://reports/temp/s01")
	DirAccess.make_dir_recursive_absolute(work)
	if shots:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/evidence/screenshots"))
	state.store.prefix = work.path_join("run-%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()])
	state.store.serial = 0
	state.store.notice = ""
	state.p = {}
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game = current_scene
	await photo("menu")
	game.pages.request_new()
	game.pages.select_hero("ogre")
	await photo("heroes")
	game.pages.start_campaign()
	check(state.p.hero=="ogre" and state.p.hearts==3 and state.p.wallet==0 and game.page=="map","new ogre campaign and route map")
	await photo("map")
	game.start_level()
	await ticks(6)
	var player = game.world.player
	var ogre_box: Vector2 = player.get_node("Hitbox").shape.size
	var ogre_speed: float = player.SPEED
	check(game.world.total_coins==138,"authored coin total")
	await photo("hud")
	await place_player(208)
	check(state.p.wallet==1 and state.p.score==10,"touch coin immediately credits balance and score")
	await hit_block(544)
	await hit_block(544)
	check(state.p.wallet==21,"head strike on chest pays 20 once")
	await hit_block(2608)
	check(state.claimed("1-1/block_2608") and not state.claimed("1-1/block_2608/item"),"bonus chest opens before collection")
	game.start_level()
	await ticks(6)
	check(game.world.get_node_or_null("Coin208")==null and game.world.get_node("Block544").spent and state.p.wallet==21,"restart retains spent rewards")
	player = game.world.player
	await ticks(65)
	await place_player(2646)
	await photo("potion")
	check(player.form==1 and state.claimed("1-1/block_2608/item"),"uncollected potion restored after restart")
	await hit_block(6240)
	check(state.claimed("1-1/block_6128"),"large hero can open ridge chest")
	player.damage()
	check(player.form==0 and state.p.hearts==3,"large form absorbs hit")
	player.protection = 0
	player.apply_form(2)
	player.damage()
	check(player.form==0 and state.p.hearts==3,"magic form absorbs hit")
	player.protection = 0
	player.damage()
	player.damage()
	check(state.p.hearts==2 and state.p.lost==1,"small hit charged once during recovery")
	await ticks(70)
	await place_player(game.world.checkpoint_x)
	check(game.world.checkpoint and state.p.hearts==2,"checkpoint activates without healing")
	await photo("checkpoint")
	player.apply_form(2)
	await place_player(8300,625)
	await ticks(72)
	check(state.p.hearts==1 and player.form==0 and absf(player.position.x-game.world.checkpoint_x)<1,"fall costs one and respawns at checkpoint")
	game.pause()
	var t: float = state.p.seconds
	await ticks(40)
	check(game.page=="pause" and state.p.seconds==t,"pause freezes active clock")
	game.show_page("play")
	await place_player(3840)
	await hit_block(3840)
	check(game.world.has_node("Block3712"),"small form cannot break block")
	player.apply_form(1)
	await hit_block(3840)
	check(not game.world.has_node("Block3712") and state.claimed("1-1/block_3712"),"large head strike breaks block")
	player.apply_form(2)
	await place_player(4340,369)
	await photo("enemy")
	player.shoot()
	player.shoot()
	player.shoot()
	check(get_nodes_in_group("bolts").size()==2,"magic cap two")
	await ticks(150)
	check(get_nodes_in_group("bolts").is_empty(),"bolts expire or collide")
	var murloc = game.world.get_node_or_null("BrookGuard")
	if murloc:
		player.position = murloc.position - Vector2(0,69)
		player.velocity = Vector2(0,165)
		await ticks(28)
	check(state.claimed("1-1/murloc_brook"),"murloc defeated by magic or stomp")
	await combat_and_input()
	state.new_game("human")
	game.start_level()
	await ticks(6)
	player = game.world.player
	check(player.get_node("Hitbox").shape.size==ogre_box and player.SPEED==ogre_speed,"both heroes share body and speed")
	# A carried balance from earlier progress, followed by the actual 20-coin chest.
	state.reward("fixture/prior",99,990)
	await hit_block(544)
	for i in 3:
		player.damage(false,true)
		await ticks(70)
	check(state.p.wallet==119 and state.p.hearts==0 and game.page=="offer","99+20 and zero hearts show offer")
	await photo("offer")
	var disk = STORE.new()
	disk.prefix = state.store.prefix
	var restored: Dictionary = disk.read_profile()
	check(restored.status=="offer" and restored.wallet==119,"fresh reader restores pending purchase")
	game.purchase()
	game.purchase()
	check(state.p.wallet==19 and state.p.hearts==1 and state.price()==200 and state.p.purchases==1,"double purchase leaves 19 and exactly one heart")
	state.reward("fixture/next",200,2000)
	player.damage(false,true)
	game.purchase()
	check(state.price()==300 and state.p.wallet==19,"second purchase costs 200")
	player.damage(false,true)
	game.end_attempt()
	check(state.p.status=="defeat" and game.page=="defeat","refusal shows campaign defeat")
	state.new_game("human")
	check(state.p.hearts==3 and state.p.wallet==0 and state.p.lost==0,"new attempt clears defeated campaign")
	game.start_level()
	await ticks(4)
	state.start_sandbox()
	state.debug_values(500,1)
	state.end_sandbox()
	check(state.p.wallet==0 and state.p.hearts==3,"debug fork does not touch regular profile")
	check(state.stars(10,13,0)==1 and state.stars(11,13,1)==2 and state.stars(11,13,0)==3,"star threshold and heart loss")
	await traverse()
	# Deliberately corrupt only the newest isolated test record.
	var corrupt := FileAccess.open("%s.%d"%[state.store.prefix,state.store.serial%2],FileAccess.WRITE)
	corrupt.store_8(0)
	corrupt.close()
	check(not disk.read_profile().is_empty() and not disk.notice.is_empty(),"damaged latest record falls back with notice")
	quit(1 if failed else 0)

func combat_and_input() -> void:
	state.new_game("ogre")
	game.start_level()
	await ticks(5)
	var actor = game.world.player
	var short_top := 480.0
	var high_top := 480.0
	for hold in [3,45]:
		await place_player(1480)
		press(KEY_SPACE,true)
		for step in 72:
			if step==hold:
				press(KEY_SPACE,false)
			if hold==3 and step==14:
				var previous: float = actor.velocity.y
				press(KEY_SPACE,true)
				await ticks(1)
				check(actor.velocity.y >= previous,"airborne second press cannot jump")
				press(KEY_SPACE,false)
			await ticks(1)
			if hold==3:
				short_top = minf(short_top,actor.position.y)
			else:
				high_top = minf(high_top,actor.position.y)
	check(short_top-high_top > 35,"holding Space raises jump apex")
	var rune = load("res://scenes/objects/rune.tscn").instantiate()
	rune.reward_id = "fixture/rune"
	rune.position = actor.position - Vector2(0,14)
	game.world.add_child(rune)
	await ticks(5)
	check(actor.form==2 and state.p.score==1000,"touching rune grants magic and 1000 points")
	var potion = load("res://scenes/objects/potion.tscn").instantiate()
	potion.reward_id = "fixture/potion"
	potion.position = actor.position - Vector2(0,14)
	game.world.add_child(potion)
	await ticks(5)
	check(actor.form==2 and state.p.score==2000,"potion does not downgrade magic")
	var enemy = game.world.get_node("BrookGuard")
	await place_player(enemy.position.x-65,enemy.position.y-1)
	actor.facing = 1
	press(KEY_E,true)
	await ticks(28)
	press(KEY_E,false)
	check(not game.world.has_node("BrookGuard") and state.p.enemies==1,"E bolt defeats patrolling murloc")
	game.start_level()
	await ticks(6)
	actor = game.world.player
	enemy = game.world.get_node("BrookGuard")
	actor.position = enemy.position-Vector2(0,63)
	actor.velocity = Vector2(0,120)
	await ticks(22)
	check(not game.world.has_node("BrookGuard") and actor.velocity.y<0 and state.p.enemies==1,"stomp rebounds; restored enemy pays no second reward")
	enemy = game.world.get_node("GateGuard")
	actor.position = enemy.position - Vector2(10,0)
	await ticks(5)
	check(state.p.hearts==2 and state.p.lost==1,"real side contact costs a small hero one heart")
	game.start_level()
	await ticks(3)
	check(state.p.lost==1 and state.p.hearts==2,"restart preserves losses for third star")

func traverse() -> void:
	var player = game.world.player
	var pits := [1600,3184,4784,6560]

	var held := 0
	var approach_shown := false
	press(KEY_D,true)
	for frame in 9000:
		await physics_frame
		if game.page != "play":
			break
		var x: float = player.position.x
		if x>6970 and not approach_shown:
			approach_shown = true
			await photo("finish")
		var launch: bool = player.is_on_wall()
		for edge: int in pits:
			if x >= edge-42 and x <= edge-1:
				launch = true
		for enemy in game.world.get_children():
			if enemy.has_method("defeat") and enemy.position.x-x > 15 and enemy.position.x-x < 86:
				launch = true
		if held > 0:
			held -= 1
			if held == 0:
				press(KEY_SPACE,false)
		elif launch and player.is_on_floor():
			press(KEY_SPACE,true)
			held = 35
		if frame==2800:
			await photo("route")
	press(KEY_D,false)
	press(KEY_SPACE,false)
	check(game.page=="result" and state.p.level=="1-2","continuous keyboard route finished at x="+str(int(player.position.x)))
	if game.page=="result":
		check(player.form==0 and state.p.lost==0,"route cleared small without losing a heart")
		check(not state.finish(138) and state.p.results.size()==1,"single result on repeated finish")
		await photo("result")
		game.next_map()
		game.start_level()
		check(game.page=="play" and state.p.level=="1-2","map starts the next forest level")
