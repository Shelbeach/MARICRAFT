extends Node2D
const Pose=preload("body_pose.gd")
const BASE=preload("../parts/base.png")
const TORSO=preload("../parts/torso.png")
const HEAD=preload("../parts/head.png")
const CAST=preload("../parts/head_cast.png")
const BLEND=preload("head_blend.gdshader")
var clip:="idle"
var progress:=0.0
var pose:Dictionary=Pose.sample("idle",0)
var head:Sprite2D
func _ready()->void:
	head=Sprite2D.new();head.texture=CAST;head.centered=false;head.offset=Vector2(-125,-103)
	var mat:=ShaderMaterial.new();mat.shader=BLEND;mat.set_shader_parameter("normal_tex",HEAD);mat.set_shader_parameter("cast_tex",CAST);head.material=mat
	add_child(head);refresh_head()
func sample(action:String,t:float)->void:
	clip=action;progress=t;apply_pose(Pose.sample(action,t))
func apply_pose(value:Dictionary)->void:
	pose=value;refresh_head();queue_redraw()
func refresh_head()->void:
	if not is_instance_valid(head):return
	var p:=pose
	head.position=p.head_position if p.head_free else p.torso+Vector2(11,-181).rotated(p.angle)
	head.rotation=p.head_angle+(0.0 if p.head_free else p.angle)
	head.modulate=p.tint;head.material.set_shader_parameter("amount",p.mouth)
func paint(tex:Texture2D,at:Vector2,pivot:Vector2,angle:float,size:Vector2,tint:Color)->void:
	draw_set_transform(at,angle,size);draw_texture(tex,-pivot,tint)
func _draw()->void:
	var p:=pose
	paint(BASE,Vector2.ZERO,Vector2(120,137),0,p.base_scale,Color(1,1,1,p.base_alpha)*p.tint)
	paint(TORSO,p.torso,Vector2(115,216),p.angle,Vector2.ONE,p.tint)
	draw_set_transform(Vector2.ZERO)
