extends Node2D
## Cosmetic only: every cue follows the boss's live warning timer and locked aim.
const Sprite:=preload("res://scripts/visual/art_sprite.gd")
const WAVE:=preload("res://assets/forest_art/gameplay/effects/ground_wave.png")
const INK:=Color("#174851")
const WATER:=Color("#37bfc8")
const FOAM:=Color("#ddfff0")
var actor
var charge:=Sprite.new()
var progress:=0.0

func _ready() -> void:
	actor=get_parent().actor
	name="Telegraph"
	add_child(charge)
	charge.play("water_shot")
	z_index=2
	visible=false

func _process(_delta:float) -> void:
	visible=actor.hp>0 and actor.mode==actor.Mode.WARN
	if not visible: return
	progress=clampf(1.0-actor.time_left/actor.move.warning,0,1)
	charge.visible=actor.move.kind==actor.WATER
	if charge.visible:
		charge.position=Vector2(0,-48)+actor.aim*30
		charge.rotation=actor.aim.angle()
		charge.scale=Vector2.ONE*(0.55+progress*0.6)
	queue_redraw()

func _draw() -> void:
	if not visible: return
	var arrival:Vector2=actor.landing-actor.position
	match actor.move.kind:
		actor.WATER: draw_aim()
		actor.DASH: draw_rush(arrival)
		actor.LEAP: draw_landing(arrival)

func droplet(at:Vector2,radius:float,angle:float,opacity:=1.0) -> void:
	var points:=PackedVector2Array()
	for point in [Vector2(-1.5,0),Vector2(-0.25,-0.65),Vector2(0.6,-0.62),Vector2(1,0),Vector2(0.6,0.62),Vector2(-0.25,0.65)]:
		points.append(at+point.rotated(angle)*radius)
	draw_colored_polygon(points,Color(WATER,opacity))
	points.append(points[0])
	draw_polyline(points,Color(INK,opacity*0.8),1,true)
	draw_line(at+Vector2(-0.2,-0.3).rotated(angle)*radius,at+Vector2(0.5,-0.3).rotated(angle)*radius,Color(FOAM,opacity),1,true)

func draw_aim() -> void:
	var origin:=Vector2(0,-48)
	var normal:Vector2=actor.aim.orthogonal()
	var start:Vector2=origin+actor.aim*34
	var end:Vector2=origin+actor.aim*148
	var locked:bool=actor.time_left<=0.24
	# A tapered translucent water trail, with a bright crest when aim locks.
	var alpha:=0.22+progress*0.16
	draw_polygon(PackedVector2Array([start+normal*6,start-normal*6,end-normal*1.5,end+normal*1.5]),PackedColorArray([Color(WATER,alpha),Color(WATER,alpha),Color(WATER,0.03),Color(WATER,0.03)]))
	for i in 4:
		var t:=fposmod(progress*1.8+i*0.25,1.0)
		var at:=start.lerp(end,t)
		droplet(at,2.3+1.0*(1-t),actor.aim.angle(),0.45+0.5*sin(t*PI))
	var tip:Vector2=origin+actor.aim*143
	var arrow:=PackedVector2Array([tip-actor.aim*9+normal*6,tip,tip-actor.aim*9-normal*6])
	draw_polyline(arrow,INK,4,true)
	draw_polyline(arrow,FOAM if locked else WATER,2,true)
	if locked:
		draw_line(start,end,Color(FOAM,0.7),1.2,true)

func draw_rush(arrival:Vector2) -> void:
	var direction:=signf(arrival.x)
	var from:=Vector2(direction*20,-3)
	var to:=arrival+Vector2(direction*24,-3)
	var points:=PackedVector2Array([from+Vector2(0,-5),to+Vector2(-direction*10,-3),to+Vector2(direction*7,0),to+Vector2(-direction*10,4),from+Vector2(0,7)])
	draw_colored_polygon(points,Color(INK,0.32))
	draw_line(from,to,Color(WATER,0.55),3,true)
	for i in 3:
		var t:float=(i+0.5)/3.0
		var at:=from.lerp(to,t)
		var strength:=0.5+0.5*sin(progress*TAU*2-i*0.8)
		wave(at,direction,0.65+strength*0.35)
		droplet(at+Vector2(-direction*4,-15-strength*3),2.2,Vector2(direction,-0.4).angle(),0.8)

func wave(at:Vector2,direction:float,opacity:float) -> void:
	var frame:=int(progress*12)%6
	draw_set_transform(at,0,Vector2(direction,1))
	draw_texture_rect_region(WAVE,Rect2(-13,-17,26,19.5),Rect2(frame*48,0,48,36),Color(1,1,1,opacity))
	draw_set_transform(Vector2.ZERO)

func draw_landing(arrival:Vector2) -> void:
	var center:=arrival+Vector2(0,-2)
	# Water gathers at the actual landing point, then emits two ground waves.
	var outline:=PackedVector2Array()
	for i in 65:
		var angle:=TAU*i/64.0
		var ripple:=1.0+0.04*sin(angle*7+progress*TAU*2)
		outline.append(center+Vector2(cos(angle)*34,sin(angle)*8)*ripple)
	draw_colored_polygon(outline,Color("#216b79",0.36+progress*0.2))
	draw_polyline(outline,Color(INK,0.85),3,true)
	for segment in 3:
		var foam:=PackedVector2Array()
		for i in 13:
			var a:=segment*TAU/3+progress*2+i*0.07
			foam.append(center+Vector2(cos(a)*31,sin(a)*7))
		draw_polyline(foam,FOAM,1.8,true)
	for i in 6:
		var phase:=fposmod(progress*1.6+i/6.0,1.0)
		var side:float=-1 if i%2 else 1
		var at:=center+Vector2(side*(36-26*phase),-9-19*sin(phase*PI))
		droplet(at,2+phase,Vector2(-side,0.7).angle(),sin(phase*PI)*0.9)
	for side in [-1,1]:
		var at:=center+Vector2(side*43,0)
		wave(at,side,0.6+progress*0.4)
