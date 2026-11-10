extends Node2D
## P04 PNGs already contain pose calibration; never re-normalize their alpha bounds.
var library
var sprite:=AnimatedSprite2D.new()
var model:=""
var last_clip:=""
var sampled:=false

func _init() -> void:
	sprite.centered=false
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)

func set_actor(id:String) -> void:
	model=id
	var data:Dictionary=library.actors[id]
	sprite.sprite_frames=library.resource("characters/"+id+"/"+id+".tres")
	sprite.scale=Vector2.ONE/float(data.density)
	sprite.offset=-Vector2(data.pivot_px[0],data.pivot_px[1])
	last_clip=""

func face(direction:float) -> void:
	scale.x=signf(direction) if direction!=0 else 1.0

func select(clip:String) -> void:
	if model.is_empty():
		var data:Dictionary=library.objects[clip]
		var group:String="effects" if data.file.contains("/effects/") else "objects"
		var frames:SpriteFrames=library.resource(data.get("frames_resource",group+"/"+group+".tres"))
		if sprite.sprite_frames!=frames: sprite.sprite_frames=frames
		sprite.scale=Vector2.ONE/float(data.density)
		sprite.offset=-Vector2(data.anchor_world[0],data.anchor_world[1])*float(data.density)

func play(clip:String,duration:=0.0,restart:=false) -> void:
	if clip==last_clip and not restart and not sampled: return
	select(clip)
	last_clip=clip
	sampled=false
	sprite.speed_scale=1.0
	if duration>0:
		sprite.speed_scale=float(sprite.sprite_frames.get_frame_count(clip))/maxf(0.001,sprite.sprite_frames.get_animation_speed(clip)*duration)
	if restart: sprite.stop()
	sprite.play(clip)

func sample(clip:String,progress:float) -> void:
	if clip!=last_clip or not sampled:
		select(clip)
		sprite.play(clip)
		sprite.pause()
		last_clip=clip
		sampled=true
	sprite.frame=clampi(floori(progress*sprite.sprite_frames.get_frame_count(clip)),0,sprite.sprite_frames.get_frame_count(clip)-1)
