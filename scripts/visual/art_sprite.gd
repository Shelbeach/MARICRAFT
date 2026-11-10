extends Node2D
## One feet-origin branch. Collision shapes are always siblings, never descendants.
const Art := preload("res://scripts/visual/art_library.gd")
var sprite := AnimatedSprite2D.new()
var model := ""
var corrected := true
var base_pivot := Vector2.ZERO
var base_scale := Vector2.ONE
var actor := false
var source_faces := 1

func _init() -> void:
	Art.initialize()
	sprite.centered=false
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	sprite.frame_changed.connect(align_frame)

func set_actor(id: String) -> void:
	if model==id: return
	model=id
	actor=true
	var data:Dictionary=Art.actors[id]
	sprite.stop()
	sprite.sprite_frames=Art.resource("characters/"+data.spriteframes)
	sprite.animation=&"idle"
	sprite.frame=0
	base_scale=Vector2.ONE/float(data.density)
	base_pivot=Vector2(data.pivot_px[0],data.pivot_px[1])
	source_faces=1 if data.faces=="right" else -1
	align_frame()

func face(direction: float) -> void:
	scale.x=signf(direction)*source_faces if direction!=0 else 1.0

func play(clip: String,duration:=0.0,restart:=false) -> void:
	if not actor:
		var data:Dictionary=Art.objects[clip]
		var frames:SpriteFrames=Art.resource("gameplay/"+data.spriteframes)
		if sprite.sprite_frames!=frames: sprite.sprite_frames=frames
		base_pivot=Vector2(data.anchor_world[0],data.anchor_world[1])*2
		base_scale=Vector2.ONE*0.5
	if not restart and sprite.animation==clip and (sprite.is_playing() or not sprite.sprite_frames.get_animation_loop(clip)):
		align_frame()
		return
	sprite.speed_scale=1.0
	if duration>0:
		sprite.speed_scale=float(sprite.sprite_frames.get_frame_count(clip))/sprite.sprite_frames.get_animation_speed(clip)/duration
	if restart: sprite.stop()
	sprite.play(clip)
	align_frame()

func align_frame() -> void:
	var correction:=1.0
	if actor and corrected:
		var profile:Dictionary=Art.calibration.get(model,{})
		correction=float(profile.get("_scale",1.0))*float(profile.get(str(sprite.animation),{}).get(str(sprite.frame),1.0))
	sprite.scale=base_scale*correction
	sprite.offset=-base_pivot

func play_locomotion(clip: String, speed: float) -> void:
	play(clip)
	# A full cycle travels one stride. Small bodies need more steps at the same
	# gameplay speed; acceleration/deceleration must not use full-speed feet.
	var stride:float=Art.calibration.get(model,{}).get("_stride",104.0)
	sprite.speed_scale=absf(speed)*sprite.sprite_frames.get_frame_count(clip)/sprite.sprite_frames.get_animation_speed(clip)/stride
