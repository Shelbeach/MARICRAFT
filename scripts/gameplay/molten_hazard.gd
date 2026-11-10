extends Node2D
## One clock defines both the visible warning and the exact damaging rectangle.
@export_enum("vent","lava","eruption") var kind := "vent"
@export var width := 64.0
@export var height := 72.0
@export var warning := 1.0
@export var duration := 0.7
@export var rest := 2.3
@export var offset := 0.0
@export var one_shot := false
var age := 0.0
var active := false
var warning_now := false
var activated := false

func _ready() -> void:
	age=offset
	if one_shot: add_to_group("molten_attacks")

func bounds() -> Rect2:
	return Rect2(global_position-Vector2(width/2,height),Vector2(width,height))

func _physics_process(delta:float) -> void:
	if not Campaign.active(): return
	age+=delta
	var phase:=age if one_shot else fmod(age,warning+duration+rest)
	warning_now=kind!="lava" and phase<warning
	active=kind=="lava" or (phase>=warning and phase<warning+duration)
	if one_shot and phase>=warning+duration:
		queue_free()
		return
	var a=get_parent().player
	if active and a.recovering<=0:
		var body:=Rect2(a.global_position-Vector2(12,a.height),Vector2(24,a.height))
		if bounds().intersects(body): a.damage(kind=="lava")
	queue_redraw()

func _draw() -> void:
	if has_meta("forest_skin"): return
	# Temporary P07 socket: bright teeth/flame fill, dark base, no debug outlines.
	var rect:=Rect2(-width/2,-height,width,height)
	if kind=="lava":
		draw_rect(rect,Color("#c94328"))
		draw_rect(Rect2(-width/2,-height,width,6),Color("#ffd477"))
		for i in ceili(width/26):
			var x:float=-width/2+13+i*26
			draw_arc(Vector2(x,-height+13),9,0,PI,9,Color("#ec8235"),3)
		return
	draw_rect(Rect2(-width/2-3,-3,width+6,7),Color("#171b25"))
	if warning_now:
		var progress:=clampf(age/warning if one_shot else fmod(age,warning+duration+rest)/warning,0,1)
		draw_rect(rect,Color(1.0,0.55,0.18,0.13+progress*0.12))
		for i in ceili(width/16):
			var x:float=-width/2+8+i*16
			draw_colored_polygon(PackedVector2Array([Vector2(x-5,-4),Vector2(x,-13-7*progress),Vector2(x+5,-4)]),Color("#ffcb75"))
		draw_rect(Rect2(-width/2,-2,width*progress,3),Color("#ffe6a0"))
	elif active:
		draw_rect(rect,Color("#de572e"))
		for i in ceili(width/16):
			var x:float=-width/2+i*16
			draw_colored_polygon(PackedVector2Array([Vector2(x,-3),Vector2(x+7,-height+2),Vector2(minf(x+16,width/2),-3)]),Color("#ffe49a"))
	else:
		draw_line(Vector2(-width/2,0),Vector2(width/2,0),Color("#925641"),3)
