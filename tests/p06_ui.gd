extends "res://tests/s02_forest.gd"
const OUTPUT5:="res://reports/evidence/p06/after/"
var audit:Array=[]

func _initialize() -> void:
	root.unfocusable=true
	run.call_deferred()

func snap(id:String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT5+id+".png")

func controls(node:Node) -> void:
	for child in node.get_children():
		if child is Button:
			check(child.size.y>=48,"button height: "+child.text)
			check(child.get_global_rect().end.x<=948,"button fits panel: "+child.text)
			check(not child.has_theme_font_size_override("font_size"),"theme button font: "+child.text)
		elif child is Label:
			check(child.get_global_rect().end.x<=960,"label fits viewport: "+child.text)
			if child.autowrap_mode==TextServer.AUTOWRAP_OFF:
				check(child.get_minimum_size().x<=child.size.x+1,"text width: "+child.text)
		controls(child)

func click(caption:String) -> void:
	var target:Button
	for child in game.screen.get_children():
		if child is Button and (child.text==caption or child.name==caption): target=child
	check(target!=null,"visible button "+caption)
	if target==null: return
	var at:=target.get_global_rect().get_center()
	for on in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=at
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=on
		Input.parse_input_event(event)
		await process_frame

func page(id:String,suffix:="") -> void:
	game.show_page(id)
	await process_frame
	controls(game.screen)
	await snap("ui-"+id+suffix)

func run() -> void:
	state=root.get_node("Campaign")
	state.start_sandbox()
	state.p={}
	state.store.notice=""
	change_scene_to_file("res://scenes/boot/campaign.tscn")
	await scene_changed
	game=current_scene
	game.get_node("Interface/Feedback").hide()
	await page("main","-empty")
	await click("Новая игра")
	check(game.page=="heroes","new game opens real hero page")
	await snap("ui-heroes-empty")
	check(game.screen.get_node("ConfirmHero").disabled,"confirmation disabled before selection")
	await click("ConfirmHero")
	check(game.page=="heroes" and state.p.is_empty(),"disabled confirm cannot start a campaign")
	var motion:=InputEventMouseMotion.new()
	motion.position=Vector2(250,280)
	Input.parse_input_event(motion)
	await snap("ui-heroes-hover")
	await click("HeroHit_ogre") # Last matching button is the ogre.
	check(game.selected=="ogre","mouse selects ogre")
	await snap("ui-heroes-ogre")
	await click("Подтвердить выбор")
	check(state.p.hero=="ogre" and game.page=="map","hero callback creates real campaign")
	await page("map")
	await click("Продолжить")
	check(game.page=="play" and state.p.level=="1-1","map callback starts level")
	game.pause()
	game.options()
	check(game.back_page=="pause","settings remembers pause")
	await click("Назад")
	check(game.page=="pause","settings returns to pause")
	game.main_menu()
	game.options()
	var toggles:Array=game.screen.get_children().filter(func(c): return c is CheckButton)
	toggles[0].button_pressed=true
	toggles[0].toggled.emit(true)
	await snap("ui-settings-muted")
	await click("Применить")
	check(state.muted("Музыка") and game.page=="main","mute on means muted; apply returns to menu")
	game.selected=""
	game.show_page("heroes")
	await process_frame
	await process_frame
	# Drive normal focus traversal and activation, preserving focus after selection.
	for code in [KEY_SPACE]:
		press(code,true)
		await process_frame
		press(code,false)
		await process_frame
	check(game.selected=="human","initial focus and Space select the human")
	await snap("ui-heroes-keyboard-human")
	for code in [KEY_TAB,KEY_SPACE]:
		press(code,true)
		await process_frame
		press(code,false)
		await process_frame
	check(game.selected=="ogre","keyboard focus survives selection and advances to ogre")
	await snap("ui-heroes-keyboard-ogre")
	await click("HeroHit_human")
	await page("heroes","-human")
	state.new_game("human")
	game.start_level()
	await ticks(6)
	state.p.wallet=999999
	state.p.score=99999999
	state.p.seconds=5999
	state.p.tutorial={"move":true,"jump":true,"shoot":true}
	game.refresh()
	controls(game.screen)
	var counter:Label=game.hud.wallet
	var font:=counter.get_theme_font("font")
	var width:=-1.0
	for digit in "0123456789":
		var actual:float=font.get_string_size(digit,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x
		if width<0: width=actual
		check(is_equal_approx(actual,width),"tabular digit "+digit)
	for name in ["Alegreya-ExtraBold.ttf","AlegreyaSans-Bold.ttf","AlegreyaSans-Medium.ttf"]:
		var face:FontFile=load("res://assets/ui_art/fonts/"+name)
		check(not face.allow_system_fallback,"no system font fallback "+name)
		var complete:=true
		for letter in "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя0123456789←↑→↓":
			complete=complete and face.has_char(letter.unicode_at(0))
		check(complete,"local Cyrillic/digits/arrows "+name)
	await snap("hud-large-values")
	for dimensions in [Vector2i(640,360),Vector2i(800,450),Vector2i(1280,800),Vector2i(960,540)]:
		root.size=dimensions
		game.show_page("heroes")
		await snap("window-%dx%d"%[dimensions.x,dimensions.y])
	game.start_level()
	await ticks(5)
	for id in ["main","map","settings","pause","future","occupied"]: await page(id)
	game.pending=game.start_level
	game.cancel_page="pause"
	game.show_page("confirm","Вернуться к старту? Потраченные сердца и полученные награды сохранятся. Текущий уровень начнётся с начала.")
	controls(game.screen)
	await snap("ui-confirm")
	await click("Нет, вернуться")
	check(game.page=="pause","confirmation cancellation preserves callback page")
	state.p.purchases=9
	state.p.hearts=1
	state.lose_heart()
	state.p.wallet=999
	await page("offer","-disabled")
	state.p.wallet=1000
	await page("offer")
	await click("Купить 1 сердце — 1000 монет")
	check(state.p.wallet==0 and state.p.hearts==1 and game.page=="play","real purchase debits once and resumes")
	state.p.hearts=1
	state.lose_heart()
	game.show_page("offer")
	await click("Завершить попытку")
	check(game.page=="confirm","end attempt requires existing confirmation")
	await click("Да, продолжить")
	check(game.page=="defeat" and state.p.status=="defeat","confirmed end uses real campaign state")
	await page("defeat")
	state.new_game("human")
	state.finish(138)
	await page("result")
	await click("Следующий уровень")
	check(state.p.level=="1-2" and game.page=="map","result advances via Campaign.leave_result")
	for id in ["1-1","1-2","1-3","2-1","2-2","2-3","2-1"]:
		await test_level(id)
		await ticks(8)
		await RenderingServer.frame_post_draw
		audit.append({"level":id,"textures_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)})
	var file:=FileAccess.open(OUTPUT5+"native-memory.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(audit,"  "))
	print("P06 UI ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
