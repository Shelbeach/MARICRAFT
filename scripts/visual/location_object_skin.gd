extends Node2D
const Sprite:=preload("res://scripts/visual/location_sprite.gd")
var library
var art:=Sprite.new()
var object
var level
var role:=""

func _ready() -> void:
	object=get_parent()
	level=object.get_parent()
	role=object.get_script().resource_path.get_file().get_basename()
	art.library=library
	add_child(art)
	if object.has_signal("visual_event"): object.visual_event.connect(on_event)
	update()
	if role=="spikes":
		# The original transparent padding made a 44-wide hazard look only 34 wide.
		# Painted teeth now span the existing 44x18 collider; the base stays in soil.
		art.scale=Vector2(1.25,0.9)
		var metal:=ShaderMaterial.new()
		metal.shader=preload("res://scripts/visual/spike_metal.gdshader")
		art.sprite.material=metal
		queue_redraw()

func effect(clip:String,offset:=Vector2.ZERO) -> void:
	level.get_node("LocationArt/Effects").spawn(clip,object.global_position+offset,object.direction if role=="bolt" else 1)

func on_event(event:String) -> void:
	match event:
		"wall","enemy","boss","fade": effect(Campaign.p.hero+"_hit_"+event)
		"break": effect("ore_break")
		"open": effect("chest_reward",Vector2(0,-12))
		"eject": effect("potion_eject",Vector2(0,-16))
		"enter": effect("pipe_enter",Vector2(0,-48))
		"emerge": effect("pipe_emerge",Vector2(0,-48))
		"contact": effect("spike_contact",Vector2(0,-12))

func _process(_delta:float) -> void:
	update()
	if role=="ferry": queue_redraw()

func _draw() -> void:
	if role=="spikes":
		var contact:=PackedVector2Array()
		for i in 25:
			var angle:=TAU*i/24.0
			contact.append(Vector2(cos(angle)*23,sin(angle)*2.3-0.5))
		draw_colored_polygon(contact,Color(0.12,0.08,0.07,0.85))
		return
	if role!="ferry": return
	for x in [-48,48]:
		draw_line(Vector2(x,116-object.position.y),Vector2(x,1),Color("#443b35"),3,true)
		draw_line(Vector2(x+0.5,116-object.position.y),Vector2(x+0.5,1),Color("#a89b7a"),1,true)

func update() -> void:
	match role:
		"reward_block":
			position.y=-sin(object.bump/0.18*PI)*4 if object.bump>0 else 0.0
			art.position.y=0 if object.kind in ["empty","fragile"] else 16
			var clip:String="chest_used" if object.spent else "chest_closed"
			if object.kind=="empty": clip="block_strong"
			elif object.kind=="fragile": clip="block_fragile"
			art.play(clip)
		"bolt":
			art.play(Campaign.p.hero+"_green_flight")
			art.face(object.direction)
		"pipe":
			art.play("pipe_spent" if object.mode=="ambush" and object.triggered else "pipe_"+object.mode)
			# Keep the mouth on its collision plane; the opaque foot meets the soil.
			art.position.y=1
		"ferry": art.play("ferry")
		"spikes": art.play("spikes")
