extends Control

@onready var modal: Control = $Modal
@onready var collisions: CheckButton = %Collisions
@onready var list: VBoxContainer = %Close.get_parent()
var bench_window:Control
var previous_focus: Control
var previous_pause := false
var controls := GridContainer.new()

func _ready() -> void:
	list.get_node("Later").hide()
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(640,280)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	list.add_child(scroll)
	scroll.add_child(controls)
	list.move_child(scroll,%Close.get_index())
	controls.columns = 3
	controls.add_theme_constant_override("h_separation",8)

func game():
	var scene := get_tree().current_scene
	return scene if scene and scene.has_method("debug_restart") else null

func toggle() -> void:
	if is_instance_valid(bench_window):
		bench_window.finish()
		return
	if modal.visible:
		modal.hide()
		get_tree().paused = previous_pause
		if is_instance_valid(previous_focus):
			previous_focus.grab_focus()
		return
	previous_pause = get_tree().paused
	previous_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	modal.show()
	collisions.disabled = not get_tree().has_group("test_hitboxes")
	rebuild()
	%Close.grab_focus()

func add_action(caption: String, action: Callable) -> void:
	var b := Button.new()
	b.text = caption
	b.add_theme_font_size_override("font_size",18)
	b.custom_minimum_size = Vector2(190,35)
	b.pressed.connect(action)
	controls.add_child(b)

func rebuild() -> void:
	for child in controls.get_children():
		controls.remove_child(child)
		child.queue_free()
	var g = game()
	if not g:
		return
	add_action("Стенд анимаций",animation_bench)
	if not Campaign.sandbox:
		add_action("Начать тестовую сессию",enter_sandbox)
		return
	for level: String in Campaign.NAMES:
		add_action("Заново · "+level,command.bind(level))
	add_action("В обычный профиль",command.bind("leave"))
	if not is_instance_valid(g.world) or g.page != "play":
		return
	for entry in [["infinite","Бесконечные сердца"],["shield","Неуязвимость"],["fly","Полёт (стрелки)"]]:
		add_action(entry[1]+(": вкл." if Campaign.cheats.get(entry[0],false) else "  —"),command.bind(entry[0]))
	add_action("Скорость ×"+str(Campaign.cheats.get("speed",1)),command.bind("speed"))
	add_action("+100 монет",command.bind("coins"))
	add_action("Сердца: %d / 3" % Campaign.p.hearts,command.bind("hearts"))
	for i in 3:
		add_action(g.world.player.FORM_NAMES[i],command.bind("form"+str(i)))
	add_action("Потерять сердце",command.bind("damage"))
	add_action("К привалу",command.bind("checkpoint"))
	add_action("К финишу",command.bind("finish"))
	if g.world.boss:
		add_action("Босс · %d / %d ОЗ" % [g.world.boss.hp,g.world.boss.MAX_HP],command.bind("arena"))
		add_action("Восстановить босса",command.bind("heal"))
		add_action("Победить босса",command.bind("kill"))

func animation_bench() -> void:
	modal.hide()
	var bench=preload("res://scripts/debug/animation_bench.gd").new()
	add_child(bench)
	bench_window=bench
	bench.closed=func(): modal.show()

func enter_sandbox() -> void:
	Campaign.start_sandbox()
	rebuild()

func command(id: String) -> void:
	if not Campaign.sandbox:
		return
	var g = game()
	if Campaign.NAMES.has(id) or id == "leave":
		toggle()
		if id == "leave":
			g.debug_return()
		else:
			Campaign.cheats.clear()
			g.debug_restart(id)
		return
	var player = g.world.player
	match id:
		"infinite","shield","fly":
			Campaign.cheats[id] = not Campaign.cheats.get(id,false)
		"speed":
			Campaign.cheats.speed = int(Campaign.cheats.get("speed",1))%3+1
		"coins": Campaign.debug_values(100,Campaign.p.hearts)
		"hearts": Campaign.debug_values(0,1+int(Campaign.p.hearts)%3)
		"form0","form1","form2": player.apply_form(int(id.right(1)))
		"damage":
			toggle()
			player.damage(false,true)
			return
		"heal": g.world.boss.reset_health()
		"kill": g.world.boss.take_damage(g.world.boss.hp)
		"arena":
			toggle()
			g.world.warp(Vector2(g.world.boss.position.x-225,380))
			return
		"checkpoint","finish":
			toggle()
			player.position = Vector2(g.world.checkpoint_x if id == "checkpoint" else g.world.finish_x-96,475)
			player.velocity = Vector2.ZERO
			player.get_node("Camera").reset_smoothing()
			return
	rebuild()

func _on_collisions_toggled(enabled: bool) -> void:
	$Outlines.visible = enabled
