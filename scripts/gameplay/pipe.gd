extends StaticBody2D

signal visual_event(kind: String)

const MURLOC := preload("res://scenes/enemies/murloc.tscn")
@export var enemy_scene:PackedScene = MURLOC
@export_enum("entry","return","ambush") var mode := "entry"
@export var destination := Vector2.ZERO
@export var enemy_id := ""
@export var prompt := ""
@export_range(-1,1) var emerge_direction := 0
@export var enemy_patrol_width := 85.0
var triggered := false
var showing_hint := false

func _physics_process(_delta: float) -> void:
	var level = get_parent()
	var actor = level.player
	if actor.recovering > 0 or not Campaign.active():
		return
	var distance: float = absf(actor.position.x-position.x)
	if mode == "ambush":
		if not triggered and distance < 190 and distance > 55:
			triggered = true
			visual_event.emit("emerge")
			var guard := enemy_scene.instantiate()
			guard.reward_id = enemy_id
			guard.patrol_width = enemy_patrol_width
			guard.position = position + Vector2(0,-48)
			guard.direction = 1 if actor.position.x < position.x else -1
			if emerge_direction!=0: guard.direction=emerge_direction
			guard.velocity.y = -135
			guard.emerging_from_pipe = true
			level.add_child(guard)
			queue_redraw()
		return
	var atop: bool = distance < 37 and absf(actor.position.y-(position.y-48)) < 3 and actor.is_on_floor()
	if atop:
		level.pipe_prompt = "S / стрелка вниз   ·   "+(prompt if not prompt.is_empty() else ("Войти в грот" if mode=="entry" else "Вернуться в лес"))
		if Input.is_action_just_pressed("pipe_down"):
			visual_event.emit("enter")
			SFX.play("pipe_transition",self)
			level.warp(destination)
			Campaign.learned("pipe")
	elif showing_hint:
		level.pipe_prompt = ""
	showing_hint = atop

func _draw() -> void:
	if has_meta("forest_skin"): return
	var color := Color("#b76f5a") if mode=="ambush" else Color("#409f96")
	draw_rect(Rect2(-34,-42,68,42),color.darkened(0.17))
	draw_rect(Rect2(-40,-48,80,12),color)
	draw_string(ThemeDB.fallback_font,Vector2(-22,-12),"!" if mode=="ambush" else ("ВХОД" if mode=="entry" else "ВЫХОД"),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
