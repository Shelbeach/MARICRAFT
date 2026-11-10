extends SceneTree
## Run with Godot --main-pack <extracted ZIP's MARICRAFT.pck> --script <this file>.
## Export templates do not expose --script; the separate EXE smoke test uses
## its normal entry point. Game resources here all resolve inside the shipped PCK.
var state
var game
var menu
var checks: Array = []
var failures := 0

func _initialize() -> void:
	root.unfocusable = true
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks.append({"pass":ok,"check":label})
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label)

func ticks(count := 3) -> void:
	for i in count: await physics_frame

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func f1() -> void:
	key(KEY_F1,true)
	await process_frame
	key(KEY_F1,false)
	await process_frame

func click(caption: String) -> void:
	for button in menu.controls.get_children():
		if button is Button and button.text == caption:
			button.pressed.emit()
			return
	check(false,"Missing debug button: "+caption)

func saves() -> Array:
	var result: Array = []
	for slot in 2:
		var path := "user://campaign.%d" % slot
		result.append(FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "")
	return result

func run() -> void:
	await process_frame
	state = root.get_node("Campaign")
	check(OS.is_debug_build() and OS.has_feature("teacher_debug"),"Windows debug runtime and teacher feature")
	check(OS.get_user_data_dir().replace("\\","/").ends_with("/MARICRAFT-Teacher"),"Separate teacher save directory")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/boot/campaign.tscn","Packed game retains the ordinary main scene")
	game = load("res://scenes/boot/campaign.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await ticks()
	check(game.page == "main","Packed main menu loads")
	menu = root.get_node("DebugTools/DeveloperMenu")
	await f1()
	check(menu.modal.visible and paused,"Real F1 input opens debug modal and pauses")
	await f1()
	check(not menu.modal.visible,"F1 closes debug modal")
	state.new_game("ogre")
	state.reward("1-1/handoff-probe",17,170)
	game.start_level()
	await ticks(15)
	var x: float = game.world.player.position.x
	key(KEY_D,true)
	await ticks(15)
	key(KEY_D,false)
	check(game.world.player.position.x > x + 15,"Keyboard movement in standalone EXE")
	var y: float = game.world.player.position.y
	key(KEY_SPACE,true)
	await ticks(10)
	key(KEY_SPACE,false)
	check(game.world.player.position.y < y - 15,"Keyboard jump in standalone EXE")
	await f1()
	click("Начать тестовую сессию")
	check(state.sandbox,"Existing sandbox enabled through menu button")
	var snapshot: Array = saves()
	click("Заново · 1-1")
	await ticks(15)
	await f1()
	click("Бесконечные сердца  —")
	click("Неуязвимость  —")
	check(state.cheats.get("infinite",false) and state.cheats.get("shield",false),"Both god-mode flags enabled through existing controls")
	var hearts: int = state.p.hearts
	game.world.player.damage()
	state.lose_heart()
	check(state.p.hearts == hearts,"Shield and infinite hearts prevent life loss")
	var wallet: int = state.p.wallet
	click("+100 монет")
	check(state.p.wallet == wallet + 100,"Debug coins control")
	for form in 3:
		click(game.world.player.FORM_NAMES[form])
		check(game.world.player.form == form,"Debug form "+str(form))
	click("Полёт (стрелки)  —")
	await f1()
	y = game.world.player.position.y
	key(KEY_UP,true)
	await ticks(15)
	key(KEY_UP,false)
	check(game.world.player.position.y < y - 15,"Flight follows keyboard input")
	await f1()
	click("К привалу")
	await ticks()
	check(absf(game.world.player.position.x-game.world.checkpoint_x) < 5,"Checkpoint teleport")
	for id in state.ROUTE:
		if not menu.modal.visible: await f1()
		click("Заново · "+id)
		await ticks(10)
		check(game.page == "play" and state.p.level == id and is_instance_valid(game.world.player),"Packed level and resources load: "+id)
		check(state.cheats.is_empty(),"Level change clears cheats: "+id)
		if game.world.boss:
			await f1()
			var hp: int = game.world.boss.MAX_HP
			click("Босс · %d / %d ОЗ" % [hp,hp])
			await ticks(30)
			check(absf(game.world.player.position.x-(game.world.boss.home.x-225)) < 150,"Boss teleport: "+id)
			await f1()
			click("Победить босса")
			check(game.world.boss.hp == 0,"Debug victory covers actual boss HP: "+id)
			click("Восстановить босса")
			check(game.world.boss.hp == hp,"Debug boss reset: "+id)
	check(saves() == snapshot,"Sandbox leaves both on-disk save slots byte-identical")
	if not menu.modal.visible: await f1()
	click("В обычный профиль")
	await ticks()
	check(not state.sandbox and state.cheats.is_empty(),"Leaving sandbox clears all debug flags")
	check(state.p.wallet == 17 and state.p.hero == "ogre" and state.p.level == "1-1","Ordinary teacher progress restored without cheat rewards")
	var path := OS.get_cmdline_user_args()[0]
	var report := {"checks":checks,"failures":failures,"version":Engine.get_version_info(),"user_data":OS.get_user_data_dir(),"executable":OS.get_executable_path()}
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.clear_world()
	root.get_node("MusicManager").stop_all()
	paused = false
	await ticks()
	quit(1 if failures else 0)
