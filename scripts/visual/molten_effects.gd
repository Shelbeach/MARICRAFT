extends "res://scripts/visual/location_effects.gd"
const P07ROOT:="res://assets/molten_art/"

func make(group:String,clip:String,at:Vector2,heading:=1.0,scale_factor:=Vector2.ONE,ending:=false):
	if not is_inside_tree() or get_child_count()>=LIMIT: return null
	if group=="boss_eruption":
		var eruption:=preload("res://assets/p07_v03/visual/eruption_atlas.tscn").instantiate()
		eruption.position=to_local(at)
		eruption.scale=scale_factor
		add_child(eruption)
		eruption.play(clip)
		if ending: eruption.animation_finished.connect(eruption.queue_free,CONNECT_ONE_SHOT)
		return eruption
	var folder:="characters/" if group in ["fire_imp","obsidian_shell"] else "effects/"
	var view=load(P07ROOT+folder+group+"/"+group+".tscn").instantiate()
	view.position=to_local(at)
	view.scale=scale_factor
	add_child(view)
	view.face_right(heading>=0)
	view.play(clip)
	if ending:
		view.sprite.animation_finished.connect(view.queue_free,CONNECT_ONE_SHOT)
		var timer:=Timer.new()
		timer.one_shot=true
		view.add_child(timer)
		timer.timeout.connect(view.queue_free)
		timer.start(view.frames.get_frame_count(clip)/view.frames.get_animation_speed(clip)+0.1)
	return view

func spawn(clip:String,at:Vector2,direction:=1.0) -> void:
	if clip=="block_shards":
		make("block_break","break",at,direction,Vector2.ONE,true)
	elif clip in ["growth","magic_form"]:
		make("hero_impacts","powerup",at+Vector2(0,32),direction,Vector2.ONE,true)
	else: super.spawn(clip,at,direction)

func actor_ending(model:String,clip:String,at:Vector2,direction:float) -> void:
	if model in ["fire_imp","obsidian_shell"]: make(model,clip,at,direction,Vector2.ONE,true)
	else: super.actor_ending(model,clip,at,direction)
