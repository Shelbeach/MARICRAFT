extends Node2D
const Sprite := preload("res://scripts/visual/art_sprite.gd")
const LIMIT := 36

func spawn(clip: String,at: Vector2,direction:=1.0) -> void:
	if get_child_count()>=LIMIT: return
	var effect:=Sprite.new()
	add_child(effect)
	effect.position=to_local(at)
	effect.play(clip)
	effect.scale.x=direction
	effect.sprite.animation_finished.connect(effect.queue_free,CONNECT_ONE_SHOT)
	# Some projectile and status strips loop in the pack.
	var timer:=Timer.new()
	timer.one_shot=true
	effect.add_child(timer)
	timer.timeout.connect(effect.queue_free)
	timer.start(0.75)

func actor_ending(model: String,clip: String,at: Vector2,direction: float) -> void:
	if get_child_count()>=LIMIT: return
	var effect:=Sprite.new()
	add_child(effect)
	effect.position=to_local(at)
	effect.set_actor(model)
	effect.face(direction)
	effect.play(clip)
	effect.sprite.animation_finished.connect(effect.queue_free,CONNECT_ONE_SHOT)
