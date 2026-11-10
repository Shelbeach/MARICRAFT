extends Node

const Art:=preload("res://scripts/visual/art_library.gd")
const ForestUI:=preload("res://scripts/ui/forest_ui.gd")
const UI := preload("res://scripts/core/ui_kit.gd")
const Pages := preload("res://scripts/ui/campaign_pages.gd")
const LEVELS := {
	"1-1": preload("res://scenes/levels/forest_1_1.tscn"),
	"1-2": preload("res://scenes/levels/forest_1_2.tscn"),
	"1-3": preload("res://scenes/levels/forest_1_3.tscn"),
	"2-1": preload("res://scenes/levels/durotar_2_1.tscn"),
	"2-2": preload("res://scenes/levels/durotar_2_2.tscn"),
	"2-3": preload("res://scenes/levels/durotar_2_3.tscn"),
	"3-1": preload("res://scenes/levels/molten_3_1.tscn"),
	"3-2": preload("res://scenes/levels/molten_3_2.tscn"),
	"3-3": preload("res://scenes/levels/molten_3_3.tscn")
}
@onready var screen: Control = $Interface/Screen
var pages
var world
var page := ""
var selected := ""
var map_selected := ""
var back_page := "main"
var cancel_page := ""
var pending: Callable
var hud: Dictionary
var hint: Label

func _ready() -> void:
	MusicManager.bind_flow(self)
	screen.theme=ForestUI.theme()
	$Interface/Feedback.theme=screen.theme
	# The automated Web acceptance runner can opt into observation only.
	# Ordinary pages create no observer; release still has no debug commands.
	if OS.has_feature("web") and JavaScriptBridge.eval("window.MARICRAFT_QA === true"):
		var observer=preload("res://scripts/debug/web_observer.gd").new()
		observer.host=self
		add_child(observer)
	pages = Pages.new()
	pages.host = self
	Campaign.changed.connect(refresh)
	while not Campaign.access_ready:
		await get_tree().process_frame
	if Campaign.access_denied:
		show_page("occupied")
	else:
		restore_screen()

func restore_screen() -> void:
	if not Campaign.p.is_empty():
		match Campaign.p.status:
			"offer","defeat","result","victory":
				show_page(Campaign.p.status)
				return
	show_page("main")

func start_level() -> void:
	if not LEVELS.has(Campaign.p.level):
		show_page("future")
		return
	clear_world()
	world = LEVELS[Campaign.p.level].instantiate()
	world.process_mode = PROCESS_MODE_PAUSABLE
	add_child(world)
	world.cleared.connect(func(): show_page(Campaign.p.status))
	show_page("play")

func clear_world() -> void:
	SFX.new_world()
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null

func main_menu() -> void:
	Campaign.save()
	clear_world()
	show_page("main")

func ask(message: String, yes: Callable) -> void:
	cancel_page = page
	pending = yes
	show_page("confirm",message)

func options() -> void:
	back_page = page
	show_page("settings")

func show_page(next: String, message := "") -> void:
	for child in screen.get_children():
		screen.remove_child(child)
		child.queue_free()
	page = next
	SFX.page_changed(next)
	get_tree().paused = is_instance_valid(world) and next != "play"
	hud.clear()
	hint = null
	if next == "play":
		build_hud()
	else:
		pages.draw(next,message)
		# Godot needs an initial focus owner for Tab/Space navigation after rebuilding
		# a page. Mouse activation alone had hidden this gap in the old menus.
		focus_page.call_deferred()
	refresh()

func focus_page() -> void:
	if page=="play" or get_viewport().gui_get_focus_owner()!=null: return
	if screen.has_node("WorldMap/MapStart"):
		screen.get_node("WorldMap/MapStart").grab_focus()
		return
	for control in screen.find_children("*","Control",true,false):
		if control is Control and control.focus_mode==Control.FOCUS_ALL and (not control is BaseButton or not control.disabled):
			control.grab_focus()
			break

func refresh() -> void:
	$Interface/Feedback.text = Campaign.store.notice
	if Campaign.sandbox:
		$Interface/Feedback.text = "ТЕСТОВЫЙ ПРОФИЛЬ   ·   Изменения только в памяти"
	# This small status line has its own row. Gameplay instructions have one owner
	# and a fixed priority below; they cannot overlap the sandbox/store notice.
	$Interface/Feedback.position=Vector2(32,508)
	$Interface/Feedback.size=Vector2(896,24)
	if page == "play" and Campaign.p.get("status") == "offer":
		show_page("offer")
		return
	if page != "play" or not is_instance_valid(world):
		return
	var p := Campaign.p
	if hud.hearts.filled != p.hearts:
		hud.hearts.filled = p.hearts
		hud.hearts.queue_redraw()
	hud.wallet.text = str(p.wallet)
	hud.score.text = str(p.score)
	hud.form.text = "Форма: "+world.player.FORM_NAMES[world.player.form]
	hud.time.text = UI.clock(Campaign.local_stat("seconds"))
	if hud.has("molten_boss"):
		hud.molten_boss.visible=world.boss.in_arena() and world.boss.hp>0
		hud.molten_boss.set_ratio(float(world.boss.hp)/float(world.boss.MAX_HP))
	if hud.has("boss_bar"):
		var active:bool=world.boss.in_arena() and world.boss.hp>0
		hud.boss_bar.visible=active
		hud.boss_name.visible=active
		hud.boss_bar.value=world.boss.hp

	if world.boss and world.boss.hp>0 and world.boss.in_arena():
		hint.text = ""
	elif world.boss and world.boss.hp<=0 and world.player.position.x>=world.arena_entry_x:
		hint.text="Босс повержен · проходы открыты"
	elif world.pipe_prompt != "":
		hint.text = world.pipe_prompt
	elif not p.tutorial.has("move"):
		hint.text = "A / D    Идите вправо по тропе"
	elif not p.tutorial.has("jump"):
		hint.text = "Пробел    Прыжок  ·  Удерживайте для высокого прыжка"
	elif world.player.form == 2 and not p.tutorial.has("shoot"):
		hint.text = "E    Магический выстрел"
	else:
		hint.text = ""
	hud.hint_panel.visible=not hint.text.is_empty()

func build_hud() -> void:
	ForestUI.panel(screen,Rect2(12,12,936,58))
	hud.level=UI.counter(screen,Campaign.p.level,30,25,48,32)
	hud.hearts=UI.symbols(screen,"hearts",Campaign.p.hearts,96,28,26)
	ForestUI.icon(screen,"hud_coin",Vector2(206,28))
	hud.wallet=UI.counter(screen,"",238,25,74,32)
	UI.label(screen,"Очки",326,26,48,30,18,UI.MUTED)
	hud.score=UI.counter(screen,"",380,25,94,32)
	hud.form=UI.label(screen,"",487,25,202,32,18,UI.PAPER)
	ForestUI.icon(screen,"clock",Vector2(697,28),Vector2(23,23))
	hud.time=UI.counter(screen,"",726,25,68,32)
	UI.button(screen,"Пауза",pause,809,17,119,48)
	hud.hint_panel=ForestUI.panel(screen,Rect2(112,162,736,38))
	hint=UI.label(hud.hint_panel,"",24,3,688,32,20,UI.PAPER)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if world.boss and world.has_meta("molten_art"):
		var boss_view=preload("res://assets/molten_art/ui/boss_health.tscn").instantiate()
		screen.add_child(boss_view)
		boss_view.position=Vector2(326,90)
		boss_view.scale=Vector2.ONE*0.82
		boss_view.mouse_filter=Control.MOUSE_FILTER_IGNORE
		hud.molten_boss=boss_view
	elif world.boss:
		hud.boss_name=UI.label(screen,world.boss.title,304,88,352,30,23,UI.PAPER)
		hud.boss_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var bar:=TextureProgressBar.new()
		bar.texture_under=ForestUI.texture("boss_track")
		bar.texture_progress=ForestUI.texture("boss_fill")
		bar.nine_patch_stretch=true
		bar.stretch_margin_left=8
		bar.stretch_margin_right=8
		bar.stretch_margin_top=6
		bar.stretch_margin_bottom=6
		bar.max_value=world.boss.MAX_HP
		bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		UI.place(bar,screen,304,124,352,18)
		hud.boss_bar=bar
		hud.boss_fill=bar
	preload("res://scripts/ui/faction_ui.gd").decorate(screen,"play",Campaign.p.hero)

func pause() -> void:
	if page == "play":
		Campaign.save()
		show_page("pause")

func _process(_delta: float) -> void:
	if page == "play" and is_instance_valid(world):
		refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and page == "play" and not get_tree().paused:
		pause()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	var debug_modal := get_node_or_null("/root/DebugTools/DeveloperMenu/Modal")
	if debug_modal and debug_modal.visible:
		return
	match page:
		"play": pause()
		"pause": show_page("play")
		"settings": show_page(back_page)
		"confirm": show_page(cancel_page)
		"heroes","map","future": main_menu()
	get_viewport().set_input_as_handled()

func purchase() -> void:
	if Campaign.buy():
		if is_instance_valid(world):
			world.player.respawn()
			show_page("play")
		else:
			start_level()

func end_attempt() -> void:
	var previous_status:String=Campaign.p.status
	Campaign.abandon()
	clear_world()
	if previous_status=="offer" and Campaign.p.status=="defeat": SFX.play("game_over",self)
	show_page("defeat")

func next_map() -> void:
	Campaign.leave_result()
	clear_world()
	show_page("map")

func debug_restart(level := "1-1") -> void:
	if Campaign.sandbox:
		Campaign.debug_level(level)
		start_level()

func debug_return() -> void:
	clear_world()
	Campaign.end_sandbox()
	restore_screen()
