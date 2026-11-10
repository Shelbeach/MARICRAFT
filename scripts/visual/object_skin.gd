extends Node2D
const Sprite:=preload("res://scripts/visual/art_sprite.gd")
var art:=Sprite.new()
var object
var level
var role:=""
var opening:=false
var trail_time:=0.0
var pipe_parts:Array[Node2D]=[]

func _ready() -> void:
	object=get_parent()
	level=object.get_parent()
	role=object.get_script().resource_path.get_file().get_basename()
	add_child(art)
	if object.has_signal("visual_event"): object.visual_event.connect(on_event)
	if role=="pipe": build_pipe()
	update()

func effect(clip: String,offset:=Vector2.ZERO) -> void:
	level.get_node("LocationArt/Effects" if level.has_meta("location2_art") else "ForestArt/Effects").spawn(clip,object.global_position+offset)

func on_event(event: String) -> void:
	match event:
		"pickup":
			effect({"coin":"coin_pickup","potion":"bonus_pickup","rune":"rune_pickup"}[object.kind])
		"open":
			opening=true
			art.play("chest_coin_open" if object.kind=="coins" else "chest_bonus_open")
			effect("chest_reward",Vector2(0,-12))
			art.sprite.animation_finished.connect(func(): opening=false,CONNECT_ONE_SHOT)
		"break": effect("block_shards")
		"eject": effect("potion_eject",Vector2(0,-16))
		"enter": effect("pipe_enter",Vector2(0,-48))
		"emerge": effect("pipe_emerge",Vector2(0,-48))
		"wall","enemy","boss","fade":
			effect(Campaign.p.hero+"_"+event)
		"water_hit": effect("water_hit")
		"contact": effect("spike_contact",Vector2(0,-12))

func build_pipe() -> void:
	art.visible=false
	var stem:String="pipe_"+object.mode
	for part in ["rim","body","foot"]:
		var piece:=Sprite.new()
		add_child(piece)
		piece.play(stem+"_"+part)
		piece.position.y={"rim":-48,"body":-28,"foot":-12}[part]
		# Keep the playable rim at -48; extend the base into the turf.
		if part=="body": piece.scale.y=1.25
		if part=="foot": piece.position.y=-8
		pipe_parts.append(piece)
	var sign:=Sprite.new()
	add_child(sign)
	sign.play("sign_"+object.mode)
	sign.position.y=-14
	pipe_parts.append(sign)
	# An overlapping foreground grass lip seats the base without moving collision.
	var contact:=preload("res://scripts/visual/pipe_contact.gd").new()
	add_child(contact)

func _process(delta: float) -> void:
	update()
	if role=="bolt":
		trail_time+=delta
		if trail_time>=0.10:
			trail_time=0
			effect(Campaign.p.hero+"_trail",Vector2(-8*object.direction,0))

func update() -> void:
	match role:
		"pickup": art.play({"coin":"coin_spin","potion":"potion_idle","rune":"rune_idle"}[object.kind])
		"reward_block":
			position.y=-sin(object.bump/0.18*PI)*4 if object.bump>0 else 0.0
			if opening: return
			var clip:="chest_coin" if object.kind=="coins" else "chest_bonus"
			if object.spent: clip="chest_spent"
			if object.kind in ["empty","fragile"]: clip="solid" if object.kind=="empty" else "fragile"
			art.play(clip)
		"bolt":
			art.play(Campaign.p.hero+"_bolt")
			art.scale.x=object.direction
		"boss_shot":
			art.play("ground_wave" if object.wave else "water_shot")
			if object.wave: art.scale.x=signf(object.direction.x)
			else:
				art.rotation=object.direction.angle()
				art.scale=Vector2.ONE*1.6
		"ferry": art.play("ferry_oak")
		"spikes": art.play("spikes")
		"pipe":
			if object.mode=="ambush" and object.triggered:
				for part in pipe_parts: part.visible=false
				art.visible=true
				art.play("pipe_ambush_spent")
				art.position.y=4
