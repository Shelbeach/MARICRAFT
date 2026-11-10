extends "res://scripts/visual/forest_effects.gd"
const LocalSprite:=preload("res://scripts/visual/location_sprite.gd")
var library

func spawn(clip:String,at:Vector2,direction:=1.0) -> void:
	clip={"run_dust":"dust","land_dust":"dust","block_shards":"ore_break"}.get(clip,clip)
	if not library.objects.has(clip):
		super.spawn(clip,at,direction)
		return
	if get_child_count()>=LIMIT: return
	var effect:=LocalSprite.new()
	effect.library=library
	add_child(effect)
	effect.position=to_local(at)
	effect.play(clip)
	effect.face(direction)
	effect.sprite.animation_finished.connect(effect.queue_free,CONNECT_ONE_SHOT)
	var data:Dictionary=library.objects[clip]
	var timer:=Timer.new()
	timer.one_shot=true
	effect.add_child(timer)
	timer.timeout.connect(effect.queue_free)
	timer.start(float(data.count)/maxf(float(data.fps),1.0)+0.1)

func actor_ending(model:String,clip:String,at:Vector2,direction:float) -> void:
	if not library.actors.has(model):
		super.actor_ending(model,clip,at,direction)
		return
	if get_child_count()>=LIMIT: return
	var effect:=LocalSprite.new()
	effect.library=library
	add_child(effect)
	effect.position=to_local(at)
	effect.set_actor(model)
	effect.face(direction)
	# Gameplay has already removed the actor. This branch never owns a collider/reward.
	if model=="kobold":
		effect.play("hit",0.16)
		effect.sprite.animation_finished.connect(func():
			effect.play(clip)
			effect.sprite.animation_finished.connect(effect.queue_free,CONNECT_ONE_SHOT),CONNECT_ONE_SHOT)
	else:
		effect.play(clip)
		effect.sprite.animation_finished.connect(effect.queue_free,CONNECT_ONE_SHOT)
