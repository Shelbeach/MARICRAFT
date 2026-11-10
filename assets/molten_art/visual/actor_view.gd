extends Node2D
## Visual-only adapter. No movement, health, collision or reward logic.
@export var frames: SpriteFrames
@export var pivot_px := Vector2(80,112)
@export var density := 2.0
@export var initial_clip: StringName = &"idle"
@export var clip_pivots:Dictionary={}
var sprite: AnimatedSprite2D
var mirror: Node2D
func _ready() -> void:
	mirror=Node2D.new();add_child(mirror)
	sprite=AnimatedSprite2D.new();mirror.add_child(sprite)
	sprite.sprite_frames=frames;sprite.centered=false;sprite.offset=-pivot_px;sprite.scale=Vector2.ONE/density
	if frames and frames.has_animation(initial_clip):play(initial_clip)
func face_right(value:bool) -> void:
	mirror.scale.x=1.0 if value else -1.0
func play(clip:StringName) -> void:
	if frames.has_animation(clip):
		sprite.offset=-clip_pivots.get(String(clip),pivot_px);sprite.play(clip)
func sample(clip:StringName,progress:float) -> void:
	if not frames.has_animation(clip):return
	sprite.offset=-clip_pivots.get(String(clip),pivot_px)
	sprite.animation=clip;sprite.pause()
	sprite.set_frame_and_progress(clampi(int(progress*frames.get_frame_count(clip)),0,frames.get_frame_count(clip)-1),0)
